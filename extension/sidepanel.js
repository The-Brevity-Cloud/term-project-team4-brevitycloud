// API Configuration
const API_ENDPOINT = 'https://8lgd1r9720.execute-api.us-east-1.amazonaws.com/prod';
const AUTH_ENDPOINT = `${API_ENDPOINT}/auth`;
const SUMMARIZE_ENDPOINT = 'https://oojx0dyhe9.execute-api.us-east-1.amazonaws.com/prod/summarize';
const COGNITO_CLIENT_ID = '7ej1h1n3jvhk2d6nfktlcj0r7f';

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
            showError(loginError, 'Email verified! Please login.');
        } else {
            showError(verifyError, data.message || 'Verification failed');
        }
    } catch (error) {
        showError(verifyError, 'Network error occurred');
    } finally {
        hideLoading();
    }
}

// Summarize Functions
async function summarizePage() {
    try {
        showLoading();
        
        // Get current tab's content
        const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
        const response = await chrome.tabs.sendMessage(tab.id, { action: "getPageContent" });
        
        if (!response || !response.content) {
            throw new Error('Could not get page content');
        }

        // Call summarize API
        const apiResponse = await fetch(SUMMARIZE_ENDPOINT, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                text: response.content
            })
        });

        const data = await apiResponse.json();
        
        if (apiResponse.ok) {
            summaryContainer.style.display = 'block';
            summaryContent.textContent = data.summary;
        } else {
            throw new Error(data.message || 'Failed to generate summary');
        }
    } catch (error) {
        alert('Error: ' + error.message);
    } finally {
        hideLoading();
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
});

showLoginLink.addEventListener('click', () => {
    registerForm.style.display = 'none';
    loginForm.style.display = 'block';
});

summarizeBtn.addEventListener('click', summarizePage);

sendQueryBtn.addEventListener('click', () => {
    // Implement query functionality when backend is ready
    alert('Query functionality will be implemented soon!');
});

logoutBtn.addEventListener('click', () => {
    isAuthenticated = false;
    currentEmail = '';
    chrome.storage.local.remove(['isAuthenticated', 'userEmail']);
    showAuthContainer();
}); 