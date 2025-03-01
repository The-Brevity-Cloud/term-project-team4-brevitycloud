document.addEventListener('DOMContentLoaded', function() {
    const summarizeBtn = document.getElementById('summarize-btn');
    const loadingEl = document.getElementById('loading');
    const resultEl = document.getElementById('result-container');
    const summaryTextEl = document.getElementById('summary-text');
    const errorEl = document.getElementById('error-container');
    const errorMsgEl = document.getElementById('error-message');
    
    // Replace with your API endpoint from AWS
    const API_ENDPOINT = 'https://854eynz9xg.execute-api.us-east-1.amazonaws.com/prod/summarize';
    
    summarizeBtn.addEventListener('click', async () => {
      loadingEl.classList.remove('hidden');
      resultEl.classList.add('hidden');
      errorEl.classList.add('hidden');
      
      try {
        // Get the active tab
        const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
        
        // Extract content from the page
        const response = await chrome.tabs.sendMessage(tab.id, { action: "extractContent" });
        
        if (!response || !response.content) {
          throw new Error("Couldn't extract content from the page.");
        }
        
        // Call the backend API
        const apiResponse = await fetch(API_ENDPOINT, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            content: response.content
          })
        });
        
        if (!apiResponse.ok) {
          throw new Error('Failed to get summary from the server.');
        }
        
        const data = await apiResponse.json();
        summaryTextEl.textContent = data.summary;
        resultEl.classList.remove('hidden');
      } catch (error) {
        errorMsgEl.textContent = `Error: ${error.message}`;
        errorEl.classList.remove('hidden');
        console.error(error);
      } finally {
        loadingEl.classList.add('hidden');
      }
    });
});