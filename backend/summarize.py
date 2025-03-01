import json
import boto3
import os
import re

def clean_text(text):
    # Remove excessive whitespace, normalize line breaks
    text = re.sub(r'\n\s*\n', '\n\n', text)
    text = re.sub(r'\s+', ' ', text)
    return text.strip()

def lambda_handler(event, context):
    print("Event received:", json.dumps(event))  # Debug logging
    
    # Handle OPTIONS request for CORS
    if event.get('requestContext', {}).get('http', {}).get('method') == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'OPTIONS,POST'
            },
            'body': ''
        }
    
    try:
        # Parse request body
        body = json.loads(event.get('body', '{}'))
        text_content = body.get('content', '')
        
        if not text_content:
            return {
                'statusCode': 400,
                'headers': {
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type',
                    'Access-Control-Allow-Methods': 'OPTIONS,POST'
                },
                'body': json.dumps({'error': 'No content provided'})
            }
        
        # Clean the text
        cleaned_text = clean_text(text_content)
        print("Cleaned text length:", len(cleaned_text))  # Debug logging
        
        # For free-tier AWS, we'll use a basic approach:
        # 1. Either use Amazon Bedrock if available (recommended)
        # 2. Or use a simpler extractive approach if Bedrock is not accessible
        
        try:
            # Try to use Amazon Bedrock (if available)
            bedrock_runtime = boto3.client(
                service_name='bedrock-runtime',
                region_name=os.environ.get('AWS_REGION', 'us-east-1')
            )
            
            # Create prompt for summarization
            prompt = f"""Human: Please provide a concise summary of the following text in 3-5 sentences, focusing on the main points:

{cleaned_text}

Please provide a clear, well-structured summary that captures the essential information in 3-5 sentences.

Assistant:"""
            
            # Call Bedrock model
            response = bedrock_runtime.invoke_model(
                modelId='anthropic.claude-3-5-sonnet-20241022-v2:0',
                body=json.dumps({
                    "prompt": prompt,
                    "max_tokens": 500,
                    "temperature": 0.7,
                    "top_p": 1,
                    "stop_sequences": ["Human:"]
                })
            )
            
            # Parse response
            response_body = json.loads(response.get('body').read())
            summary = response_body.get('completion', '').strip()
            print("Generated summary:", summary)  # Debug logging
            
        except Exception as e:
            print("Bedrock API error:", str(e))  # Debug logging
            # Fallback to extractive summarization
            sentences = re.split(r'(?<=[.!?])\s+', cleaned_text)
            if len(sentences) <= 5:
                summary = cleaned_text
            else:
                summary = ' '.join(sentences[:min(5, len(sentences) // 3)])
        
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'OPTIONS,POST',
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'summary': summary
            })
        }
        
    except Exception as e:
        print("General error:", str(e))  # Debug logging
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'OPTIONS,POST',
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'error': str(e)
            })
        }