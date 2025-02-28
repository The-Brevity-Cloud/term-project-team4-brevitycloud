import json
import boto3
import os
import re

def clean_text(text):
    # Remove excessive whitespace, normalize line breaks
    text = re.sub(r'\n\s*\n', '\n\n', text)
    return text.strip()

def lambda_handler(event, context):
    try:
        # Parse request body
        body = json.loads(event['body'])
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
            prompt = f"""Human: I need a concise summary of the following web content. Focus on key points and main ideas only:

            {cleaned_text}

            Please provide a clear, well-structured summary that captures the essential information in 3-5 sentences.

            Assistant:"""
            
            # Call Bedrock model (using Claude or another available model)
            response = bedrock_runtime.invoke_model(
                modelId='anthropic.claude-v2',  # Or another available model
                body=json.dumps({
                    "prompt": prompt,
                    "max_tokens_to_sample": 500,
                    "temperature": 0.5,
                    "top_p": 0.9,
                })
            )
            
            # Parse response
            response_body = json.loads(response['body'].read().decode('utf-8'))
            summary = response_body.get('completion', '')
            
        except Exception as e:
            # Fallback to a simple extractive approach if Bedrock fails
            # This is a very basic implementation for the POC
            sentences = re.split(r'(?<=[.!?])\s+', cleaned_text)
            if len(sentences) <= 5:
                summary = cleaned_text
            else:
                # Simple extractive summarization - take first 3-5 sentences
                summary = ' '.join(sentences[:min(5, len(sentences) // 3)])
        
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'OPTIONS,POST'
            },
            'body': json.dumps({
                'summary': summary
            })
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'OPTIONS,POST'
            },
            'body': json.dumps({'error': str(e)})
        }