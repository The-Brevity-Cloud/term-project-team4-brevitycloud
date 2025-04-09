import json
import boto3
import base64
import os
import time
import uuid
import urllib.parse
from logger import logger

# Initialize AWS clients
s3 = boto3.client('s3')
transcribe = boto3.client('transcribe')

S3_BUCKET_NAME = os.environ.get('S3_BUCKET_NAME')

def start_transcription_job(job_name, media_uri):
    """Starts an AWS Transcribe job."""
    logger.info(f"Starting transcription job: {job_name} for media: {media_uri}")
    try:
        response = transcribe.start_transcription_job(
            TranscriptionJobName=job_name,
            Media={'MediaFileUri': media_uri},
            MediaFormat='webm', # Assuming webm format from MediaRecorder, adjust if needed (e.g., 'mp3', 'wav')
            LanguageCode='en-US' # Specify language code
            # OutputBucketName=S3_BUCKET_NAME, # Optional: Specify where Transcribe puts the output JSON
            # OutputKey=f'transcripts/{job_name}.json' # Optional: Specify output key
        )
        logger.info(f"Transcription job started: {response}")
        return response
    except Exception as e:
        logger.error(f"Error starting transcription job {job_name}: {str(e)}", exc_info=True)
        raise RuntimeError(f"Could not start transcription job: {str(e)}")

def get_transcription_job_status(job_name):
    """Gets the status of an AWS Transcribe job."""
    try:
        response = transcribe.get_transcription_job(TranscriptionJobName=job_name)
        return response['TranscriptionJob']['TranscriptionJobStatus']
    except Exception as e:
        logger.error(f"Error getting status for job {job_name}: {str(e)}", exc_info=True)
        return 'FAILED' # Assume failure on error

def get_transcript(job_name):
    """Gets the transcript result from a completed job."""
    try:
        response = transcribe.get_transcription_job(TranscriptionJobName=job_name)
        transcript_uri = response['TranscriptionJob']['Transcript']['TranscriptFileUri']
        logger.info(f"Transcript URI: {transcript_uri}")

        # Fetch the transcript JSON from the URI (usually an S3 presigned URL)
        # Using urllib instead of requests to avoid adding dependency if not already present
        with urllib.request.urlopen(transcript_uri) as url_response:
             transcript_data = json.loads(url_response.read().decode())
        
        transcript_text = transcript_data['results']['transcripts'][0]['transcript']
        logger.info(f"Successfully retrieved transcript text.")
        return transcript_text
        
    except Exception as e:
        logger.error(f"Error getting transcript for job {job_name}: {str(e)}", exc_info=True)
        raise RuntimeError(f"Could not retrieve transcript: {str(e)}")

def lambda_handler(event, context):
    """Main Lambda handler for Transcribe."""
    logger.info(f"Transcribe Event received: {json.dumps(event)}")
    
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'OPTIONS,POST'
    }
    
    if event.get('requestContext', {}).get('http', {}).get('method') == 'OPTIONS':
        return {'statusCode': 200, 'headers': headers, 'body': ''}

    try:
        if not S3_BUCKET_NAME:
            raise ValueError("S3_BUCKET_NAME environment variable not set.")

        body = json.loads(event.get('body', '{}'))
        audio_base64 = body.get('audio_data') # Expecting base64 encoded audio string

        if not audio_base64:
            raise ValueError("Missing 'audio_data' (base64 encoded) in request body")

        # Decode base64 audio data
        try:
            # Ensure correct base64 padding
            missing_padding = len(audio_base64) % 4
            if missing_padding:
                audio_base64 += '=' * (4 - missing_padding)
            audio_bytes = base64.b64decode(audio_base64)
            logger.info(f"Audio decoded successfully, size: {len(audio_bytes)} bytes")
        except base64.binascii.Error as e:
             logger.error(f"Base64 decoding error: {str(e)}")
             raise ValueError(f"Invalid base64 audio data: {str(e)}")

        # Upload audio to S3
        job_uuid = str(uuid.uuid4())
        s3_key = f"temp-audio/{job_uuid}.webm" # Match format in start_transcription_job
        media_uri = f"s3://{S3_BUCKET_NAME}/{s3_key}"
        
        try:
            s3.put_object(Bucket=S3_BUCKET_NAME, Key=s3_key, Body=audio_bytes)
            logger.info(f"Audio uploaded to S3: {media_uri}")
        except Exception as e:
            logger.error(f"Error uploading audio to S3 {media_uri}: {str(e)}", exc_info=True)
            raise RuntimeError(f"Failed to upload audio to S3: {str(e)}")

        # Start transcription job
        job_name = f"transcribe-{job_uuid}"
        start_transcription_job(job_name, media_uri)

        # Poll for job completion (with timeout)
        max_wait_time = 60 # seconds
        poll_interval = 5  # seconds
        start_time = time.time()
        job_status = 'IN_PROGRESS'

        while job_status == 'IN_PROGRESS' and (time.time() - start_time) < max_wait_time:
            time.sleep(poll_interval)
            job_status = get_transcription_job_status(job_name)
            logger.info(f"Polling job {job_name}, status: {job_status}")

        # Process result
        if job_status == 'COMPLETED':
            transcript = get_transcript(job_name)
            response_body = {'transcript': transcript}
            status_code = 200
        elif job_status == 'FAILED':
             logger.error(f"Transcription job {job_name} failed.")
             # Optionally get failure reason
             # job = transcribe.get_transcription_job(TranscriptionJobName=job_name)
             # failure_reason = job.get('TranscriptionJob', {}).get('FailureReason')
             raise RuntimeError(f"Transcription job failed")
        else: # Timed out
            logger.error(f"Transcription job {job_name} timed out after {max_wait_time} seconds.")
            raise RuntimeError("Transcription job timed out")
            
        # Optional: Clean up S3 audio file after processing
        # try:
        #    s3.delete_object(Bucket=S3_BUCKET_NAME, Key=s3_key)
        #    logger.info(f"Deleted temporary audio file: {s3_key}")
        # except Exception as e:
        #    logger.warning(f"Failed to delete temporary audio file {s3_key}: {str(e)}")

        return {
            'statusCode': status_code,
            'headers': headers,
            'body': json.dumps(response_body)
        }

    except ValueError as e:
         logger.error(f"Input validation error: {str(e)}")
         return {
            'statusCode': 400, 'headers': headers,
            'body': json.dumps({'error': str(e)})}
    except RuntimeError as e:
         logger.error(f"Processing error: {str(e)}")
         return {
            'statusCode': 500, 'headers': headers,
            'body': json.dumps({'error': f'Processing failed: {str(e)}'})}
    except Exception as e:
        logger.error(f"Unexpected error processing transcribe request: {str(e)}", exc_info=True)
        return {
            'statusCode': 500, 'headers': headers,
            'body': json.dumps({'error': f'Internal server error: {str(e)}'})
        } 