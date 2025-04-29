import json
import boto3
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client = boto3.client('s3')

# Environment variables expected:
# - S3_BUCKET: The bucket where results are stored
# - REKOGNITION_PREFIX: e.g., "rekognition-results"
# - TRANSCRIBE_PREFIX: e.g., "transcribe-results"

def lambda_handler(event, context):
    logger.info(f"Received event: {json.dumps(event)}")
    
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'OPTIONS,GET' # Allow GET
    }
    
    # Handle OPTIONS request for CORS
    if event.get('requestContext', {}).get('http', {}).get('method') == 'OPTIONS':
        return {'statusCode': 200, 'headers': headers, 'body': ''}
        
    try:
        s3_bucket = os.environ['S3_BUCKET']
        rekognition_prefix = os.environ['REKOGNITION_PREFIX']
        transcribe_prefix = os.environ['TRANSCRIBE_PREFIX']
    except KeyError as e:
        logger.error(f"Missing environment variable: {e}")
        return {
            'statusCode': 500, 'headers': headers,
            'body': json.dumps({'error': 'Internal configuration error', 'details': f'Missing env var: {e}'})
        }
        
    try:
        # Extract job ID and type from path/query parameters
        job_id = event.get('pathParameters', {}).get('jobId')
        result_type = event.get('queryStringParameters', {}).get('type', 'rekognition') # Default or require type?

        if not job_id:
            raise ValueError("Missing 'jobId' in path parameters")
        
        logger.info(f"Checking status for Job ID: {job_id}, Type: {result_type}")

        result_key = None
        failure_key = None
        
        if result_type == 'rekognition':
            result_key = f"{rekognition_prefix}/{job_id}.txt"
            # Failure status for Rekognition isn't explicitly saved currently
        elif result_type == 'transcribe':
            result_key = f"{transcribe_prefix}/{job_id}.txt"
            failure_key = f"{transcribe_prefix}/{job_id}.FAILED.txt"
        else:
            raise ValueError(f"Invalid result type specified: {result_type}")

        # Check for successful result file
        try:
            logger.debug(f"Checking for result file: s3://{s3_bucket}/{result_key}")
            response = s3_client.get_object(Bucket=s3_bucket, Key=result_key)
            content = response['Body'].read().decode('utf-8')
            logger.info(f"Result found for job {job_id}")
            return {
                'statusCode': 200,
                'headers': headers,
                'body': json.dumps({'status': 'COMPLETED', 'result': content})
            }
        except s3_client.exceptions.NoSuchKey:
            logger.info(f"Result file not found yet for job {job_id}. Checking for failure...")
            # Fall through to check failure key or return PENDING
        except Exception as e:
            logger.error(f"Error retrieving result file s3://{s3_bucket}/{result_key}: {e}")
            # Return PENDING on error to allow retries, or consider a different status
            return {
                'statusCode': 202, # Still processing / temporarily unavailable
                'headers': headers,
                'body': json.dumps({'status': 'PENDING', 'detail': f'Error checking result: {e}'})
            }
            
        # Check for failure file (currently only for transcribe)
        if failure_key:
            try:
                logger.debug(f"Checking for failure file: s3://{s3_bucket}/{failure_key}")
                response = s3_client.get_object(Bucket=s3_bucket, Key=failure_key)
                failure_reason = response['Body'].read().decode('utf-8')
                logger.error(f"Failure file found for job {job_id}. Reason: {failure_reason}")
                return {
                    'statusCode': 200, # Found a definitive FAILED status
                    'headers': headers,
                    'body': json.dumps({'status': 'FAILED', 'error': failure_reason})
                }
            except s3_client.exceptions.NoSuchKey:
                logger.info(f"Failure file not found for job {job_id}. Status is PENDING.")
                # Return PENDING as neither result nor failure file exists
            except Exception as e:
                 logger.error(f"Error retrieving failure file s3://{s3_bucket}/{failure_key}: {e}")
                 # Return PENDING on error to allow retries
                 return {
                     'statusCode': 202, 
                     'headers': headers,
                     'body': json.dumps({'status': 'PENDING', 'detail': f'Error checking failure file: {e}'})
                 }
                 
        # If no result or failure file found
        return {
            'statusCode': 202, # Still processing
            'headers': headers,
            'body': json.dumps({'status': 'PENDING', 'detail': 'Result not yet available.'})
        }

    except ValueError as e:
         logger.error(f"Input validation error: {str(e)}")
         return {
            'statusCode': 400, 'headers': headers,
            'body': json.dumps({'error': str(e)})}
    except Exception as e:
        logger.error(f"Unexpected error checking result: {str(e)}", exc_info=True)
        return {
            'statusCode': 500, 'headers': headers,
            'body': json.dumps({'error': f'Internal server error: {str(e)}'})
        } 