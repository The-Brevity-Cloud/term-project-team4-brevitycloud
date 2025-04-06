import hashlib
import re
import boto3
from logger import logger
from s3_helper import generate_url_hash, update_indexed_status, get_document

def generate_document_id(content, title=""):
    """Updated function to use hash based url encoding for S3 bucket storing"""
    # For URL-based content, we'll use the URL hash as the document ID
    if title.startswith(('http://', 'https://')):
        return generate_url_hash(title)
    
    # Otherwise, fallback to content hash for non-URL content
    content_sample = content[:1000]  # Use first 1000 chars to avoid large hash calculations
    hash_input = (title + content_sample).encode('utf-8')
    return hashlib.md5(hash_input).hexdigest()

def split_into_chunks(text, max_chunk_size=5000):
    """Split text into manageable chunks for Kendra indexing"""
    # First try to split by paragraphs
    paragraphs = re.split(r'\n\n+', text)
    chunks = []
    current_chunk = ""
    
    for paragraph in paragraphs:
        if len(current_chunk) + len(paragraph) <= max_chunk_size:
            current_chunk += paragraph + "\n\n"
        else:
            if current_chunk:
                chunks.append(current_chunk.strip())
            current_chunk = paragraph + "\n\n"
    
    # Add the last chunk if it exists
    if current_chunk:
        chunks.append(current_chunk.strip())
    
    # If we have no chunks (e.g., a single huge paragraph), split by sentences
    if not chunks:
        sentences = re.split(r'(?<=[.!?])\s+', text)
        current_chunk = ""
        
        for sentence in sentences:
            if len(current_chunk) + len(sentence) <= max_chunk_size:
                current_chunk += sentence + " "
            else:
                if current_chunk:
                    chunks.append(current_chunk.strip())
                current_chunk = sentence + " "
        
        if current_chunk:
            chunks.append(current_chunk.strip())
    
    return chunks

def index_in_kendra(chunks, doc_id, title, index_id):
    """Index content chunks in Kendra"""
    kendra_client = boto3.client('kendra')
    
    responses = []
    for i, chunk in enumerate(chunks):
        chunk_id = f"{doc_id}_chunk_{i}"
        
        try:
            response = kendra_client.batch_put_document(
                IndexId=index_id,
                Documents=[{
                    'Id': chunk_id,
                    'Title': f"{title} - Part {i+1}" if title else f"Document Part {i+1}",
                    'Blob': chunk.encode(),
                    'ContentType': 'PLAIN_TEXT',
                    'Attributes': [
                        {'Key': 'document_id', 'Value': {'StringValue': doc_id}},
                        {'Key': 'chunk_number', 'Value': {'LongValue': i}},
                        {'Key': 'source_url', 'Value': {'StringValue': title if title.startswith(('http://', 'https://')) else 'manual-input'}}
                    ]
                }]
            )
            responses.append(response)
            
            # If this is URL-based content, update the indexed status in S3
            if title.startswith(('http://', 'https://')):
                url_hash = generate_url_hash(title)
                update_indexed_status(url_hash, 'complete')
                
        except Exception as e:
            logger.error(f"Error indexing chunk {i}: {str(e)}")
            
            # Mark indexing as failed in S3 if URL-based
            if title.startswith(('http://', 'https://')):
                url_hash = generate_url_hash(title)
                update_indexed_status(url_hash, 'failed')
    
    return responses

def query_kendra(doc_id, index_id, query_text="What are the main points and key information in this document?"):
    """Query Kendra for the most relevant content from the document"""
    kendra_client = boto3.client('kendra')
    
    try:
        # First try to get document from S3 if it's a URL hash
        s3_content = None
        try:
            s3_content = get_document(doc_id)
        except Exception as e:
            logger.info(f"Document {doc_id} not found in S3, querying Kendra directly")
        
        # If we found the document in S3 and it's already indexed in Kendra,
        # we can use its content directly
        if s3_content and s3_content.get('cleaned_text'):
            # Check if this document is already indexed in Kendra
            try:
                # Make a test query to see if it exists in Kendra
                test_response = kendra_client.query(
                    IndexId=index_id,
                    QueryText=query_text,
                    AttributeFilter={
                        'EqualsTo': {
                            'Key': 'document_id',
                            'Value': {'StringValue': doc_id}
                        }
                    },
                    PageSize=1
                )
                
                # If the document is found in Kendra, proceed with normal query
                if test_response.get('ResultItems'):
                    pass  # Document exists in Kendra, continue with query below
                else:
                    # Document not found in Kendra but exists in S3
                    # Return the cleaned text from S3 directly
                    logger.info(f"Document {doc_id} found in S3 but not in Kendra, returning S3 content")
                    return s3_content.get('cleaned_text')
            except Exception as e:
                logger.warning(f"Error checking if document exists in Kendra: {str(e)}")
                # If we can't check Kendra, return S3 content as fallback
                return s3_content.get('cleaned_text')
        
        # Query Kendra for the main points of the document
        response = kendra_client.query(
            IndexId=index_id,
            QueryText=query_text,
            AttributeFilter={
                'EqualsTo': {
                    'Key': 'document_id',
                    'Value': {'StringValue': doc_id}
                }
            },
            PageSize=5  # Retrieve top 5 most relevant chunks
        )
        
        # Extract and combine relevant passages
        passages = []
        for result in response.get('ResultItems', []):
            if 'DocumentExcerpt' in result:
                text = result['DocumentExcerpt']['Text']
                if text and text not in passages:  # Avoid duplicates
                    passages.append(text)
        
        if passages:
            return "\n\n".join(passages)
        elif s3_content and s3_content.get('cleaned_text'):
            # Fallback to S3 content if Kendra query returned no results
            return s3_content.get('cleaned_text')
        else:
            return None  # No relevant passages found
            
    except Exception as e:
        logger.error(f"Error querying Kendra: {str(e)}")
        
        # Try to get content from S3 as a fallback
        try:
            s3_content = get_document(doc_id)
            if s3_content and s3_content.get('cleaned_text'):
                logger.info(f"Returning S3 content as fallback for document {doc_id}")
                return s3_content.get('cleaned_text')
        except Exception as s3_error:
            logger.error(f"Error retrieving S3 fallback: {str(s3_error)}")
            
        return None