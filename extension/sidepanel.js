// API Configuration
const API_ENDPOINT = 'https://uxi2askv8l.execute-api.us-east-1.amazonaws.com/prod';
const AUTH_ENDPOINT = `${API_ENDPOINT}/auth`;
const SUMMARIZE_ENDPOINT = `${API_ENDPOINT}/summarize`;
const COGNITO_CLIENT_ID = '7n6rth0cr5qrivgh19rkujkied';

// UI Elements
const authContainer = document.getElementById('authContainer');
const mainContainer = document.getElementById('mainContainer');
const loginForm = document.getElementById('loginForm');
const registerForm = document.getElementById('registerForm');
const verifyForm = document.getElementById('verifyForm');
const loading = document.getElementById('loading');

// Form Elements
const loginEmail = document.getElementById('loginEmail');
const loginPassword = document.getElementById('loginPassword');
const registerEmail = document.getElementById('registerEmail');
const registerPassword = document.getElementById('registerPassword');
const verifyCode = document.getElementById('verifyCode');

// Buttons
const loginBtn = document.getElementById('loginBtn');
const registerBtn = document.getElementById('registerBtn');
const verifyBtn = document.getElementById('verifyBtn');
const resendCodeBtn = document.getElementById('resendCodeBtn');
const summarizeBtn = document.getElementById('summarizeBtn');
const sendQueryBtn = document.getElementById('sendQueryBtn');
const logoutBtn = document.getElementById('logoutBtn');
const historyBtn = document.getElementById('historyBtn');
const backToMainBtn = document.getElementById('backToMainBtn');

// Mic Button & Recording Elements
const micBtn = document.getElementById('micBtn');
let mediaRecorder;
let audioChunks = [];
let isRecording = false;
const micActiveColor = '#f44336'; // Color for mic when recording
const micInactiveColor = '#666'; // Default mic color

// Rekognition Elements
const rekognitionContainer = document.getElementById('rekognitionContainer');
const rekognitionImage = document.getElementById('rekognitionImage');
const rekognitionLoading = document.getElementById('rekognitionLoading');
const rekognitionText = document.getElementById('rekognitionText');
const rekognitionError = document.getElementById('rekognitionError');

// Error/Success Messages
const loginError = document.getElementById('loginError');
const registerError = document.getElementById('registerError');
const verifyError = document.getElementById('verifyError');

// Form Toggle Links
const showRegisterLink = document.getElementById('showRegister');
const showLoginLink = document.getElementById('showLogin');

// Summary Elements
const summaryContainer = document.getElementById('summaryContainer');
const summaryContent = document.getElementById('summaryContent');
const queryInput = document.getElementById('queryInput');

// History Elements
const historyContainer = document.getElementById('historyContainer');
const historyLoading = document.getElementById('historyLoading');
const historyContent = document.getElementById('historyContent');
const historyError = document.getElementById('historyError');

// State Management
let currentEmail = '';
let isAuthenticated = false;
let currentPageContent = '';
let currentPageTitle = '';
let currentPageUrl = '';

const kendraModeBtn = document.getElementById('kendraModeBtn');
const bedrockModeBtn = document.getElementById('bedrockModeBtn');
let useKendra = true; // Default to Kendra

const POLLING_INTERVAL_MS = 3000; // 3 seconds
const POLLING_TIMEOUT_MS = 180000; // 3 minutes

// Check Authentication Status on Load
chrome.storage.local.get(['isAuthenticated', 'userEmail'], (result) => {
    if (result.isAuthenticated) {
        isAuthenticated = true;
        currentEmail = result.userEmail;
        showMainContainer();
    }
});

// UI Helper Functions
function showLoading() {
    loading.style.display = 'block';
}

function hideLoading() {
    loading.style.display = 'none';
}

function showError(element, message) {
    element.textContent = message;
    element.style.display = 'block';
}

function hideError(element) {
    element.style.display = 'none';
}

function showMainContainer() {
    authContainer.style.display = 'none';
    mainContainer.style.display = 'flex';
}

function showAuthContainer() {
    authContainer.style.display = 'flex';
    mainContainer.style.display = 'none';
}

// Function to toggle main view and history view
function showHistoryView() {
    // Hide other main content sections if they are potentially visible
    summaryContainer.style.display = 'none';
    rekognitionContainer.style.display = 'none';
    document.querySelector('.model-selector').style.display = 'none'; // Hide model selector
    document.querySelector('.footer').style.display = 'none'; // Hide chat input footer
    summarizeBtn.style.display = 'none'; 
    
    historyContainer.style.display = 'block';
    hideError(historyError);
}

function showMainContentView() {
    historyContainer.style.display = 'none';
    
    // Restore visibility of main elements
    document.querySelector('.model-selector').style.display = 'block'; 
    document.querySelector('.footer').style.display = 'flex'; 
    summarizeBtn.style.display = 'block';
    // summaryContainer might need to be shown depending on state, handle as needed
    // rekognitionContainer might need to be shown depending on state, handle as needed
}

// Authentication Functions
async function login(email, password) {
    try {
        showLoading();
        hideError(loginError); 
        
        let response;
        try {
            response = await fetch(`${AUTH_ENDPOINT}/login`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json'
                },
                body: JSON.stringify({ email, password, clientId: COGNITO_CLIENT_ID })
            });
        } catch (networkError) {
            // Catch actual network/fetch errors
            console.error("Login fetch/network error:", networkError);
            showError(loginError, 'Network error: Could not reach login service.');
            hideLoading();
            return; // Stop execution
        }

        let data;
        try {
            // Check if response is ok before trying to parse JSON
            if (!response.ok) {
                // Try to parse error response, but don't fail if it's not JSON
                 data = await response.json().catch(() => ({ message: `Login failed with status: ${response.status}` }));
                 throw new Error(data.message || `HTTP error! status: ${response.status}`);
            }
            data = await response.json(); // Parse successful JSON response
            console.log("Login successful, received data:", JSON.stringify(data, null, 2));
        } catch (parseOrHttpError) {
             // Catch errors during response.json() or if response was not ok
            console.error("Login response/parse error:", parseOrHttpError);
            showError(loginError, parseOrHttpError.message || 'Login failed: Invalid response from server.');
            hideLoading();
            return; // Stop execution
        }
        
        // If we reach here, response was ok and data is parsed
        isAuthenticated = true;
        currentEmail = email;
        console.log("Storing tokens:", JSON.stringify(data, null, 2)); // Log before storing
        await chrome.storage.local.set({ 
            isAuthenticated: true, 
            userEmail: email, 
            idToken: data.idToken, // Store idToken
            accessToken: data.accessToken // *** Store accessToken ***
        }); 
        showMainContainer();
        showMainContentView(); 
        // fetchHistory(); 

    } catch (error) {
        // Catch any unexpected errors not caught above (should be rare)
        console.error("Unexpected Login error:", error);
        showError(loginError, 'An unexpected error occurred during login.');
    } finally {
        hideLoading();
    }
}

async function register(email, password) {
    try {
        showLoading();
        const response = await fetch(`${AUTH_ENDPOINT}/register`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            },
            body: JSON.stringify({
                email,
                password,
                clientId: COGNITO_CLIENT_ID
            })
        });

        const data = await response.json();
        
        if (response.ok) {
            currentEmail = email;
            loginForm.style.display = 'none';
            registerForm.style.display = 'none';
            verifyForm.style.display = 'block';
        } else {
            showError(registerError, data.message || 'Registration failed');
        }
    } catch (error) {
        showError(registerError, 'Network error occurred');
    } finally {
        hideLoading();
    }
}

async function verifyEmail(code) {
    try {
        showLoading();
        hideError(verifyError); // Hide verify error before request
        const response = await fetch(`${AUTH_ENDPOINT}/verify`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            },
            body: JSON.stringify({
                email: currentEmail,
                code,
                clientId: COGNITO_CLIENT_ID
            })
        });

        const data = await response.json();
        
        if (response.ok) {
            loginForm.style.display = 'block';
            verifyForm.style.display = 'none';
            hideError(loginError); // *** Explicitly hide login error ***
            // Remove previous success message if exists
            const existingSuccess = loginForm.querySelector('.success-message');
            if (existingSuccess) existingSuccess.remove();
            
            const successMessage = document.createElement('div');
            successMessage.className = 'success-message';
            successMessage.style.display = 'block';
            successMessage.textContent = 'Email verified! Please login.';
            loginForm.insertBefore(successMessage, loginForm.firstChild);
        } else {
            showError(verifyError, data.message || 'Verification failed');
        }
    } catch (error) {
        showError(verifyError, 'Network error occurred during verification');
    } finally {
        hideLoading();
    }
}

// Content Functions
async function getPageContent() {
    try {
        const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
        const response = await chrome.tabs.sendMessage(tab.id, { action: "getPageContent" });
        
        if (!response || !response.content) {
            throw new Error('Could not get page content');
        }

        currentPageContent = response.content;
        currentPageTitle = response.title || tab.title;
        currentPageUrl = response.url || tab.url;

        return response.content;
    } catch (error) {
        console.error('Error getting page content:', error);
        throw error;
    }
}

async function summarizePage() {
    try {
        const summaryLoading = document.getElementById('summaryLoading');
        summaryLoading.style.display = 'block';
        summaryContent.textContent = '';
        summaryContainer.style.display = 'block';
        
        // Get page content if not already available
        if (!currentPageContent) {
            await getPageContent();
        }

        // Ensure we have a URL
        if (!currentPageUrl) {
            const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
            currentPageUrl = tab.url;
            currentPageTitle = currentPageTitle || tab.title;
        }

        // *** Retrieve Access Token ***
        const { accessToken } = await chrome.storage.local.get('accessToken');
        if (!accessToken) {
             alert("Authentication error (Access Token missing). Please log out and log back in.");
             document.getElementById('summaryLoading').style.display = 'none';
             return; 
        }

        // Call summarize API
        const response = await fetch(SUMMARIZE_ENDPOINT, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': `Bearer ${accessToken}` // *** Use Access Token ***
            },
            body: JSON.stringify({
                action: 'summarize',
                text: currentPageContent,
                title: currentPageTitle,
                url: currentPageUrl,
                use_kendra: useKendra
            })
        });

        const data = await response.json();
        
        if (response.ok) {
            summaryContent.textContent = data.summary;
        } else {
            throw new Error(data.message || 'Failed to generate summary');
        }
    } catch (error) {
        alert('Error: ' + error.message);
    } finally {
        document.getElementById('summaryLoading').style.display = 'none';
    }
}

async function sendQuery(query) {
    try {
        const chatLoading = document.getElementById('chatLoading');
        chatLoading.style.display = 'block';
        summaryContainer.style.display = 'block';
        
        // Ensure we have page content
        if (!currentPageContent) {
            await getPageContent();
        }

        // *** Retrieve Access Token ***
        const { accessToken: chatAccessToken } = await chrome.storage.local.get('accessToken'); 
        if (!chatAccessToken) {
             alert("Authentication error (Access Token missing). Please log out and log back in.");
             document.getElementById('chatLoading').style.display = 'none'; 
             return; 
        }

        // Call chat API
        const response = await fetch(SUMMARIZE_ENDPOINT, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': `Bearer ${chatAccessToken}` // *** Use Access Token ***
            },
            body: JSON.stringify({
                action: 'chat',
                query: query,
                context: currentPageContent,
                url: currentPageUrl,
                title: currentPageTitle,
                use_kendra: useKendra 
            })
        });

        const data = await response.json();
        
        if (response.ok) {
            // Create and append response element
            const responseElement = document.createElement('div');
            responseElement.className = 'chat-response';
            responseElement.textContent = data.response;
            document.getElementById('chatResponses').appendChild(responseElement);
            
            // Scroll to the new response
            responseElement.scrollIntoView({ behavior: 'smooth' });
            
            // Clear input
            queryInput.value = '';
        } else {
            throw new Error(data.message || 'Failed to get response');
        }
    } catch (error) {
        alert('Error: ' + error.message);
    } finally {
        document.getElementById('chatLoading').style.display = 'none';
    }
}

// Rekognition API Call
async function detectTextImage(imageUrl) {
    try {
        rekognitionContainer.style.display = 'block';
        rekognitionImage.src = imageUrl;
        rekognitionLoading.style.display = 'block';
        rekognitionText.value = '';
        hideError(rekognitionError);

        // *** Retrieve ID Token for Authorization ***
        const { idToken } = await chrome.storage.local.get('idToken'); 
        if (!idToken) {
            throw new Error("Authentication error: Not logged in or ID token missing.");
        }

        const response = await fetch(`${API_ENDPOINT}/rekognition`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                // *** Add Authorization header ***
                'Authorization': `Bearer ${idToken}` 
            },
            body: JSON.stringify({ image_url: imageUrl })
        });

        // --- Modify handleRekognitionResponse call location ---
        // Process the response using the async handler function
        await handleRekognitionResponse(response); 

    } catch (error) {
        console.error('Rekognition Error:', error);
        showError(rekognitionError, `Error: ${error.message}`);
        rekognitionText.value = 'Error detecting text.'; // Show error in text area too
        rekognitionLoading.style.display = 'none'; // Ensure loading hides on error
    }
}

// Transcribe Audio Function
async function transcribeAudio(audioBlob) {
    const transcribeLoadingText = "Transcribing audio..."; 
    const statusElement = document.getElementById('chatLoading');
    const queryInput = document.getElementById('queryInput');

    try {
        statusElement.querySelector('.loading-text').textContent = transcribeLoadingText;
        statusElement.style.display = 'block';
        micBtn.disabled = true;
        queryInput.disabled = true;
        queryInput.placeholder = transcribeLoadingText;

        // Convert Blob to base64
        const reader = new FileReader();
        reader.readAsDataURL(audioBlob);
        const base64Audio = await new Promise((resolve, reject) => {
            reader.onloadend = () => {
                const base64String = reader.result.split(',', 2)[1];
                resolve(base64String);
            };
            reader.onerror = reject;
        });

        // *** Retrieve ID Token for Authorization ***
        const { idToken } = await chrome.storage.local.get('idToken');
        if (!idToken) {
            throw new Error("Authentication error: Not logged in or ID token missing.");
        }

        const response = await fetch(`${API_ENDPOINT}/transcribe`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                 // *** Add Authorization header ***
                'Authorization': `Bearer ${idToken}`
            },
            body: JSON.stringify({ audio_data: base64Audio })
        });

        // --- Modify to use the async handler --- 
        await handleTranscribeResponse(response); // Assume/create a handler similar to Rekognition's

    } catch (error) {
        console.error('Transcription Error:', error);
        alert(`Transcription Error: ${error.message}`);
        queryInput.placeholder = "Error transcribing. Try again.";
        // Ensure UI resets on error
        statusElement.style.display = 'none';
        micBtn.disabled = false;
        queryInput.disabled = false;
        queryInput.placeholder = "Ask a question about this page..."; 
    }
}

// Media Recorder Setup - Modified
async function setupMediaRecorder() {
    // 1. Send message to background to trigger iframe injection
    console.log("Sidepanel: Requesting background script to inject permission iframe...");
    try {
        const response = await chrome.runtime.sendMessage({ action: "requestMicPermission" });
        console.log("Sidepanel: Response from background script:", response);
        if (!response || !response.success) {
            throw new Error(response?.error || "Failed to communicate with background script for permissions.");
        }
    } catch (err) {
         console.error('Sidepanel: Error requesting permission injection:', err);
         alert(`Could not initiate microphone permission request: ${err.message}. Try reloading the page/extension.`);
         return false; // Indicate failure
    }
    
    // 2. Wait a short moment for the iframe to potentially trigger the prompt
    await new Promise(resolve => setTimeout(resolve, 500)); // 0.5 second delay

    // 3. Now try to get the user media stream
    try {
        console.log("Sidepanel: Attempting to get user media stream after iframe injection request...");
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        console.log("Sidepanel: Media stream acquired successfully.");

        // Check for supported MIME type
        const mimeType = MediaRecorder.isTypeSupported('audio/webm;codecs=opus') 
                         ? 'audio/webm;codecs=opus' 
                         : (MediaRecorder.isTypeSupported('audio/webm') ? 'audio/webm' : 'audio/ogg');
        if (!mimeType) {
             throw new Error("No suitable audio recording format found.");
        }
        console.log(`Using MIME type: ${mimeType}`);

        mediaRecorder = new MediaRecorder(stream, { mimeType: mimeType }); 

        mediaRecorder.ondataavailable = (event) => {
            if (event.data.size > 0) {
                audioChunks.push(event.data);
            }
        };

        mediaRecorder.onstop = () => {
            const audioBlob = new Blob(audioChunks, { type: mimeType });
            audioChunks = []; // Clear chunks for next recording
            if (audioBlob.size > 100) { 
                transcribeAudio(audioBlob);
            } else {
                console.log("Audio blob too small, not sending.");
                micBtn.querySelector('svg').style.fill = micInactiveColor;
                isRecording = false;
            }
            stream.getTracks().forEach(track => track.stop());
        };

        mediaRecorder.onerror = (event) => {
            console.error("MediaRecorder error:", event.error);
            alert("Audio recording error occurred.");
            isRecording = false;
            micBtn.querySelector('svg').style.fill = micInactiveColor;
            stream.getTracks().forEach(track => track.stop());
        };

        return true; // Indicate success

    } catch (err) {
        console.error('Sidepanel: Error accessing microphone stream:', err);
        // Check for specific errors
        if (err.name === 'NotAllowedError' || err.name === 'PermissionDeniedError') {
             alert('Microphone access was denied. Please grant permission in browser settings and reload the extension.');
        } else if (err.name === 'NotFoundError' || err.name === 'DevicesNotFoundError'){
             alert('No microphone found. Please ensure a microphone is connected and enabled.');
        } else {
             alert(`Could not access microphone: ${err.message}. Check console for details.`);
        }
        return false; // Indicate failure
    }
}

// startRecording - Modified
async function startRecording() {
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        alert("Audio recording is not supported by your browser.");
        return;
    }
    if (mediaRecorder && mediaRecorder.state === "recording") {
         console.warn("Already recording.");
         return;
    }

    // Ensure permissions are likely granted via iframe method before proceeding
    const setupSuccess = await setupMediaRecorder();

    if (setupSuccess && mediaRecorder) {
         if (mediaRecorder.state === "inactive") {
            audioChunks = [];
            mediaRecorder.start();
            isRecording = true;
            micBtn.querySelector('svg').style.fill = micActiveColor; 
            console.log("Recording started");
        } else {
             console.warn(`MediaRecorder state is not inactive: ${mediaRecorder.state}`);
        }
    } else {
        console.error("MediaRecorder setup failed or recorder not available.");
        // Error message already shown in setupMediaRecorder
        // Reset UI just in case
        isRecording = false;
        micBtn.querySelector('svg').style.fill = micInactiveColor;
    }
}

// stopRecording - (Keep existing implementation)
function stopRecording() {
    if (mediaRecorder && mediaRecorder.state === "recording") {
        mediaRecorder.stop();
        isRecording = false;
        micBtn.querySelector('svg').style.fill = micInactiveColor; // Change color back
        console.log("Recording stopped");
    } else {
        console.log("Recorder not active or already stopped.");
         isRecording = false;
         micBtn.querySelector('svg').style.fill = micInactiveColor;
    }
}

// Event Listeners
loginBtn.addEventListener('click', () => {
    hideError(loginError);
    login(loginEmail.value, loginPassword.value);
});

registerBtn.addEventListener('click', () => {
    hideError(registerError);
    register(registerEmail.value, registerPassword.value);
});

verifyBtn.addEventListener('click', () => {
    hideError(verifyError);
    verifyEmail(verifyCode.value);
});

resendCodeBtn.addEventListener('click', async () => {
    // Implement resend code functionality if needed
    alert('Resend code functionality not implemented yet');
});

showRegisterLink.addEventListener('click', () => {
    loginForm.style.display = 'none';
    registerForm.style.display = 'block';
    hideError(loginError); // Hide login error when switching
    // Clear potential success message from login form
    const existingSuccess = loginForm.querySelector('.success-message');
    if (existingSuccess) existingSuccess.remove();
});

showLoginLink.addEventListener('click', () => {
    registerForm.style.display = 'none';
    loginForm.style.display = 'block';
    hideError(registerError); // Hide register error when switching
});

summarizeBtn.addEventListener('click', summarizePage);

sendQueryBtn.addEventListener('click', () => {
    const query = queryInput.value.trim();
    if (query) {
        sendQuery(query);
    }
});

logoutBtn.addEventListener('click', () => {
    isAuthenticated = false;
    currentEmail = '';
    currentPageContent = '';
    currentPageTitle = '';
    currentPageUrl = '';
    chrome.storage.local.remove(['isAuthenticated', 'userEmail']);
    showAuthContainer();
});

kendraModeBtn.addEventListener('click', () => {
    useKendra = true;
    kendraModeBtn.classList.add('toggle-active');
    bedrockModeBtn.classList.remove('toggle-active');
  });
  
  bedrockModeBtn.addEventListener('click', () => {
    useKendra = false;
    bedrockModeBtn.classList.add('toggle-active');
    kendraModeBtn.classList.remove('toggle-active');
  });

micBtn.addEventListener('click', () => {
    if (!isRecording) {
        startRecording(); // Now calls the modified async version
    } else {
        stopRecording();
    }
});

historyBtn.addEventListener('click', () => {
    if (!isAuthenticated) {
        alert("Please log in to view history.");
        return;
    }
    showHistoryView();
    fetchHistory();
});

backToMainBtn.addEventListener('click', () => {
    showMainContentView();
});

// Listen for messages (Combined Listener)
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    console.log("Message received in sidepanel:", request);
    
    if (request.action === "detectTextImage") {
        // --- Handle Rekognition Request --- 
        if (request.imageUrl) {
            if (isAuthenticated) {
                 detectTextImage(request.imageUrl);
                 showMainContentView(); // Ensure main view is visible
                 rekognitionContainer.scrollIntoView({ behavior: 'smooth' }); // Scroll to results
            } else {
                 console.warn("User not authenticated. Rekognition feature requires login.");
                 showError(rekognitionError, "Please login to use the text detection feature.");
                 rekognitionContainer.style.display = 'block';
                 showMainContentView(); // Show main view to display the error in context
            }
        } else {
            console.error("No image URL provided in message.");
            showError(rekognitionError, "Error: Missing image URL from request.");
            rekognitionContainer.style.display = 'block';
            showMainContentView();
        }
        // Optional: sendResponse({ received: true });
        
    } else if (request.action === "tabNavigated") {
        // --- Handle Tab Navigation --- 
        console.log(`Sidepanel: Detected navigation to ${request.url}`);
        // Update state only if the URL actually changed
        if (currentPageUrl !== request.url) {
            currentPageUrl = request.url;
            currentPageContent = ''; // Clear stale content
            currentPageTitle = '';   // Clear stale title
            
            // Reset UI elements to initial state for the new page
            summaryContainer.style.display = 'none';
            summaryContent.innerHTML = '';
            document.getElementById('chatResponses').innerHTML = '';
            rekognitionContainer.style.display = 'none';
            rekognitionText.value = '';
            rekognitionImage.src = '';
            queryInput.value = ''; // Clear chat input
            
            // Ensure the main content view is visible (not history)
            showMainContentView();
            
            // Optionally, display a message indicating the context change
            // e.g., update a status bar element not implemented here yet.
             console.log("Sidepanel context reset for new page.");
        }
        // Optional: sendResponse({ received: true });
    }
    // ... handle other potential message actions ...

    // Return true ONLY if using sendResponse asynchronously elsewhere in the listener
    // Since we handle synchronously here, returning true might keep ports open unnecessarily.
    // Consider returning false or nothing if no async sendResponse is used for these actions.
    return true; 
});

// History Functions
function formatTimestamp(unixTimestamp) {
    if (!unixTimestamp) return 'Unknown date';
    const date = new Date(unixTimestamp * 1000);
    return date.toLocaleString(); // Adjust format as needed
}

function displayHistory(historyData) {
    historyContent.innerHTML = ''; // Clear previous content

    if (!historyData || (!historyData.summaries?.length && !historyData.chat_history?.length)) {
        historyContent.innerHTML = '<p>No history found.</p>';
        return;
    }

    // Display Summaries
    if (historyData.summaries?.length) {
        const summarySection = document.createElement('div');
        summarySection.innerHTML = '<h3>Recent Summaries</h3>';
        historyData.summaries.forEach(item => {
            const div = document.createElement('div');
            div.className = 'history-item summary-item'; // Add classes for styling
            div.innerHTML = `
                <p><strong>Title:</strong> ${item.title || 'N/A'}</p>
                <p><strong>URL:</strong> <a href="${item.url}" target="_blank">${item.url || 'N/A'}</a></p>
                <p><strong>Summary:</strong> ${item.summary || 'N/A'}</p>
                <small><em>${formatTimestamp(item.timestamp)}</em></small>
            `;
            summarySection.appendChild(div);
        });
        historyContent.appendChild(summarySection);
    }

    // Display Chat History
    if (historyData.chat_history?.length) {
        const chatSection = document.createElement('div');
        chatSection.innerHTML = '<h3>Recent Chats</h3>';
        historyData.chat_history.forEach(item => {
            const div = document.createElement('div');
            div.className = 'history-item chat-item'; // Add classes for styling
            div.innerHTML = `
                <p><strong>Page:</strong> ${item.title || item.url || 'N/A'}</p>
                <p><strong>Query:</strong> ${item.query || 'N/A'}</p>
                <p><strong>Response:</strong> ${item.response || 'N/A'}</p> <!-- Adjust if response is object -->
                <small><em>${formatTimestamp(item.timestamp)}</em></small>
            `;
             chatSection.appendChild(div);
        });
        historyContent.appendChild(chatSection);
    }
     // Add basic styling for history items (can be moved to <style> block)
    const style = document.createElement('style');
    style.textContent = `
        .history-item { border: 1px solid #eee; padding: 10px; border-radius: 5px; background-color: #fff; }
        .history-item p { margin-bottom: 5px; font-size: 13px; }
        .history-item small { color: #777; font-size: 11px; }
        .history-item a { color: #007bff; text-decoration: none; }
        .history-item a:hover { text-decoration: underline; }
        .history-item h3 { font-size: 16px; margin-bottom: 10px; border-bottom: 1px solid #ddd; padding-bottom: 5px; }
    `;
    historyContent.appendChild(style);
}

async function fetchHistory() {
    console.log("Fetching user history...");
    historyLoading.style.display = 'block';
    historyContent.innerHTML = ''; // Clear previous
    hideError(historyError);

    try {
        // *** Retrieve Access Token ***
        const { accessToken: historyAccessToken } = await chrome.storage.local.get('accessToken');
        if (!historyAccessToken) {
            throw new Error("Not logged in or Access Token missing.");
        }

        const response = await fetch(`${API_ENDPOINT}/history`, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${historyAccessToken}`, // *** Use Access Token ***
                'Accept': 'application/json'
            }
        });

        if (!response.ok) {
             // Handle specific errors like 401 Unauthorized
             if (response.status === 401) {
                  throw new Error("Authentication failed. Please log in again.");
             }
            const errorData = await response.json().catch(() => ({})); // Try to get error body
            throw new Error(errorData.error || `Failed to fetch history: ${response.statusText}`);
        }

        const historyData = await response.json();
        console.log("History data received:", historyData);
        displayHistory(historyData);

    } catch (error) {
        console.error("Fetch History Error:", error);
        showError(historyError, `Error loading history: ${error.message}`);
         // If auth error, maybe force logout?
         // if (error.message.includes("Authentication failed")) { logoutUser(); } 
    } finally {
        historyLoading.style.display = 'none';
    }
}

// Helper function to poll for results
function pollForResult(jobId, type, resultElementId, loadingElementId, statusElementId) {
    const startTime = Date.now();
    let intervalId = null;
    const statusDiv = document.getElementById(statusElementId); // Optional element to show status updates

    const checkStatus = async () => {
        const elapsedTime = Date.now() - startTime;
        if (elapsedTime > POLLING_TIMEOUT_MS) {
            console.error(`Polling timed out for job ${jobId}`);
            displayError(`Polling timed out for ${type} job ${jobId}.`, resultElementId); // Or update statusDiv
            if (loadingElementId) hideLoading(loadingElementId);
            clearInterval(intervalId);
            return;
        }

        console.log(`Polling for job ${jobId} (type: ${type}), elapsed: ${Math.round(elapsedTime / 1000)}s`);
        if (statusDiv) statusDiv.textContent = `Processing... (checking status)`;

        try {
            const token = await getToken();
            if (!token) {
                displayError("Authentication error during polling.", resultElementId);
                clearInterval(intervalId);
                return;
            }
            
            // Ensure jobId is URL encoded if it contains special characters (unlikely for UUID/jobName)
            const encodedJobId = encodeURIComponent(jobId); 
            const response = await fetch(`${API_ENDPOINT}/results/${encodedJobId}?type=${type}`, {
                method: 'GET',
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                }
            });

            if (!response.ok && response.status !== 202) { // 202 is expected for PENDING
                throw new Error(`Polling check failed with status ${response.status}`);
            }

            const data = await response.json();
            console.log(`Polling response for ${jobId}:`, data);

            if (data.status === 'COMPLETED') {
                console.log(`Job ${jobId} completed.`);
                clearInterval(intervalId);
                if (loadingElementId) hideLoading(loadingElementId);
                if (statusDiv) statusDiv.textContent = 'Completed.';

                const resultElement = document.getElementById(resultElementId);
                if (resultElement) {
                     // Assuming result is plain text, adjust if it's JSON, etc.
                    if (resultElement.tagName === 'TEXTAREA' || resultElement.tagName === 'INPUT') {
                        resultElement.value = data.result || 'No result content found.';
                    }
                    // *** START: Modified logic for chat/other elements ***
                    else {
                         // Check if it's a transcribe result meant for the chat
                         if (type === 'transcribe' && resultElementId === 'chatResponses') { 
                            // Append transcript as a new message
                            displayChatMessage('user', data.result || 'Empty Transcript'); 
                         } else {
                            // Original behavior for other types (like rekognition) or different elements
                            resultElement.textContent = data.result || 'No result content found.';
                         }
                    }
                    // *** END: Modified logic for chat/other elements ***
                } else {
                    console.error(`Result element with ID ${resultElementId} not found.`);
                }
                
            } else if (data.status === 'FAILED') {
                console.error(`Job ${jobId} failed: ${data.error}`);
                clearInterval(intervalId);
                 if (loadingElementId) hideLoading(loadingElementId);
                displayError(`Job ${jobId} failed: ${data.error || 'Unknown reason'}`, resultElementId); // Or update statusDiv
            } else if (data.status === 'PENDING') {
                // Continue polling
                 if (statusDiv) statusDiv.textContent = `Processing... (status: PENDING)`;
            } else {
                 // Unexpected status
                console.error(`Unexpected status for job ${jobId}: ${data.status}`);
                 if (statusDiv) statusDiv.textContent = `Processing... (status: ${data.status || 'Unknown'})`;
                // Continue polling? Or treat as error? Let's continue for now.
            }
        } catch (error) {
            console.error(`Error during polling for job ${jobId}: ${error}`);
            // Optionally stop polling on error, or allow retries? Stopping for now.
            // displayError(`Polling error: ${error.message}`, resultElementId);
            // clearInterval(intervalId);
            // if (loadingElementId) hideLoading(loadingElementId);
             if (statusDiv) statusDiv.textContent = `Processing... (polling error)`;
        }
    };

    // Initial check
    checkStatus(); 
    // Set interval for subsequent checks
    intervalId = setInterval(checkStatus, POLLING_INTERVAL_MS);
}

// --- Helper function to get token (if not already existing) ---
async function getToken() {
    const { idToken } = await chrome.storage.local.get('idToken');
    if (!idToken) {
        console.error("Attempted to get token but none found.");
        // Optionally trigger logout or show login prompt
        // showAuthContainer(); 
    }
    return idToken;
}

// --- Modify handleRekognitionResponse --- 
// Make sure this function exists and handles loading indicators
async function handleRekognitionResponse(response) { 
    // const rekResultTextArea = document.getElementById('rekognitionText'); // Use correct ID
    const rekLoadingIndicator = document.getElementById('rekognitionLoading');
    const rekStatusDiv = document.getElementById('rekognition-status'); // Optional status element

    if (!rekognitionText) { // Check the correct element variable
        console.error("Rekognition result text area not found.");
        return;
    }
    // Loading indicator should have been shown by detectTextImage
    // rekognitionText.value = ''; // Clear previous results? Maybe keep old while processing?
    if (rekStatusDiv) rekStatusDiv.textContent = 'Processing response...';

    try {
        if (response.status === 202) { // Check for Accepted status
            const data = await response.json();
            const jobId = data.jobId; 
            if (jobId) {
                console.log(`Rekognition job submitted. Job ID: ${jobId}`);
                rekognitionText.value = 'Processing image...'; // Update feedback
                if (rekStatusDiv) rekStatusDiv.textContent = 'Processing... (polling)';
                pollForResult(jobId, 'rekognition', 'rekognitionText', 'rekognitionLoading', 'rekognition-status'); // Use correct resultElementId
            } else {
                throw new Error("API accepted request but did not return a Job ID.");
            }
        } else if (response.ok) { 
            // Handle unexpected success (sync response)
            const data = await response.json();
            if (rekLoadingIndicator) hideLoading(rekLoadingIndicator.id); // Correct function call
            rekognitionText.value = data.detected_text || 'No text detected (sync).';
            if (rekStatusDiv) rekStatusDiv.textContent = 'Completed (sync).';
        } else {
            // Handle API error (4xx, 5xx) from the initial request
            const errorData = await response.json().catch(() => ({ error: `API Error ${response.status}` }));
            throw new Error(errorData.error || `API Error: ${response.status}`);
        }
    } catch (error) {
        console.error('Error handling rekognition response:', error);
        if (rekLoadingIndicator) hideLoading(rekLoadingIndicator.id); // Correct function call
        // Display error in the text area
        showError(rekognitionError, `Error: ${error.message}`); 
        rekognitionText.value = `Error: ${error.message}`; // Also put in text area
        if (rekStatusDiv) rekStatusDiv.textContent = 'Error.';
    }
}

// --- Create handleTranscribeResponse (Mirroring Rekognition's) ---
async function handleTranscribeResponse(response) {
    const statusElement = document.getElementById('chatLoading'); 
    const queryInput = document.getElementById('queryInput');
    const transcribeStatusElementId = 'transcribe-status'; // Optional status element ID
    const transcribeResultTargetElementId = 'chatResponses'; // Target the div where responses appear

    if (document.getElementById(transcribeStatusElementId)) {
         document.getElementById(transcribeStatusElementId).textContent = 'Processing response...';
    }

    try {
        if (response.status === 202) { // Check for Accepted status
            const data = await response.json();
            const jobName = data.jobName; 
            if (jobName) {
                console.log(`Transcribe job submitted. Job Name: ${jobName}`);
                displayChatMessage('system', 'Audio submitted. Processing transcript...');
                // Start polling, ADAPT COMPLETION LOGIC for chat
                pollForResult(jobName, 'transcribe', transcribeResultTargetElementId, 'chatLoading', transcribeStatusElementId);
            } else {
                throw new Error("API accepted request but did not return a Job Name.");
            }
        } else if (response.ok) {
            // Handle unexpected sync success
            const data = await response.json();
            if (statusElement) statusElement.style.display = 'none';
            micBtn.disabled = false;
            queryInput.disabled = false;
            queryInput.value = data.transcript || ''; // Populate input field on sync success
            queryInput.placeholder = "Ask a question about this page..."; 
            displayChatMessage('system', `Transcript (sync): ${data.transcript || 'Empty'}`);
        } else {
            // Handle API error
            const errorData = await response.json().catch(() => ({ error: `API Error ${response.status}` }));
            throw new Error(errorData.error || `API Error: ${response.status}`);
        }
    } catch (error) {
        console.error('Error handling transcribe response:', error);
        if (statusElement) statusElement.style.display = 'none';
        micBtn.disabled = false;
        queryInput.disabled = false;
        queryInput.placeholder = "Ask a question about this page..."; 
        displayChatMessage('system', `Error: ${error.message}`); // Display error in chat
    }
}

// --- Helper function displayChatMessage (ensure it exists) ---
function displayChatMessage(sender, message) {
    const responsesDiv = document.getElementById('chatResponses');
    if (!responsesDiv) return;

    const messageElement = document.createElement('div');
    messageElement.classList.add('chat-message', sender === 'user' ? 'user-message' : 'system-message'); 
    
    // Basic formatting (can be enhanced)
    const contentElement = document.createElement('p');
    contentElement.textContent = message;
    messageElement.appendChild(contentElement);
    
    responsesDiv.appendChild(messageElement);
    messageElement.scrollIntoView({ behavior: 'smooth', block: 'end' });
}

// --- Helper function displayError (ensure it exists and handles element ID) ---
function displayError(message, targetElementId) {
    const element = document.getElementById(targetElementId);
    if (element) {
         // Check if it's an error display element or a general output area
         if (element.classList.contains('error-message')) {
             element.textContent = message;
             element.style.display = 'block';
         } else if (element.tagName === 'TEXTAREA' || element.tagName === 'INPUT') {
             element.value = `Error: ${message}`; // Show error in input/textarea
         } else {
             // For general divs like chat output, perhaps append an error message
             displayChatMessage('system', `Error: ${message}`); 
         }
    } else {
         // Fallback alert if target element not found
         console.error(`Target element ${targetElementId} not found for error: ${message}`);
         // alert(`Error: ${message}`); 
    }
}








