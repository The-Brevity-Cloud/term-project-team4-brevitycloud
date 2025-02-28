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
  
  // Listen for messages from the popup
  chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.action === "extractContent") {
      const content = extractPageContent();
      sendResponse({content: content});
    }
    return true; // Keeps the message channel open for async response
  });