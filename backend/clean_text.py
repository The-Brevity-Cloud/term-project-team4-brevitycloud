import re
from bs4 import BeautifulSoup

def clean_text(text):
    # Remove excessive whitespace, normalize line breaks
    text = re.sub(r'\n\s*\n', '\n\n', text)
    text = re.sub(r'\s+', ' ', text)
    return text.strip()

def extract_main_content(html_content):
    soup = BeautifulSoup(html_content, 'html.parser')
    
    # Remove unwanted elements
    for element in soup(['script', 'style', 'nav', 'footer', 'header', 'aside']):
        element.decompose()
    
    # Extract text from main content areas (prioritize article, main, content divs)
    main_content = soup.find('article') or soup.find('main') or soup.find(id=re.compile(r'content|main', re.I))
    
    if main_content:
        # Extract from main content area if found
        content = main_content.get_text(separator='\n', strip=True)
    else:
        # Fallback to extracting paragraphs and headings if no main content area identified
        elements = soup.find_all(['h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'p'])
        content = '\n'.join([elem.get_text(strip=True) for elem in elements if elem.get_text(strip=True)])
    
    return content