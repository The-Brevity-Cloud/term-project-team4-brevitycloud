import boto3
import hashlib
import json
import os
from urllib.parse import urlparse
import time
from logger import logger

# Initializing S3 client
s3 = boto3.client('s3')
S3_BUCKET_NAME = os.environ.get('S3_BUCKET_NAME')

def generate_url_hash(url):
    # Normalize URL by removing trailing slashes, query parameters if needed
    parsed_url = urlparse(url)
    normalized_url = f"{parsed_url.scheme}://{parsed_url.netloc}{parsed_url.path}"
    
    # Generate MD5 hash
    return hashlib.md5(normalized_url.encode('utf-8')).hexdigest()

def check_document_exists(url_hash):
    if not S3_BUCKET_NAME:
        logger.error("S3_BUCKET_NAME environment variable not set")
        return None
        
    metadata_key = f"shared/metadata/{url_hash}-meta.json"
    
    try:
        # Check if metadata file exists
        response = s3.head_object(Bucket=S3_BUCKET_NAME, Key=metadata_key)
        
        # If it exists, get the metadata file
        metadata_obj = s3.get_object(Bucket=S3_BUCKET_NAME, Key=metadata_key)
        metadata = json.loads(metadata_obj['Body'].read().decode('utf-8'))
        
        return metadata
    
    except Exception as e:
        if 'Not Found' in str(e) or '404' in str(e):
            # Document doesn't exist
            return None
        else:
            logger.error(f"Error checking document existence: {str(e)}")
            return None
        
def store_document(url, title, cleaned_text, raw_text=None):
    if not S3_BUCKET_NAME:
        logger.error("S3_BUCKET_NAME environment variable not set")
        return None
    
    url_hash = generate_url_hash(url)
    
    # Define the S3 keys
    content_key = f"shared/websites/{url_hash}.json"
    metadata_key = f"shared/metadata/{url_hash}-meta.json"
    
    try:
        # Check if document already exists
        existing_metadata = check_document_exists(url_hash)
        
        if existing_metadata:
            # Document exists, update metadata
            existing_metadata['visit_count'] = existing_metadata.get('visit_count', 0) + 1
            existing_metadata['last_accessed'] = int(time.time())
            
            # Check if content should be refreshed (e.g., if it's older than a week)
            if int(time.time()) - existing_metadata.get('last_updated', 0) > 604800:  # 7 days in seconds
                # Update content
                content_data = {
                    'url': url,
                    'title': title,
                    'cleaned_text': cleaned_text,
                    'raw_text': raw_text if raw_text else None
                }
                
                s3.put_object(
                    Bucket=S3_BUCKET_NAME,
                    Key=content_key,
                    Body=json.dumps(content_data),
                    ContentType='application/json'
                )
                
                existing_metadata['last_updated'] = int(time.time())
                
            # Update metadata file
            s3.put_object(
                Bucket=S3_BUCKET_NAME,
                Key=metadata_key,
                Body=json.dumps(existing_metadata),
                ContentType='application/json'
            )
            
            logger.info(f"Updated existing document for URL: {url}")
            return url_hash
            
        else:
            # Document doesn't exist, create new files
            # Create content file
            content_data = {
                'url': url,
                'title': title,
                'cleaned_text': cleaned_text,
                'raw_text': raw_text if raw_text else None
            }
            
            s3.put_object(
                Bucket=S3_BUCKET_NAME,
                Key=content_key,
                Body=json.dumps(content_data),
                ContentType='application/json'
            )
            
            # Create metadata file
            metadata = {
                'url': url,
                'title': title,
                'last_updated': int(time.time()),
                'last_accessed': int(time.time()),
                'visit_count': 1,
                'indexed_status': 'pending'
            }
            
            s3.put_object(
                Bucket=S3_BUCKET_NAME,
                Key=metadata_key,
                Body=json.dumps(metadata),
                ContentType='application/json'
            )
            
            logger.info(f"Created new document for URL: {url}")
            return url_hash
            
    except Exception as e:
        logger.error(f"Error storing document in S3: {str(e)}")
        return None
    
def get_document(url_hash):
    if not S3_BUCKET_NAME:
        logger.error("S3_BUCKET_NAME environment variable not set")
        return None
        
    content_key = f"shared/websites/{url_hash}.json"
    
    try:
        # Get the content file
        content_obj = s3.get_object(Bucket=S3_BUCKET_NAME, Key=content_key)
        content_data = json.loads(content_obj['Body'].read().decode('utf-8'))
        
        # Update the metadata to reflect this access
        metadata_key = f"shared/metadata/{url_hash}-meta.json"
        try:
            metadata_obj = s3.get_object(Bucket=S3_BUCKET_NAME, Key=metadata_key)
            metadata = json.loads(metadata_obj['Body'].read().decode('utf-8'))
            
            metadata['last_accessed'] = int(time.time())
            metadata['visit_count'] = metadata.get('visit_count', 0) + 1
            
            s3.put_object(
                Bucket=S3_BUCKET_NAME,
                Key=metadata_key,
                Body=json.dumps(metadata),
                ContentType='application/json'
            )
        except Exception as e:
            logger.warning(f"Could not update metadata for {url_hash}: {str(e)}")
        
        return content_data
        
    except Exception as e:
        logger.error(f"Error retrieving document from S3: {str(e)}")
        return None
    
def update_indexed_status(url_hash, status='complete'):
    if not S3_BUCKET_NAME:
        logger.error("S3_BUCKET_NAME environment variable not set")
        return False
        
    metadata_key = f"shared/metadata/{url_hash}-meta.json"
    
    try:
        # Get the current metadata
        metadata_obj = s3.get_object(Bucket=S3_BUCKET_NAME, Key=metadata_key)
        metadata = json.loads(metadata_obj['Body'].read().decode('utf-8'))
        
        # Update the indexed status
        metadata['indexed_status'] = status
        
        # Write back the updated metadata
        s3.put_object(
            Bucket=S3_BUCKET_NAME,
            Key=metadata_key,
            Body=json.dumps(metadata),
            ContentType='application/json'
        )
        
        return True
        
    except Exception as e:
        logger.error(f"Error updating indexed status for {url_hash}: {str(e)}")
        return False