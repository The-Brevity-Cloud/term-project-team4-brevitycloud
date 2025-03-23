import hashlib
import re
import boto3
from logger import logger

def generate_document_id(content, title=""):
    """Generate a unique document ID based on content hash"""
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
                        {'Key': 'chunk_number', 'Value': {'LongValue': i}}
                    ]
                }]
            )
            responses.append(response)
        except Exception as e:
            logger.error(f"Error indexing chunk {i}: {str(e)}")
    
    return responses

def query_kendra(doc_id, index_id):
    """Query Kendra for the most relevant content from the document"""
    kendra_client = boto3.client('kendra')
    
    try:
        # Query for the main points of the document
        response = kendra_client.query(
            IndexId=index_id,
            QueryText="What are the main points and key information in this document?",
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
        else:
            return None  # No relevant passages found
            
    except Exception as e:
        logger.error(f"Error querying Kendra: {str(e)}")
        return None