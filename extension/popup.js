
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
    const API_ENDPOINT = 'https://z5n7ea4ds5.execute-api.us-east-1.amazonaws.com/prod';
    
    summarizeBtn.addEventListener('click', async () => {
      loadingEl.classList.remove('hidden');
      resultEl.classList.add('hidden');
      errorEl.classList.add('hidden');
      
      try {
        // Get the active tab
        const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
        
        const data = await response.json();
        console.log("Login response data:", JSON.stringify(data));
        
        if (!response.ok) {
            throw new Error(data.message || 'Login failed');
        }

        authToken = data.token;
        localStorage.setItem('authToken', authToken);
        
        // Switch to summary view
        document.getElementById('loginForm').style.display = 'none';
        document.getElementById('summaryContent').style.display = 'block';
        
        // Show success message
        showMessage('Login successful!', 'success');
    } catch (error) {
        console.error("Login error:", error);
        showMessage(error.message, 'error');
    }
}

async function register(email, password) {
    try {
        console.log("Attempting registration...");
        // Use the endpoint that was identified as valid by the test
        const url = `${AUTH_ENDPOINT}/auth/register`;
        console.log("Registration endpoint:", url);
        
        const requestBody = { 
            email, 
            password,
            clientId: COGNITO_CLIENT_ID
        };
        console.log("Registration request body:", JSON.stringify(requestBody));
        
        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            },
            body: JSON.stringify(requestBody)
        });

        console.log("Registration response status:", response.status);
        console.log("Registration response headers:", JSON.stringify([...response.headers]));
        
        const data = await response.json();
        console.log("Registration response data:", JSON.stringify(data));
        
        if (!response.ok) {
            throw new Error(data.message || 'Registration failed');
        }

        // Show verification message
        showMessage('Registration successful! Please check your email for verification code.', 'success');
        

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