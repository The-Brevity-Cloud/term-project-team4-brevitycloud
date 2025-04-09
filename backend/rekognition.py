import json
import boto3
import base64
import os
import io
import requests
from logger import logger

# Initialize AWS clients
rekognition = boto3.client('rekognition')

def detect_text_from_url(image_url):
    """Downloads image from URL and detects text using Rekognition."""
    try:
        logger.info(f"Fetching image from URL: {image_url}")
        response = requests.get(image_url, stream=True, timeout=10) # Added timeout
        response.raise_for_status() # Raise HTTPError for bad responses (4xx or 5xx)

        # Check if the content type is an image
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
        
        logger.info(f"Detected {len(detected_lines)} lines of text.")
        return "\n".join(detected_lines)

    except requests.exceptions.RequestException as e:
        logger.error(f"Error fetching image from URL {image_url}: {str(e)}", exc_info=True)
        raise ConnectionError(f"Could not fetch image from URL: {str(e)}")
    except ValueError as e:
        raise e # Re-raise the specific ValueError
    except Exception as e:
        logger.error(f"Rekognition error for URL {image_url}: {str(e)}", exc_info=True)
        # Consider specific boto3 client errors if needed
        raise RuntimeError(f"Failed to detect text using Rekognition: {str(e)}")

def lambda_handler(event, context):
    """Main Lambda handler for Rekognition."""
    logger.info(f"Rekognition Event received: {json.dumps(event)}")
    
    # CORS Headers (same as other lambdas)
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'OPTIONS,POST'
    }
    
    # Handle OPTIONS request
    if event.get('requestContext', {}).get('http', {}).get('method') == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': headers,
            'body': ''
        }

    try:
        body = json.loads(event.get('body', '{}'))
        image_url = body.get('image_url')

        if not image_url:
            raise ValueError("Missing 'image_url' in request body")

        detected_text = detect_text_from_url(image_url)

        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({'detected_text': detected_text})
        }

    except ValueError as e: # Specific error for bad input
         logger.error(f"Input validation error: {str(e)}")
         return {
            'statusCode': 400,
            'headers': headers,
            'body': json.dumps({'error': str(e)})
        }
    except ConnectionError as e: # Specific error for fetching image
         logger.error(f"Image fetching error: {str(e)}")
         return {
            'statusCode': 502, # Bad Gateway might be appropriate
            'headers': headers,
            'body': json.dumps({'error': str(e)}) 
        }
    except Exception as e:
        logger.error(f"Error processing rekognition request: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({'error': f'Internal server error: {str(e)}'})
        } 