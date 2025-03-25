// Extract content from the current page
function extractPageContent() {
    // Get meaningful text content while ignoring navigation, ads, etc.
    const mainContent = document.querySelectorAll('article, [role="main"], .main-content, #main-content, .content, #content, main, .post-content, .article-content, p, h1, h2, h3, h4, h5, h6');
    let textContent = '';
    
    // If we found specific content containers, use them
    if (mainContent.length > 0) {
        mainContent.forEach(el => {
            // Skip if element is hidden
            const style = window.getComputedStyle(el);
            if (style.display === 'none' || style.visibility === 'hidden') {
                return;
            }

            // Skip navigation, header, footer, and sidebar elements
            if (el.closest('nav, header, footer, [role="navigation"], .sidebar, #sidebar')) {
                return;
            }

            // Get text content
            const text = el.textContent.trim();
            if (text.length > 20) { // Only include meaningful content
                textContent += text + '\n\n';
            }
        });
    }
    
    // If no content was found, fallback to body text
    if (!textContent.trim()) {
        const bodyText = document.body.innerText;
        // Split by newlines and filter out short lines (likely navigation/buttons)
        const lines = bodyText.split('\n').filter(line => line.trim().length > 20);
        textContent = lines.join('\n\n');
    }
    
    return textContent.trim();
}

// Listen for messages from the side panel
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.action === "getPageContent") {
        // Get the main content of the page
        const content = extractPageContent();
        
        // Send the content back to the side panel
        sendResponse({ content });
    }
    return true; // Required for async response
});