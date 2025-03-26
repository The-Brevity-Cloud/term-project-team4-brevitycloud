// API Configuration
const API_ENDPOINT = 'https://utfoy8el8a.execute-api.us-east-1.amazonaws.com/prod';
const AUTH_ENDPOINT = `${API_ENDPOINT}/auth`;
const SUMMARIZE_ENDPOINT = `${API_ENDPOINT}/summarize`;
const COGNITO_CLIENT_ID = '1kg77rmnscaa6ncmt61ae9u64v';

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

// State Management
let currentEmail = '';
let isAuthenticated = false;
let currentPageContent = '';
let currentPageTitle = '';
let currentPageUrl = '';

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

function clearFormFields(form) {
    const inputs = form.getElementsByTagName('input');
    for (let input of inputs) {
        input.value = '';
    }
}

// Authentication Functions
async function login(email, password) {
    try {
        showLoading();
        const response = await fetch(`${AUTH_ENDPOINT}/login`, {
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
            isAuthenticated = true;
            currentEmail = email;
            chrome.storage.local.set({ isAuthenticated: true, userEmail: email });
            showMainContainer();
        } else {
            showError(loginError, data.message || 'Login failed');
        }
    } catch (error) {
        showError(loginError, 'Network error occurred');
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
            hideError(loginError);
            clearFormFields(loginForm);
            const successMessage = document.createElement('div');
            successMessage.className = 'success-message';
            successMessage.style.display = 'block';
            successMessage.textContent = 'Email verified! Please login.';
            loginForm.insertBefore(successMessage, loginForm.firstChild);
        } else {
            showError(verifyError, data.message || 'Verification failed');
        }
    } catch (error) {
        showError(verifyError, 'Network error occurred');
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
        currentPageTitle = tab.title;
        currentPageUrl = tab.url;

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

        // Call summarize API
        const response = await fetch(SUMMARIZE_ENDPOINT, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            },
            body: JSON.stringify({
                action: 'summarize',
                text: currentPageContent,
                title: currentPageTitle,
                url: currentPageUrl
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

        // Call chat API
        const response = await fetch(SUMMARIZE_ENDPOINT, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            },
            body: JSON.stringify({
                action: 'chat',
                query: query,
                context: currentPageContent,
                url: currentPageUrl,
                title: currentPageTitle
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
    hideError(loginError);
    hideError(registerError);
    clearFormFields(loginForm);
    clearFormFields(registerForm);
});

showLoginLink.addEventListener('click', () => {
    registerForm.style.display = 'none';
    loginForm.style.display = 'block';
    hideError(loginError);
    hideError(registerError);
    clearFormFields(loginForm);
    clearFormFields(registerForm);
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