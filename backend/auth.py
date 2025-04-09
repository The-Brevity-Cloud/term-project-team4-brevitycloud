import json
import boto3
import os
import time
from botocore.exceptions import ClientError

cognito = boto3.client('cognito-idp')
dynamodb = boto3.resource('dynamodb')
user_table = dynamodb.Table(os.environ['USER_TABLE_NAME'])

def lambda_handler(event, context):
    try:
        # Add CORS headers
        headers = {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token',
            'Access-Control-Allow-Methods': 'OPTIONS,POST'
        }
        
        # Handle preflight requests
        if event['requestContext']['http']['method'] == 'OPTIONS':
            return {
                'statusCode': 200,
                'headers': headers,
                'body': ''
            }

        route = event['rawPath']
        body = json.loads(event['body']) if 'body' in event else {}
        
        # Print route for debugging
        print(f"Received request for route: {route}")
        
        # Check if route contains /auth/ and extract the relevant part
        if '/auth/' in route:
            auth_action = route.split('/auth/')[1]
            print(f"Auth action: {auth_action}")
            
            response = None
            if auth_action == 'register':
                response = handle_register(body)
            elif auth_action == 'login':
                response = handle_login(body)
            elif auth_action == 'verify':
                response = handle_verify(body)
            elif auth_action == 'resend-code':
                response = handle_resend_code(body)
            else:
                response = {
                    'statusCode': 400,
                    'body': json.dumps({'message': f'Invalid auth action: {auth_action}'})
                }
        else:
            response = {
                'statusCode': 400,
                'body': json.dumps({'message': f'Invalid route path: {route}. Expected /auth/ACTION format.'})
            }
        
        # Add CORS headers to response
        response['headers'] = headers
        return response
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({'message': f'Internal server error: {str(e)}'})
        }

def handle_register(body):
    try:
        email = body['email']
        password = body['password']
        client_id = body['clientId']
        
        # Create user in Cognito
        response = cognito.sign_up(
            ClientId=client_id,
            Username=email,
            Password=password,
            UserAttributes=[
                {
                    'Name': 'email',
                    'Value': email
                }
            ]
        )
        
        # Create user entry in DynamoDB
        user_table.put_item(
            Item={
                'user_id': email,
                'email': email,
                'created_at': int(time.time()),
                'summaries': []
            }
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Registration successful. Please check your email for verification code.',
                'userSub': response['UserSub']
            })
        }
    except ClientError as e:
        error_code = e.response['Error']['Code']
        if error_code == 'UsernameExistsException':
            return {
                'statusCode': 400,
                'body': json.dumps({'message': 'Email already registered'})
            }
        raise

def handle_login(body):
    try:
        email = body['email']
        password = body['password']
        client_id = body['clientId']
        
        # Authenticate user
        response = cognito.initiate_auth(
            ClientId=client_id,
            AuthFlow='USER_PASSWORD_AUTH',
            AuthParameters={
                'USERNAME': email,
                'PASSWORD': password
            }
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'idToken': response['AuthenticationResult']['IdToken'],
                'accessToken': response['AuthenticationResult']['AccessToken'],
                'refreshToken': response['AuthenticationResult']['RefreshToken']
            })
        }
    except ClientError as e:
        error_code = e.response['Error']['Code']
        if error_code == 'NotAuthorizedException':
            return {
                'statusCode': 401,
                'body': json.dumps({'message': 'Invalid credentials'})
            }
        elif error_code == 'UserNotConfirmedException':
            return {
                'statusCode': 403,
                'body': json.dumps({'message': 'Please verify your email first'})
            }
        raise

def handle_verify(body):
    try:
        email = body['email']
        code = body['code']
        client_id = body['clientId']
        
        # Verify email
        cognito.confirm_sign_up(
            ClientId=client_id,
            Username=email,
            ConfirmationCode=code
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Email verified successfully'})
        }
    except ClientError as e:
        error_code = e.response['Error']['Code']
        if error_code == 'CodeMismatchException':
            return {
                'statusCode': 400,
                'body': json.dumps({'message': 'Invalid verification code'})
            }
        elif error_code == 'ExpiredCodeException':
            return {
                'statusCode': 400,
                'body': json.dumps({'message': 'Verification code has expired'})
            }
        raise

def handle_resend_code(body):
    try:
        email = body['email']
        client_id = body['clientId']
        
        cognito.resend_confirmation_code(
            ClientId=client_id,
            Username=email
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Verification code has been resent'})
        }
    except ClientError as e:
        error_code = e.response['Error']['Code']
        if error_code == 'UserNotFoundException':
            return {
                'statusCode': 404,
                'body': json.dumps({'message': 'User not found'})
            }
        raise 