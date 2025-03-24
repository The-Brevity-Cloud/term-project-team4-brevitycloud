document.addEventListener('DOMContentLoaded', function() {
    const summarizeBtn = document.getElementById('summarize-btn');
    const openSidePanelBtn = document.getElementById('open-sidepanel-btn'); // New button
    const loadingEl = document.getElementById('loading');
    const resultEl = document.getElementById('result-container');
    const summaryTextEl = document.getElementById('summary-text');
    const errorEl = document.getElementById('error-container');
    const errorMsgEl = document.getElementById('error-message');
    const chatInput = document.getElementById('chat-input'); // New chat input
    const sendChatBtn = document.getElementById('send-chat-btn'); // New chat button
    const chatMessages = document.getElementById('chat-messages'); // New chat messages container
    
    // Replace with your API endpoint from AWS
    const API_ENDPOINT = 'https://oojx0dyhe9.execute-api.us-east-1.amazonaws.com/prod/summarize';
    
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

    openSidePanelBtn.addEventListener('click', () => {
      chrome.runtime.sendMessage({ action: 'openSidePanel' });
    });

    sendChatBtn.addEventListener('click', () => {
      const message = chatInput.value.trim();
      if (message) {
        const messageEl = document.createElement('div');
        messageEl.textContent = message;
        chatMessages.appendChild(messageEl);
        chatInput.value = '';
        chatMessages.scrollTop = chatMessages.scrollHeight;
      }
    });
});