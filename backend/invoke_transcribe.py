import json
import boto3
import os
import logging
import uuid
import base64 # Needed for decoding audio

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ecs_client = boto3.client('ecs')
s3_client = boto3.client('s3') # Added S3 client

# Environment variable for the bucket where temporary audio is uploaded
TEMP_AUDIO_BUCKET_ENV_VAR = 'TEMP_AUDIO_BUCKET' 
TEMP_AUDIO_PREFIX = "temp-audio" # S3 prefix for uploaded audio

def lambda_handler(event, context):
    logger.info(f"Received event: {json.dumps(event)}")

    # --- Extract necessary parameters from the event ---
    try:
        body = json.loads(event.get('body', '{}'))
        audio_base64 = body.get('audio_data')
        if not audio_base64:
            raise ValueError("Missing 'audio_data' (base64 encoded) in request body")
            
        # Decode base64 audio data
        try:
            missing_padding = len(audio_base64) % 4
            if missing_padding:
                audio_base64 += '=' * (4 - missing_padding)
            audio_bytes = base64.b64decode(audio_base64)
            logger.info(f"Audio decoded successfully, size: {len(audio_bytes)} bytes")
        except base64.binascii.Error as e:
             logger.error(f"Base64 decoding error: {str(e)}")
             raise ValueError(f"Invalid base64 audio data: {str(e)}")
             
    except Exception as e:
        logger.error(f"Error parsing input event or decoding audio: {e}")
        return {
            'statusCode': 400,
            'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': 'Invalid input format or audio data', 'details': str(e)})
        }

    # --- Get Configuration from Environment Variables ---
    try:
        cluster_name = os.environ['ECS_CLUSTER_ARN']
        task_definition_arn = os.environ['TRANSCRIBE_TASK_DEF_ARN']
        subnet_ids_str = os.environ['PRIVATE_SUBNET_IDS']
        security_group_id = os.environ['TASK_SECURITY_GROUP_ID']
        temp_audio_bucket = os.environ[TEMP_AUDIO_BUCKET_ENV_VAR]
        private_subnets = subnet_ids_str.split(',')
    except KeyError as e:
        logger.error(f"Missing environment variable: {e}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': 'Internal configuration error', 'details': f'Missing env var: {e}'})
        }

    # --- Upload audio to S3 --- 
    job_uuid = str(uuid.uuid4())
    s3_key = f"{TEMP_AUDIO_PREFIX}/{job_uuid}.webm" # Assuming webm
    transcribe_job_name = f"transcribe-{job_uuid}"
    
    try:
        s3_client.put_object(Bucket=temp_audio_bucket, Key=s3_key, Body=audio_bytes, ContentType='audio/webm')
        logger.info(f"Audio uploaded to S3: s3://{temp_audio_bucket}/{s3_key}")
    except Exception as e:
        logger.error(f"Error uploading audio to S3: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': 'Failed to upload audio to S3', 'details': str(e)})
        }
        
    # --- Prepare Environment Variables for the Container --- 
    container_environment = [
        {
            'name': 'S3_BUCKET', 
            'value': temp_audio_bucket # Bucket where audio IS and results WILL BE saved
        },
        {
            'name': 'S3_KEY', # Key of the input audio
            'value': s3_key
        },
        {
            'name': 'JOB_NAME', # Unique name for the transcribe job AND result file
            'value': transcribe_job_name
        }
    ]

    logger.info(f"Attempting to run Transcribe task {transcribe_job_name} with definition {task_definition_arn}...")

    # --- Run the ECS Task --- 
    try:
        response = ecs_client.run_task(
            cluster=cluster_name,
            launchType='FARGATE',
            taskDefinition=task_definition_arn,
            count=1,
            platformVersion='LATEST',
            networkConfiguration={
                'awsvpcConfiguration': {
                    'subnets': private_subnets,
                    'securityGroups': [security_group_id],
                    'assignPublicIp': 'DISABLED'
                }
            },
            overrides={
                'containerOverrides': [
                    {
                        'name': 'transcribe-container', 
                        'environment': container_environment
                    }
                ]
            }
        )
        logger.info(f"ECS RunTask response: {response}")

        if not response.get('tasks'):
             raise Exception(f"Failed to start ECS task. Failures: {response.get('failures', [])}")

        task_arn = response['tasks'][0]['taskArn']
        logger.info(f"Successfully started task: {task_arn}")
        
        # Return JobName so caller can potentially track/find the result in S3
        return {
            'statusCode': 202, # Accepted
            'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'message': 'Transcribe task submitted successfully', 'jobName': transcribe_job_name, 'taskArn': task_arn})
        }

    except Exception as e:
        logger.error(f"Error calling RunTask: {e}", exc_info=True)
        # Attempt to clean up the uploaded S3 object if RunTask fails
        try: 
            s3_client.delete_object(Bucket=temp_audio_bucket, Key=s3_key)
            logger.info(f"Cleaned up temporary audio file s3://{temp_audio_bucket}/{s3_key} after RunTask failure.")
        except Exception as cleanup_e:
             logger.error(f"Failed to cleanup temporary audio file s3://{temp_audio_bucket}/{s3_key} after RunTask failure: {cleanup_e}")
             
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': 'Failed to start ECS task', 'details': str(e)})
        } 