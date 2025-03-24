// Extract content from the current page
function extractPageContent() {
    // Get meaningful text content while ignoring navigation, ads, etc.
    const mainContent = document.querySelectorAll('p, h1, h2, h3, h4, h5, h6, article');
    let textContent = '';
    
    mainContent.forEach(el => {
      if (el.textContent.trim().length > 15) {
        textContent += el.textContent.trim() + '\n\n';
      }
    });
    
    return textContent;
  }
  
  // Listen for messages from the side panel
  chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.action === "getPageContent") {
        // Get the main content of the page
        const content = document.body.innerText;
        
        // Send the content back to the side panel
        sendResponse({ content });
    }
    return true; // Required for async response
  });