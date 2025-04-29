import json
import boto3
import os
import logging
import uuid

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ecs_client = boto3.client('ecs')

def lambda_handler(event, context):
    logger.info(f"Received event: {json.dumps(event)}")

    try:
        body = json.loads(event.get('body', '{}'))
        image_url = body.get('image_url')
        if not image_url:
            raise ValueError("Missing 'image_url' in request body")

    except Exception as e:
        logger.error(f"Error parsing input event: {e}")
        return {
            'statusCode': 400,
            'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': 'Invalid input format', 'details': str(e)})
        }

    try:
        cluster_name = os.environ['ECS_CLUSTER_ARN'] 
        task_definition_arn = os.environ['REKOGNITION_TASK_DEF_ARN']
        subnet_ids_str = os.environ['PRIVATE_SUBNET_IDS']
        security_group_id = os.environ['TASK_SECURITY_GROUP_ID']
        s3_bucket = os.environ['S3_BUCKET'] # Get S3 bucket from env vars
        private_subnets = subnet_ids_str.split(',')
    except KeyError as e:
        logger.error(f"Missing environment variable: {e}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': 'Internal configuration error', 'details': f'Missing env var: {e}'})
        }

    # Generate a unique Job ID for this request
    job_id = str(uuid.uuid4())
    
    container_environment = [
        {
            'name': 'IMAGE_URL', # Corresponds to IMAGE_URL_ENV_VAR in rekognition.py
            'value': image_url
        },
        {
            'name': 'JOB_ID', # Corresponds to JOB_ID_ENV_VAR in rekognition.py
            'value': job_id
        },
        {
             'name': 'S3_BUCKET', # Corresponds to S3_BUCKET_ENV_VAR in rekognition.py
             'value': s3_bucket
        }
    ]

    logger.info(f"Attempting to run Rekognition task {job_id} with definition {task_definition_arn}...")

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
                        'name': 'rekognition-container', 
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
        
        # Return JobID so caller can potentially track/find the result in S3
        return {
            'statusCode': 202, # Accepted
            'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'message': 'Rekognition task submitted successfully', 'jobId': job_id, 'taskArn': task_arn})
        }

    except Exception as e:
        logger.error(f"Error calling RunTask: {e}", exc_info=True)
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': 'Failed to start ECS task', 'details': str(e)})
        } 