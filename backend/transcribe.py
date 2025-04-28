import json
import boto3
import os
import time
import sys # Added for exit codes
import urllib.parse
import urllib.request # Added for fetching transcript
from logger import logger # Assuming logger.py is still available

# --- Configuration --- 
# Read input parameters from environment variables passed by ECS
S3_BUCKET_ENV_VAR = 'S3_BUCKET' # Bucket containing input audio AND for output transcript
S3_KEY_ENV_VAR = 'S3_KEY' # Key of the input audio file in S3_BUCKET
JOB_NAME_ENV_VAR = 'JOB_NAME' # Unique job name passed from invoker
OUTPUT_PREFIX = "transcribe-results" # S3 prefix for results

# Initialize AWS clients
s3 = boto3.client('s3')
transcribe = boto3.client('transcribe')

def start_transcription_job(job_name, media_uri):
    """Starts an AWS Transcribe job."""
    logger.info(f"Starting transcription job: {job_name} for media: {media_uri}")
    try:
        # Note: Removed OutputBucketName/OutputKey - rely on TranscriptFileUri
        response = transcribe.start_transcription_job(
            TranscriptionJobName=job_name,
            Media={'MediaFileUri': media_uri},
            MediaFormat='webm', # IMPORTANT: Assumes invoker lambda saves as .webm
            LanguageCode='en-US' 
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
    except transcribe.exceptions.BadRequestException as e:
         # Can happen if job doesn't exist yet or was deleted
        logger.warning(f"BadRequestException getting status for job {job_name}: {str(e)}. Assuming FAILED.")
        return 'FAILED'
    except Exception as e:
        logger.error(f"Error getting status for job {job_name}: {str(e)}", exc_info=True)
        return 'FAILED' # Assume failure on other errors

def get_transcript(job_name):
    """Gets the transcript result from a completed job."""
    try:
        response = transcribe.get_transcription_job(TranscriptionJobName=job_name)
        # Check if transcript URI exists (might not if job failed early)
        if 'Transcript' not in response.get('TranscriptionJob', {}) or \
           'TranscriptFileUri' not in response['TranscriptionJob']['Transcript']:
            logger.error(f"TranscriptFileUri not found for job {job_name}. Status: {response.get('TranscriptionJob',{}).get('TranscriptionJobStatus')}")
            raise RuntimeError(f"Transcript URI not available for job {job_name}.")
            
        transcript_uri = response['TranscriptionJob']['Transcript']['TranscriptFileUri']
        logger.info(f"Transcript URI: {transcript_uri}")

        # Fetch the transcript JSON from the URI (usually an S3 presigned URL)
        with urllib.request.urlopen(transcript_uri) as url_response:
             transcript_data = json.loads(url_response.read().decode())
        
        # Check structure of transcript data
        if 'results' not in transcript_data or \
           'transcripts' not in transcript_data['results'] or \
           not isinstance(transcript_data['results']['transcripts'], list) or \
           len(transcript_data['results']['transcripts']) == 0 or \
           'transcript' not in transcript_data['results']['transcripts'][0]:
            logger.error(f"Unexpected transcript JSON structure for job {job_name}: {json.dumps(transcript_data)}")
            raise RuntimeError(f"Could not parse transcript from URI for job {job_name}.")
        
        transcript_text = transcript_data['results']['transcripts'][0]['transcript']
        logger.info(f"Successfully retrieved transcript text.")
        return transcript_text
        
    except Exception as e:
        logger.error(f"Error getting transcript for job {job_name}: {str(e)}", exc_info=True)
        # Don't raise here, allow calling function to handle status
        raise RuntimeError(f"Could not retrieve or parse transcript: {str(e)}")

# --- Main execution block for ECS Task --- 
if __name__ == "__main__":
    logger.info("Starting Transcribe ECS Task...")

    # --- Read parameters from Environment Variables --- 
    s3_bucket = os.environ.get(S3_BUCKET_ENV_VAR)
    s3_key = os.environ.get(S3_KEY_ENV_VAR)
    job_name = os.environ.get(JOB_NAME_ENV_VAR)
    
    if not s3_bucket or not s3_key or not job_name:
        missing_vars = [var for var, val in {S3_BUCKET_ENV_VAR: s3_bucket, S3_KEY_ENV_VAR: s3_key, JOB_NAME_ENV_VAR: job_name}.items() if not val]
        logger.error(f"Mandatory environment variables missing: {missing_vars}")
        sys.exit(1) # Exit with error code
        
    media_uri = f"s3://{s3_bucket}/{s3_key}"
    output_key = f"{OUTPUT_PREFIX}/{job_name}.txt" # Define S3 key for the result
    logger.info(f"Processing S3 media: {media_uri} with job name: {job_name}")
    logger.info(f"Result will be saved to s3://{s3_bucket}/{output_key}")
    
    final_transcript = None
    error_message = None
    job_status = None # Initialize job_status
    
    try:
        # --- Start Job --- 
        start_transcription_job(job_name, media_uri)

        # --- Poll for completion (Inefficient - Consider S3 Event/SQS/Step Functions) ---
        max_wait_time = 120 # seconds - Increased wait time
        poll_interval = 10  # seconds
        start_time = time.time()
        job_status = 'IN_PROGRESS'

        logger.info(f"Polling job {job_name} for completion (max {max_wait_time}s)... Warning: Inefficient polling.")
        while job_status == 'IN_PROGRESS' and (time.time() - start_time) < max_wait_time:
            time.sleep(poll_interval)
            job_status = get_transcription_job_status(job_name)
            logger.info(f"Polling job {job_name}, status: {job_status}")

        # --- Process Result --- 
        if job_status == 'COMPLETED':
            try:
                final_transcript = get_transcript(job_name)
                # Save result to S3
                try:
                    logger.info(f"Saving transcript to s3://{s3_bucket}/{output_key}")
                    s3.put_object(
                        Bucket=s3_bucket,
                        Key=output_key,
                        Body=final_transcript.encode('utf-8'),
                        ContentType='text/plain'
                    )
                    logger.info("Successfully saved transcript to S3.")
                except Exception as s3_e:
                    logger.error(f"Failed to save transcript to S3: {s3_e}", exc_info=True)
                    error_message = f"Job {job_name} completed but failed to save transcript to S3: {s3_e}"
                    final_transcript = None # Mark as failure if S3 save fails
                    
            except Exception as e:
                logger.error(f"Failed to retrieve transcript even though job {job_name} COMPLETED: {str(e)}")
                error_message = f"Job {job_name} completed but failed to retrieve transcript: {str(e)}"
        elif job_status == 'FAILED':
             logger.error(f"Transcription job {job_name} failed.")
             # Attempt to get failure reason if possible
             try:
                 job_info = transcribe.get_transcription_job(TranscriptionJobName=job_name)
                 failure_reason = job_info.get('TranscriptionJob', {}).get('FailureReason', 'Unknown reason')
                 error_message = f"Transcription job {job_name} failed: {failure_reason}"
             except Exception as e_get:
                 logger.error(f"Could not get failure reason for job {job_name}: {str(e_get)}")
                 error_message = f"Transcription job {job_name} failed. Could not get reason."
        else: # Timed out or unknown status
            logger.error(f"Transcription job {job_name} did not complete. Final status: {job_status}. Timeout after {max_wait_time} seconds.")
            error_message = f"Transcription job {job_name} timed out or has unexpected status {job_status}."

    except Exception as e:
        logger.error(f"An error occurred during transcription process for job {job_name}: {str(e)}", exc_info=True)
        error_message = f"Error during transcription process: {str(e)}"
        # Ensure job_status reflects failure if exception happens before polling finishes
        if job_status is None or job_status == 'IN_PROGRESS':
             job_status = 'FAILED' 

    # --- Exit based on outcome --- 
    if final_transcript is not None and error_message is None:
        logger.info(f"Transcribe task for job {job_name} completed successfully.")
        sys.exit(0)
    else:
        # Optionally write failure status to S3
        failure_output_key = f"{OUTPUT_PREFIX}/{job_name}. FAILED.txt"
        try:
            logger.error(f"Transcribe task for job {job_name} failed. Error: {error_message}. Saving failure notice to s3://{s3_bucket}/{failure_output_key}")
            s3.put_object(
                Bucket=s3_bucket,
                Key=failure_output_key,
                Body=f"Job Status: {job_status}\nError: {error_message}".encode('utf-8'),
                ContentType='text/plain'
            )
        except Exception as s3_fail_e:
             logger.error(f"Failed to save failure notice to S3: {s3_fail_e}")
             
        sys.exit(1)

# REMOVED: Original lambda_handler function
# def lambda_handler(event, context):
#    ...

# def start_transcription_job(job_name, media_uri):
#     """Starts an AWS Transcribe job."""
#     logger.info(f"Starting transcription job: {job_name} for media: {media_uri}")
#     try:
#         response = transcribe.start_transcription_job(
#             TranscriptionJobName=job_name,
#             Media={'MediaFileUri': media_uri},
#             MediaFormat='webm', # Assuming webm format from MediaRecorder, adjust if needed (e.g., 'mp3', 'wav')
#             LanguageCode='en-US' # Specify language code
#             # OutputBucketName=S3_BUCKET_NAME, # Optional: Specify where Transcribe puts the output JSON
#             # OutputKey=f'transcripts/{job_name}.json' # Optional: Specify output key
#         )
#         logger.info(f"Transcription job started: {response}")
#         return response
#     except Exception as e:
#         logger.error(f"Error starting transcription job {job_name}: {str(e)}", exc_info=True)
#         raise RuntimeError(f"Could not start transcription job: {str(e)}")

# def get_transcription_job_status(job_name):
#     """Gets the status of an AWS Transcribe job."""
#     try:
#         response = transcribe.get_transcription_job(TranscriptionJobName=job_name)
#         return response['TranscriptionJob']['TranscriptionJobStatus']
#     except Exception as e:
#         logger.error(f"Error getting status for job {job_name}: {str(e)}", exc_info=True)
#         return 'FAILED' # Assume failure on error

# def get_transcript(job_name):
#     """Gets the transcript result from a completed job."""
#     try:
#         response = transcribe.get_transcription_job(TranscriptionJobName=job_name)
#         transcript_uri = response['TranscriptionJob']['Transcript']['TranscriptFileUri']
#         logger.info(f"Transcript URI: {transcript_uri}")

#         # Fetch the transcript JSON from the URI (usually an S3 presigned URL)
#         # Using urllib instead of requests to avoid adding dependency if not already present
#         with urllib.request.urlopen(transcript_uri) as url_response:
#              transcript_data = json.loads(url_response.read().decode())
#         
#         transcript_text = transcript_data['results']['transcripts'][0]['transcript']
#         logger.info(f"Successfully retrieved transcript text.")
#         return transcript_text
#         
#     except Exception as e:
#         logger.error(f"Error getting transcript for job {job_name}: {str(e)}", exc_info=True)
#         raise RuntimeError(f"Could not retrieve transcript: {str(e)}")

# def lambda_handler(event, context):
#     """Main Lambda handler for Transcribe."""
#     logger.info(f"Transcribe Event received: {json.dumps(event)}")
#     
#     headers = {
#         'Access-Control-Allow-Origin': '*',
#         'Access-Control-Allow-Headers': 'Content-Type,Authorization',
#         'Access-Control-Allow-Methods': 'OPTIONS,POST'
#     }
#     
#     if event.get('requestContext', {}).get('http', {}).get('method') == 'OPTIONS':
#         return {'statusCode': 200, 'headers': headers, 'body': ''}

#     try:
#         if not S3_BUCKET_NAME:
#             raise ValueError("S3_BUCKET_NAME environment variable not set.")

#         body = json.loads(event.get('body', '{}'))
#         audio_base64 = body.get('audio_data') # Expecting base64 encoded audio string

#         if not audio_base64:
#             raise ValueError("Missing 'audio_data' (base64 encoded) in request body")

#         # Decode base64 audio data
#         try:
#             # Ensure correct base64 padding
#             missing_padding = len(audio_base64) % 4
#             if missing_padding:
#                 audio_base64 += '=' * (4 - missing_padding)
#             audio_bytes = base64.b64decode(audio_base64)
#             logger.info(f"Audio decoded successfully, size: {len(audio_bytes)} bytes")
#         except base64.binascii.Error as e:
#              logger.error(f"Base64 decoding error: {str(e)}")
#              raise ValueError(f"Invalid base64 audio data: {str(e)}")

#         # Upload audio to S3
#         job_uuid = str(uuid.uuid4())
#         s3_key = f"temp-audio/{job_uuid}.webm" # Match format in start_transcription_job
#         media_uri = f"s3://{S3_BUCKET_NAME}/{s3_key}"
#         
#         try:
#             s3.put_object(Bucket=S3_BUCKET_NAME, Key=s3_key, Body=audio_bytes)
#             logger.info(f"Audio uploaded to S3: {media_uri}")
#         except Exception as e:
#             logger.error(f"Error uploading audio to S3 {media_uri}: {str(e)}", exc_info=True)
#             raise RuntimeError(f"Failed to upload audio to S3: {str(e)}")

#         # Start transcription job
#         job_name = f"transcribe-{job_uuid}"
#         start_transcription_job(job_name, media_uri)

#         # Poll for job completion (with timeout)
#         max_wait_time = 60 # seconds
#         poll_interval = 5  # seconds
#         start_time = time.time()
#         job_status = 'IN_PROGRESS'

#         while job_status == 'IN_PROGRESS' and (time.time() - start_time) < max_wait_time:
#             time.sleep(poll_interval)
#             job_status = get_transcription_job_status(job_name)
#             logger.info(f"Polling job {job_name}, status: {job_status}")

#         # Process result
#         if job_status == 'COMPLETED':
#             transcript = get_transcript(job_name)
#             response_body = {'transcript': transcript}
#             status_code = 200
#         elif job_status == 'FAILED':
#              logger.error(f"Transcription job {job_name} failed.")
#              # Optionally get failure reason
#              # job = transcribe.get_transcription_job(TranscriptionJobName=job_name)
#              # failure_reason = job.get('TranscriptionJob', {}).get('FailureReason')
#              raise RuntimeError(f"Transcription job failed")
#         else: # Timed out
#              logger.error(f"Transcription job {job_name} timed out after {max_wait_time} seconds.")
#              raise RuntimeError("Transcription job timed out")
#             
#         # Optional: Clean up S3 audio file after processing
#         # try:
#         #    s3.delete_object(Bucket=S3_BUCKET_NAME, Key=s3_key)
#         #    logger.info(f"Deleted temporary audio file: {s3_key}")
#         # except Exception as e:
#         #    logger.warning(f"Failed to delete temporary audio file {s3_key}: {str(e)}")

#         return {
#             'statusCode': status_code,
#             'headers': headers,
#             'body': json.dumps(response_body)
#         }

#     except ValueError as e:
#          logger.error(f"Input validation error: {str(e)}")
#          return {
#             'statusCode': 400, 'headers': headers,
#             'body': json.dumps({'error': str(e)})}
#     except RuntimeError as e:
#          logger.error(f"Processing error: {str(e)}")
#          return {
#             'statusCode': 500, 'headers': headers,
#             'body': json.dumps({'error': f'Processing failed: {str(e)}'})}
#     except Exception as e:
#         logger.error(f"Unexpected error processing transcribe request: {str(e)}", exc_info=True)
#         return {
#             'statusCode': 500, 'headers': headers,
#             'body': json.dumps({'error': f'Internal server error: {str(e)}'})
#         } 