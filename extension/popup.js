document.addEventListener('DOMContentLoaded', function() {
    const summarizeBtn = document.getElementById('summarize-btn');
    const loadingEl = document.getElementById('loading');
    const resultEl = document.getElementById('result-container');
    const summaryTextEl = document.getElementById('summary-text');
    const errorEl = document.getElementById('error-container');
    const errorMsgEl = document.getElementById('error-message');
    
    // API endpoint from AWS (will be replaced with actual URL from Terraform output)
    const API_ENDPOINT = 'https://REPLACE_WITH_API_GATEWAY_URL/prod/summarize';
    
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
        
        // Call API to get summary
        const apiResponse = await fetch(API_ENDPOINT, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({ content: response.content })
        });
        
        if (!apiResponse.ok) {
          throw new Error(`API error: ${apiResponse.status}`);
        }
        
        const data = await apiResponse.json();
        
        // Display the summary
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