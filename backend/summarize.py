import json
import boto3
import os
import time
import re
from clean_text import clean_text, extract_main_content
from logger import logger
from kendra_indexing import generate_document_id, split_into_chunks, index_in_kendra, query_kendra

# Add Cognito for verifying JWT tokens
cognito_idp = boto3.client('cognito-idp')
dynamodb = boto3.resource('dynamodb')

def verify_token(token):
    """Verify JWT token with Cognito."""
    try:
        # Extract token without Bearer prefix if present
        if token.startswith('Bearer '):
            token = token.split(' ')[1]
            
        # Get user from Cognito using the token
        response = cognito_idp.get_user(
            AccessToken=token
        )
        
        # Extract user attributes
        user_attributes = {}
        for attr in response.get('UserAttributes', []):
            user_attributes[attr['Name']] = attr['Value']
            
        return {
            'user_id': response.get('Username'),
            'email': user_attributes.get('email')
        }
    except Exception as e:
        logger.error(f"Token verification error: {str(e)}")
        return None

def lambda_handler(event, context):
    logger.info(f"Event received: {json.dumps(event)}")
    
    # Set CORS headers for all responses
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'OPTIONS,POST',
        'Content-Type': 'application/json'
    }
    
    # Handle OPTIONS request for CORS
    if event.get('requestContext', {}).get('http', {}).get('method') == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': headers,
            'body': ''
        }
    
    try:
        # Parse request body
        body = json.loads(event.get('body', '{}'))
        text_content = body.get('content', '')
        url = body.get('url', '')
        is_html = body.get('isHtml', False)
        title = body.get('title', '')
        
        # Check for authentication token
        auth_header = event.get('headers', {}).get('authorization') or event.get('headers', {}).get('Authorization')
        user_data = None
        
        # If authentication is enabled and token is provided, verify it
        if auth_header:
            user_data = verify_token(auth_header)
            if not user_data:
                return {
                    'statusCode': 401,
                    'headers': headers,
                    'body': json.dumps({'error': 'Invalid authentication token'})
                }
            logger.info(f"Authenticated user: {user_data['email']}")
        
        if not text_content:
            return {
                'statusCode': 400,
                'headers': headers,
                'body': json.dumps({'error': 'No content provided'})
            }
        
        if is_html:
            text_content = extract_main_content(text_content)
        
        # Clean the text
        cleaned_text = clean_text(text_content)
        logger.info(f"Cleaned text length: {len(cleaned_text)}")

        # Get Kendra index ID
        kendra_index_id = os.environ.get('KENDRA_INDEX_ID')
        use_kendra = bool(kendra_index_id)
        kendra_text = None

        if use_kendra:
            try:
                # Generate document ID
                doc_id = generate_document_id(cleaned_text, title)
                logger.info(f"Generated document ID: {doc_id}")
                
                # Split text into chunks
                chunks = split_into_chunks(cleaned_text)
                logger.info(f"Split content into {len(chunks)} chunks of sizes: {[len(c) for c in chunks]}")
                
                # Index in Kendra
                index_responses = index_in_kendra(chunks, doc_id, title, kendra_index_id)
                failed_docs = sum(len(r.get('FailedDocuments', [])) for r in index_responses)
                logger.info(f"Kendra indexing complete - {len(chunks)} chunks indexed, {failed_docs} failures")
                
                # Wait a moment for indexing to complete
                time.sleep(2)
                logger.info("Querying Kendra for relevant content...")
                
                # Query Kendra for relevant content
                kendra_text = query_kendra(doc_id, kendra_index_id)
                
                if kendra_text:
                    logger.info(f"Retrieved Kendra-processed text: {len(kendra_text)} characters")
                    logger.info(f"First 200 chars of Kendra text: {kendra_text[:200]}...")
                else:
                    logger.info("No Kendra results returned, falling back to original text")
            except Exception as e:
                logger.error(f"Kendra processing error: {str(e)}", exc_info=True)
                # Continue with original text if Kendra fails
        
        # Use Kendra-enhanced text or original text
        summarization_text = kendra_text if kendra_text else cleaned_text
        logger.info(f"Using {'Kendra-enhanced' if kendra_text else 'original'} text for summarization")
        
        # For free-tier AWS, we'll use a basic approach:
        # 1. Either use Amazon Bedrock if available (recommended)
        # 2. Or use a simpler extractive approach if Bedrock is not accessible
        
        try:
            # Try to use Amazon Bedrock (if available)
            logger.info("Calling Bedrock for summarization...")
            bedrock_runtime = boto3.client(
                service_name='bedrock-runtime',
                region_name=os.environ.get('AWS_REGION', 'us-east-1')
            )
            
            # Create prompt for summarization
            prompt = f"""Human: Please provide a concise summary of the following text in 3-5 sentences, focusing on the main points:

{summarization_text}

Please provide a clear, well-structured summary that captures the essential information in 3-5 sentences.

Assistant:"""
            
            # Call Bedrock model
            response = bedrock_runtime.invoke_model(
                modelId='anthropic.claude-3-sonnet-20240229-v1:0',
                body=json.dumps({
                    "anthropic_version": "bedrock-2023-05-31",
                    "max_tokens": 500,
                    "temperature": 0.7,
                    "messages": [
                        {
                            "role": "user", 
                            "content": f"Please provide a concise summary of the following text in 3-5 sentences, focusing on the main points:\n\n{summarization_text}\n\nPlease provide a clear, well-structured summary that captures the essential information in 3-5 sentences."
                        }
                    ]
                })
            )
            
            # Parse response
            response_body = json.loads(response.get('body').read())
            summary = response_body.get('content', [{}])[0].get('text', '').strip()
            logger.info(f"Bedrock generation successful, summary length: {len(summary)}")
            logger.info(f"Summary: {summary}")
            
        except Exception as e:
            logger.error(f"Bedrock API error: {str(e)}", exc_info=True)
            # Fallback to extractive summarization
            logger.info("Falling back to extractive summarization")
            sentences = re.split(r'(?<=[.!?])\s+', cleaned_text)
            if len(sentences) <= 5:
                summary = cleaned_text
            else:
                summary = ' '.join(sentences[:min(5, len(sentences) // 3)])
        
        # If user is authenticated, save the summary to DynamoDB
        if user_data:
            try:
                table_name = os.environ.get('USER_TABLE_NAME', 'brevity-cloud-user-data')
                user_table = dynamodb.Table(table_name)
                if user_table.table_name:
                    # Save summary to DynamoDB
                    user_table.update_item(
                        Key={
                            'user_id': user_data['user_id']
                        },
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
                    logger.info(f"Saved summary to DynamoDB for user {user_data['email']}")
            except Exception as e:
                logger.error(f"Error saving to DynamoDB: {str(e)}")
                # Continue without saving to DynamoDB
        
        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({
                'summary': summary,
                'used_kendra': kendra_text is not None
            })
        }
        
    except Exception as e:
        logger.error(f"General error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({
                'error': str(e)
            })
        }