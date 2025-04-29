import json
import boto3
import base64
import os
import io
import requests
import sys
from logger import logger

# --- Configuration --- 
IMAGE_URL_ENV_VAR = 'IMAGE_URL'
JOB_ID_ENV_VAR = 'JOB_ID' # Passed from invoker Lambda
S3_BUCKET_ENV_VAR = 'S3_BUCKET' # Bucket for output
OUTPUT_PREFIX = "rekognition-results"

# Initialize AWS clients
rekognition = boto3.client('rekognition')
s3 = boto3.client('s3')

def detect_text_from_url(image_url):
    """Downloads image from URL and detects text using Rekognition."""
    try:
        logger.info(f"Fetching image from URL: {image_url}")
        response = requests.get(image_url, stream=True, timeout=15) # Increased timeout slightly
        response.raise_for_status() 

        content_type = response.headers.get('content-type')
        if not content_type or not content_type.startswith('image/'):
            logger.error(f"URL does not point to a valid image. Content-Type: {content_type}")
            raise ValueError("URL does not point to a valid image.")

        image_bytes = response.content
        logger.info(f"Image downloaded successfully, size: {len(image_bytes)} bytes")

        rekognition_response = rekognition.detect_text(Image={'Bytes': image_bytes})
        
        detected_lines = []
        for text_detection in rekognition_response.get('TextDetections', []):
            if text_detection.get('Type') == 'LINE':
                detected_lines.append(text_detection.get('DetectedText'))
        
        detected_text = "\n".join(detected_lines)
        logger.info(f"Detected {len(detected_lines)} lines of text.")
        return detected_text

    except requests.exceptions.RequestException as e:
        logger.error(f"Error fetching image from URL {image_url}: {str(e)}", exc_info=True)
        raise ConnectionError(f"Could not fetch image from URL: {str(e)}")
    except ValueError as e:
        raise e 
    except Exception as e:
        logger.error(f"Rekognition error for URL {image_url}: {str(e)}", exc_info=True)
        raise RuntimeError(f"Failed to detect text using Rekognition: {str(e)}")

# --- Main execution block for ECS Task --- 
if __name__ == "__main__":
    logger.info("Starting Rekognition ECS Task...")
    
    image_url = os.environ.get(IMAGE_URL_ENV_VAR)
    job_id = os.environ.get(JOB_ID_ENV_VAR)
    s3_bucket = os.environ.get(S3_BUCKET_ENV_VAR)
    
    # Validate mandatory environment variables
    if not image_url or not job_id or not s3_bucket:
        missing_vars = []
        if not image_url: missing_vars.append(IMAGE_URL_ENV_VAR)
        if not job_id: missing_vars.append(JOB_ID_ENV_VAR)
        if not s3_bucket: missing_vars.append(S3_BUCKET_ENV_VAR)
        logger.error(f"Mandatory environment variables missing: {missing_vars}")
        sys.exit(1) 
        
    logger.info(f"Processing image URL: {image_url} for Job ID: {job_id}")
    output_key = f"{OUTPUT_PREFIX}/{job_id}.txt"
    
    try:
        detected_text_result = detect_text_from_url(image_url)
        
        # Save result to S3
        try:
            logger.info(f"Saving detected text to s3://{s3_bucket}/{output_key}")
            s3.put_object(
                Bucket=s3_bucket,
                Key=output_key,
                Body=detected_text_result.encode('utf-8'), # Encode string to bytes
                ContentType='text/plain'
            )
            logger.info("Successfully saved result to S3.")
        except Exception as s3_e:
            logger.error(f"Failed to save result to S3: {s3_e}", exc_info=True)
            # Treat S3 save failure as a task failure
            raise RuntimeError(f"Failed to save result to S3: {s3_e}")

        logger.info("Rekognition task completed successfully.")
        sys.exit(0) 
        
    except (ValueError, ConnectionError, RuntimeError) as e:
        logger.error(f"Rekognition task failed: {str(e)}")
        # TODO: Optionally write failure status/reason to S3/DynamoDB?
        sys.exit(1) 
    except Exception as e:
        logger.error(f"An unexpected error occurred: {str(e)}", exc_info=True)
        sys.exit(1) 

# REMOVED: Original lambda_handler function
# def lambda_handler(event, context):
#    ...

# def lambda_handler(event, context):
#     """Main Lambda handler for Rekognition."""
#     logger.info(f"Rekognition Event received: {json.dumps(event)}")
#     
#     # CORS Headers (same as other lambdas)
#     headers = {
#         'Access-Control-Allow-Origin': '*',
#         'Access-Control-Allow-Headers': 'Content-Type,Authorization',
#         'Access-Control-Allow-Methods': 'OPTIONS,POST'
#     }
#     
#     # Handle OPTIONS request
#     if event.get('requestContext', {}).get('http', {}).get('method') == 'OPTIONS':
#         return {
#             'statusCode': 200,
#             'headers': headers,
#             'body': ''
#         }
#
#     try:
#         body = json.loads(event.get('body', '{}'))
#         image_url = body.get('image_url')
#
#         if not image_url:
#             raise ValueError("Missing 'image_url' in request body")
#
#         detected_text = detect_text_from_url(image_url)
#
#         return {
#             'statusCode': 200,
#             'headers': headers,
#             'body': json.dumps({'detected_text': detected_text})
#         }
#
#     except ValueError as e: # Specific error for bad input
#          logger.error(f"Input validation error: {str(e)}")
#          return {
#             'statusCode': 400,
#             'headers': headers,
#             'body': json.dumps({'error': str(e)})
#         }
#     except ConnectionError as e: # Specific error for fetching image
#          logger.error(f"Image fetching error: {str(e)}")
#          return {
#             'statusCode': 502, # Bad Gateway might be appropriate
#             'headers': headers,
#             'body': json.dumps({'error': str(e)}) 
#         }
#     except Exception as e:
#         logger.error(f"Error processing rekognition request: {str(e)}", exc_info=True)
#         return {
#             'statusCode': 500,
#             'headers': headers,
#             'body': json.dumps({'error': f'Internal server error: {str(e)}'})
#         } 