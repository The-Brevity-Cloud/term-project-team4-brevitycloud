import json
import boto3
import os
import time
import re
import decimal
from clean_text import clean_text, extract_main_content
from logger import logger
from kendra_indexing import generate_document_id, split_into_chunks, index_in_kendra, query_kendra
from s3_helper import generate_url_hash, check_document_exists, store_document, get_document

# Initialize AWS clients
cognito_idp = boto3.client('cognito-idp')
dynamodb = boto3.resource('dynamodb')
bedrock_runtime = boto3.client(
    service_name='bedrock-runtime',
    region_name=os.environ.get('AWS_REGION', 'us-east-1')
)

# Constants
BEDROCK_MODEL = 'anthropic.claude-3-sonnet-20240229-v1:0'
MAX_TOKENS = 500
TEMPERATURE = 0.7

USER_TABLE_NAME = os.environ.get('USER_TABLE_NAME', 'brevity-cloud-user-data')
user_table = dynamodb.Table(USER_TABLE_NAME)
MAX_HISTORY_ITEMS = 5 # Max number of summaries/chats to return

# Helper class to convert DynamoDB Decimal to JSON serializable type (int/float)
class DecimalEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, decimal.Decimal):
            # Convert Decimal to int if it's an integer, else float
            if o % 1 == 0:
                return int(o)
            else:
                return float(o)
        return super(DecimalEncoder, self).default(o)

def verify_token(token):
    """Verify JWT token with Cognito."""
    try:

        if token.startswith('Bearer '):
            token = token.split(' ')[1]
        response = cognito_idp.get_user(AccessToken=token)
        user_attributes = {attr['Name']: attr['Value'] for attr in response.get('UserAttributes', [])}
        return {
            'user_id': response.get('Username'),
            'email': user_attributes.get('email')

        }
    except Exception as e:
        logger.error(f"Token verification error: {str(e)}")
        return None

def call_bedrock(prompt, max_tokens=MAX_TOKENS, temperature=TEMPERATURE):
    """Make a call to Bedrock's Claude model"""
    try:
        if len(prompt.split()) > 2000:
            prompt = " ".join(prompt.split()[:2000])
            
        response = bedrock_runtime.invoke_model(
            modelId=BEDROCK_MODEL,
            body=json.dumps({
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": max_tokens,
                "temperature": temperature,
                "messages": [
                    {
                        "role": "user",
                        "content": prompt
                    }
                ]
            })
        )
        response_body = json.loads(response.get('body').read())

        
        # Handle Claude 3 response format
        if isinstance(response_body.get('content'), list):
            for content in response_body.get('content', []):
                if content.get('type') == 'text':
                    return content.get('text', '').strip()
        return ''
    except Exception as e:
        logger.error(f"Bedrock API error: {str(e)}", exc_info=True)
        return None

def handle_summarize(cleaned_text, title, url, kendra_index_id=None, use_kendra=True):
    try:
        url_hash = generate_url_hash(url)
        existing_doc = check_document_exists(url_hash)
        
        store_document(url, title, cleaned_text)
        
        kendra_text = None
        kendra_used = False
        
        if kendra_index_id and use_kendra:
            logger.info(f"Using Kendra")
            try:
                doc_id = url_hash
                
                if not existing_doc or existing_doc.get('indexed_status') != 'complete':
                    chunks = split_into_chunks(cleaned_text)
                    index_responses = index_in_kendra(chunks, doc_id, url, kendra_index_id)
                    
                    logger.info("Waiting for Kendra indexing to complete...")
                    
                    max_retries = 5
                    base_wait_time = 5  # Start with 5 seconds
                    for retry in range(max_retries):
                        # Wait with exponential backoff
                        wait_time = base_wait_time * (2 ** retry)
                        time.sleep(wait_time)
                        
                        try:
                            test_query = query_kendra(doc_id, kendra_index_id)
                            if test_query:
                                logger.info(f"Kendra indexing complete after {wait_time} seconds")
                                break
                            else:
                                logger.info(f"Kendra indexing still in progress, retry {retry+1}/{max_retries}")
                        except Exception as e:
                            logger.warning(f"Error checking Kendra indexing status: {str(e)}")
                
                kendra_text = query_kendra(doc_id, kendra_index_id)
                
                if kendra_text:
                    kendra_used = True
                else:
                    logger.warning("Kendra indexing appears to be incomplete. No results returned.")
                    
                    if use_kendra:
                        raise ValueError("Kendra indexing requested but no results available")
            
            except Exception as e:
                logger.error(f"Kendra processing error: {str(e)}", exc_info=True)
                
                if use_kendra:
                    raise ValueError(f"Kendra processing failed: {str(e)}")

        summarization_text = kendra_text if kendra_text else cleaned_text
        
        if not kendra_used and not use_kendra:
            # Create summarization prompt for Bedrock
            logger.info(f"Using Bedrock")
            prompt = f"""Please provide a concise summary of the following text in 3-5 sentences, focusing on the main points:

{summarization_text}

Please provide a clear, well-structured summary that captures the essential information in 3-5 sentences."""

            # Get summary from Bedrock
            summary = call_bedrock(prompt)
            if not summary:
                # Fallback to extractive summarization
                sentences = re.split(r'(?<=[.!?])\s+', cleaned_text)
                summary = ' '.join(sentences[:min(5, len(sentences) // 3)])
                
            return summary, False  # Bedrock was used
            
        elif kendra_used:
            # Create summarization prompt with Kendra-enhanced content
            prompt = f"""Please provide a concise summary of the following text in 3-5 sentences, focusing on the main points:

{summarization_text}

Please provide a clear, well-structured summary that captures the essential information in 3-5 sentences."""

            # Get summary from Bedrock
            summary = call_bedrock(prompt)
            if not summary:
                # Fallback to extractive summarization
                sentences = re.split(r'(?<=[.!?])\s+', kendra_text)
                summary = ' '.join(sentences[:min(5, len(sentences) // 3)])
                
            return summary, True  # Kendra was used
            
        else:
            # Should not reach here if use_kendra=True, but just in case
            raise ValueError("Kendra processing was requested but failed")

    except Exception as e:
        logger.error(f"Summarization error: {str(e)}", exc_info=True)
        raise

def handle_chat(query, context, url=None, kendra_index_id=None, use_kendra=True):
    """Handle chat request with S3 integration and proper Kendra processing"""
    try:
        context_doc_id = None
        if url:
            context_doc_id = generate_url_hash(url)
            
            existing_doc = check_document_exists(context_doc_id)
            if existing_doc:
                s3_doc = get_document(context_doc_id)
                if s3_doc and s3_doc.get('cleaned_text'):
                    context = s3_doc.get('cleaned_text')
        elif context:
            context_doc_id = generate_document_id(context)
        
        kendra_context = None
        kendra_used = False
        
        if kendra_index_id and context_doc_id and use_kendra:
            logger.info(f"Using Kendra")
            try:
                indexed_in_kendra = False
                if url:
                    existing_doc = check_document_exists(context_doc_id)
                    if existing_doc and existing_doc.get('indexed_status') == 'complete':
                        indexed_in_kendra = True
                
                if not indexed_in_kendra and url:
                    logger.info(f"Document {url} not yet indexed in Kendra, waiting for indexing...")
                    
                    max_retries = 5
                    base_wait_time = 5  # Start with 5 seconds
                    for retry in range(max_retries):
                        # Wait with exponential backoff
                        wait_time = base_wait_time * (2 ** retry)
                        time.sleep(wait_time)
                        
                        # Check if document is now indexed
                        existing_doc = check_document_exists(context_doc_id)
                        if existing_doc and existing_doc.get('indexed_status') == 'complete':
                            indexed_in_kendra = True
                            logger.info(f"Document now indexed in Kendra after {wait_time} seconds")
                            break
                        else:
                            logger.info(f"Document indexing still in progress, retry {retry+1}/{max_retries}")
                
                # Query Kendra with the specific question
                kendra_context = query_kendra(context_doc_id, kendra_index_id, query)
                
                if kendra_context:
                    kendra_used = True
                    logger.info("Successfully retrieved context from Kendra")
                else:
                    logger.warning("Kendra query returned no results")
                    
                    if use_kendra:
                        raise ValueError("Kendra was requested but no results available")
                
            except Exception as e:
                logger.error(f"Kendra query error: {str(e)}", exc_info=True)
                
                if use_kendra:
                    raise ValueError(f"Kendra processing failed: {str(e)}")

        context_text = kendra_context if kendra_used else context
        
        # Only proceed with Bedrock if Kendra succeeded or if fallback is allowed
        if kendra_used or not use_kendra:
            logger.info(f"Using Bedrock")
            # Create chat prompt
            prompt = f"""You are an AI assistant helping with questions about a webpage. Use the following context to answer the user's question. Only use information from the provided context.

Context:
{context_text}

User Question:
{query}

Please provide a clear and concise answer based solely on the context provided."""

            # Get response from Bedrock
            response = call_bedrock(prompt, max_tokens=1000)  # Longer response for chat
            if not response:
                return "I apologize, but I'm having trouble generating a response. Please try again.", kendra_used

            return response, kendra_used
        else:
            # Should not reach here if use_kendra=True, but just in case
            raise ValueError("Kendra processing was requested but failed")

    except Exception as e:
        logger.error(f"Chat error: {str(e)}", exc_info=True)
        raise

def get_user_history(user_id):
    """Retrieve user summaries and chat history from DynamoDB."""
    logger.info(f"Fetching history for user_id: {user_id}")
    try:
        response = user_table.get_item(
            Key={'user_id': user_id},
            ProjectionExpression='summaries, chat_history' # Only get necessary fields
        )
        
        item = response.get('Item', {})
        
        # Get summaries, sort by timestamp descending, take latest N
        summaries = sorted(
            item.get('summaries', []),
            key=lambda x: x.get('timestamp', 0), 
            reverse=True
        )[:MAX_HISTORY_ITEMS]
        
        # Get chat history, sort by timestamp descending, take latest N
        chat_history = sorted(
            item.get('chat_history', []),
            key=lambda x: x.get('timestamp', 0),
            reverse=True
        )[:MAX_HISTORY_ITEMS]
        
        logger.info(f"Found {len(summaries)} summaries and {len(chat_history)} chat items.")
        
        # *** No need to convert here if using the custom encoder later ***
        # Convert timestamps (optional here, can be handled by encoder)
        # for summary in summaries:
        #     if 'timestamp' in summary and isinstance(summary['timestamp'], decimal.Decimal):
        #         summary['timestamp'] = int(summary['timestamp'])
        # for chat in chat_history:
        #      if 'timestamp' in chat and isinstance(chat['timestamp'], decimal.Decimal):
        #          chat['timestamp'] = int(chat['timestamp'])
            
        return {
            'summaries': summaries,
            'chat_history': chat_history
        }
        
    except Exception as e:
        logger.error(f"DynamoDB get_item error for user {user_id}: {str(e)}", exc_info=True)
        # Return empty history on error, or re-raise depending on desired behavior
        return {'summaries': [], 'chat_history': []} 

def lambda_handler(event, context):
    """Main Lambda handler"""
    logger.info(f"Event received: {json.dumps(event)}")
    
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'OPTIONS,POST,GET' # Add GET
    }
    
    http_method = event.get('requestContext', {}).get('http', {}).get('method')
    path = event.get('requestContext', {}).get('http', {}).get('path')

    if http_method == 'OPTIONS':
        return {'statusCode': 200, 'headers': headers, 'body': ''}

    try:
        auth_header = event.get('headers', {}).get('authorization') # Use lowercase 'authorization'
        if not auth_header:
             raise ValueError("Missing Authorization header")
             
        user_data = verify_token(auth_header)
        if not user_data or not user_data.get('user_id'):
            raise ValueError("Invalid or expired token")
        
        user_id = user_data['user_id']
        
        # --- Handle GET /history --- 
        if http_method == 'GET' and path.endswith('/history'):
            logger.info(f"Handling GET /history for user: {user_id}")
            history_data = get_user_history(user_id)
            return {
                'statusCode': 200,
                'headers': headers,
                'body': json.dumps(history_data, cls=DecimalEncoder)
            }

        # --- Handle POST /summarize (and /chat) --- 
        elif http_method == 'POST' and path.endswith('/summarize'):
            body = json.loads(event.get('body', '{}'))
            action = body.get('action', 'summarize')
            kendra_index_id = os.environ.get('KENDRA_INDEX_ID')
            use_kendra = body.get('use_kendra', True) 

            if action == 'summarize':
                # Handle summarization request
                url = body.get('url')
                title = body.get('title', '')
                content = body.get('text', '')
                
                if not content:
                    raise ValueError("No content provided for summarization")
                    
                # Clean the text
                cleaned_text = clean_text(content)
                logger.info(f"Cleaned text length: {len(cleaned_text)}")
                
                # Get summary
                summary, used_kendra = handle_summarize(cleaned_text, title, url, kendra_index_id, use_kendra)
                
                # Save summary to DynamoDB
                try:
                    user_table.update_item(
                        Key={'user_id': user_id},
                        UpdateExpression='SET summaries = list_append(if_not_exists(summaries, :empty_list), :new_summary)',
                        ExpressionAttributeValues={
                            ':empty_list': [],
                            ':new_summary': [{
                                'timestamp': int(time.time()),
                                'url': url,
                                'title': title or url,
                                'summary': summary
                            }]
                        }
                    )
                    logger.info(f"Summary saved for user {user_id}")
                except Exception as e:
                    logger.error(f"DynamoDB summary save error: {str(e)}")

                response_body = {'summary': summary, 'used_kendra': used_kendra}
                
            elif action == 'chat':
                # Handle chat request
                url = body.get('url')
                query = body.get('query', '')
                context = body.get('context', '')
                

                if not query or not context:
                    raise ValueError("Query and context are required for chat")
                
                # Get chat response
                chat_response, used_kendra = handle_chat(query, context, url, kendra_index_id, use_kendra)
                
                # Save chat to DynamoDB
                try:
                    user_table.update_item(
                        Key={'user_id': user_id},
                        UpdateExpression='SET chat_history = list_append(if_not_exists(chat_history, :empty_list), :new_chat)',
                        ExpressionAttributeValues={
                            ':empty_list': [],
                            ':new_chat': [{
                                'timestamp': int(time.time()),
                                'query': query,
                                'response': chat_response, # Store the actual response
                                'url': url or '',
                                'title': body.get('title', '')
                            }]
                        }
                    )
                    logger.info(f"Chat saved for user {user_id}")
                except Exception as e:
                     logger.error(f"DynamoDB chat save error: {str(e)}")
                     
                response_body = {'response': chat_response, 'used_kendra': used_kendra}
            else:
                raise ValueError(f"Invalid action: {action}")

            return {
                'statusCode': 200,
                'headers': headers,
                'body': json.dumps(response_body)
            }
        else:
             # Handle other paths/methods if necessary
             logger.warning(f"Unhandled request: {http_method} {path}")
             return {
                 'statusCode': 404,
                 'headers': headers,
                 'body': json.dumps({'error': 'Not Found'})
             }

    except ValueError as e: # Catch auth/input validation errors specifically
        logger.error(f"Authorization or input error: {str(e)}", exc_info=True)
        status_code = 400 if "Missing" in str(e) else 401 # 400 for missing, 401 for invalid
        return {
            'statusCode': status_code,
            'headers': headers,
            'body': json.dumps({'error': str(e)})
        }
    except Exception as e:
        logger.error(f"Error processing request: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({'error': f'Internal server error: {str(e)}'})
        }