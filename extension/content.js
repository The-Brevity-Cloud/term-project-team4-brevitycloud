function extractPageContent() {
    try {
        // Use Readability for better content extraction
        const documentClone = document.cloneNode(true);
        const reader = new Readability(documentClone);
        const article = reader.parse();
        
        if (article && article.textContent) {
            return {
                content: article.textContent,
                title: article.title || document.title,
                url: window.location.href
            };
        }
        
        // Fallback to original method if Readability fails
        const mainContent = document.querySelectorAll('article, [role="main"], .main-content, #main-content, .content, #content, main, .post-content, .article-content, p, h1, h2, h3, h4, h5, h6');
        let textContent = '';
        
        if (mainContent.length > 0) {
            mainContent.forEach(el => {
                const style = window.getComputedStyle(el);
                if (style.display === 'none' || style.visibility === 'hidden') {
                    return;
                }

                if (el.closest('nav, header, footer, [role="navigation"], .sidebar, #sidebar')) {
                    return;
                }

                const text = el.textContent.trim();
                if (text.length > 20) {
                    textContent += text + '\n\n';
                }
            });
        }
        
        if (!textContent.trim()) {
            const bodyText = document.body.innerText;
            const lines = bodyText.split('\n').filter(line => line.trim().length > 20);
            textContent = lines.join('\n\n');
        }
        
        return {
            content: textContent.trim(),
            title: document.title,
            url: window.location.href
        };
    } catch (error) {
        console.error('Error extracting content:', error);
        return {
            content: document.body.innerText,
            title: document.title,
            url: window.location.href
        };
    }
}

// Listen for messages from the side panel
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.action === "getPageContent") {
        // Get the main content of the page
        const extractedData = extractPageContent();
        
        // Send the content back to the side panel
        sendResponse({
            content: extractedData.content,
            title: extractedData.title,
            url: extractedData.url
        });
    }
    return true; // Required for async response
});