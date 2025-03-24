// API Endpoints - use actual endpoints from terraform output
const API_ENDPOINT = 'https://mzu4l0fkgh.execute-api.us-east-1.amazonaws.com/prod';
const SUMMARIZE_ENDPOINT = `${API_ENDPOINT}/summarize`;
const AUTH_ENDPOINT = `${API_ENDPOINT}`;

// Cognito Client ID - replace with your actual client ID from terraform output
const COGNITO_CLIENT_ID = '62061m29hj5pf7hf0rmmmth15o';

// Get stored auth token
let authToken = localStorage.getItem('authToken');

// Debug function
function debugExtension() {
    console.log('=== EXTENSION DEBUG INFO ===');
    console.log('API_ENDPOINT:', API_ENDPOINT);
    console.log('AUTH_ENDPOINT:', AUTH_ENDPOINT);
    console.log('COGNITO_CLIENT_ID:', COGNITO_CLIENT_ID);
    console.log('Auth Token:', authToken ? 'Present' : 'Not present');
    
    // Check DOM elements
    const elements = [
        'loginForm', 'summaryContent', 'verificationForm', 
        'email', 'password', 'verificationCode', 'verificationEmail',
        'loginBtn', 'registerBtn', 'verifyBtn', 'logoutBtn', 'summarize-btn',
        'loading', 'error-container', 'success-container', 'result-container', 'summary-text'
    ];
    
    elements.forEach(id => {
        const element = document.getElementById(id);
        console.log(`Element ${id}:`, element ? 'Found' : 'NOT FOUND');
        if (element) {
            console.log(`  Display:`, window.getComputedStyle(element).display);
        }
    });
    
    console.log('=== END DEBUG INFO ===');
}

// Test API endpoints with different path combinations
async function testAPI() {
    const baseOptions = [
        'https://mzu4l0fkgh.execute-api.us-east-1.amazonaws.com',
        'https://mzu4l0fkgh.execute-api.us-east-1.amazonaws.com/prod'
    ];
    
    const pathOptions = [
        '/register',
        '/login',
        '/verify',
        '/auth/register',
        '/auth/login',
        '/auth/verify'
    ];
    
    console.log('=== TESTING API ENDPOINTS ===');
    
    for (const base of baseOptions) {
        for (const path of pathOptions) {
            try {
                const url = `${base}${path}`;
                console.log(`Testing endpoint: ${url}`);
                
                // Try POST request directly
                try {
                    const response = await fetch(url, {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                            'Accept': 'application/json'
                        },
                        body: JSON.stringify({
                            email: 'test@example.com',
                            password: 'TestPassword1!',
                            clientId: COGNITO_CLIENT_ID
                        })
                    });
                    
                    console.log(`POST Status for ${url}: ${response.status}`);
                    try {
                        const data = await response.json();
                        console.log(`POST Response for ${url}:`, JSON.stringify(data));
                        
                        // If this endpoint works, make note of it
                        if (response.status !== 400 || (data && data.message !== 'Invalid route')) {
                            console.log(`✅ POTENTIALLY VALID ENDPOINT: ${url}`);
                        }
                    } catch (e) {
                        console.log(`POST Response for ${url} is not JSON`);
                    }
                } catch (postError) {
                    console.error(`POST Error for ${url}:`, postError);
                }
                
            } catch (error) {
                console.error(`Error testing ${url}:`, error);
            }
        }
    }
    
    console.log('=== END API TESTING ===');
}

// Authentication functions
async function login(email, password) {
    try {
        console.log("Attempting login...");
        // Use the endpoint that was identified as valid by the test
        const url = `${AUTH_ENDPOINT}/auth/login`;
        console.log("Login endpoint:", url);
        
        const requestBody = { 
            email, 
            password,
            clientId: COGNITO_CLIENT_ID
        };
        console.log("Login request body:", JSON.stringify(requestBody));
        
        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            },
            body: JSON.stringify(requestBody)
        });

        console.log("Login response status:", response.status);
        console.log("Login response headers:", JSON.stringify([...response.headers]));
        
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
        
        // Show verification form
        document.getElementById('verificationEmail').value = email;
        document.getElementById('verificationForm').style.display = 'block';
        document.getElementById('loginForm').style.display = 'none';
    } catch (error) {
        console.error("Registration error:", error);
        showMessage(error.message, 'error');
    }
}

async function verifyEmail(email, code) {
    try {
        console.log("Attempting verification...");
        // Use the endpoint that was identified as valid by the test
        const url = `${AUTH_ENDPOINT}/auth/verify`;
        console.log("Verification endpoint:", url);
        
        const requestBody = { 
            email, 
            code,
            clientId: COGNITO_CLIENT_ID
        };
        console.log("Verification request body:", JSON.stringify(requestBody));
        
        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            },
            body: JSON.stringify(requestBody)
        });

        console.log("Verification response status:", response.status);
        console.log("Verification response headers:", JSON.stringify([...response.headers]));
        
        const data = await response.json();
        console.log("Verification response data:", JSON.stringify(data));
        
        if (!response.ok) {
            throw new Error(data.message || 'Verification failed');
        }

        // Show success message
        showMessage('Email verified successfully! You can now log in.', 'success');
        
        // Show login form
        document.getElementById('verificationForm').style.display = 'none';
        document.getElementById('loginForm').style.display = 'block';
    } catch (error) {
        console.error("Verification error:", error);
        showMessage(error.message, 'error');
    }
}

// UI Helper functions
function showLoading() {
    document.getElementById('loading').classList.remove('hidden');
    document.getElementById('result-container').classList.add('hidden');
    document.getElementById('error-container').classList.add('hidden');
}

function showMessage(message, type) {
    const messageElement = type === 'error' ? document.getElementById('error-message') : document.getElementById('success-message');
    const container = type === 'error' ? document.getElementById('error-container') : document.getElementById('success-container');
    
    // Hide loading
    document.getElementById('loading').classList.add('hidden');
    
    // Show message
    messageElement.textContent = message;
    container.classList.remove('hidden');
    
    // Hide message after 5 seconds if it's a success message
    if (type === 'success') {
        setTimeout(() => {
            container.classList.add('hidden');
        }, 5000);
    }
}

function showResult(summary) {
    document.getElementById('loading').classList.add('hidden');
    document.getElementById('error-container').classList.add('hidden');
    document.getElementById('result-container').classList.remove('hidden');
    document.getElementById('summary-text').textContent = summary;
}

// Main summarization function
async function summarizePage() {
    showLoading();

    try {
        // Get current tab
        const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
        
        // Inject content script to get page content
        const [{ result }] = await chrome.scripting.executeScript({
            target: { tabId: tab.id },
            function: () => document.body.innerText
        });

        console.log("Content extracted, calling API...");
        
        // Prepare headers
        const headers = {
            'Content-Type': 'application/json'
        };
        
        // Add auth token if available
        if (authToken) {
            headers['Authorization'] = `Bearer ${authToken}`;
        }
        
        // Call API
        const response = await fetch(SUMMARIZE_ENDPOINT, {
            method: 'POST',
            headers: headers,
            body: JSON.stringify({
                url: tab.url,
                content: result,
                title: tab.title
            })
        });

        console.log("API response:", response);

        if (!response.ok) {
            throw new Error(`API responded with status ${response.status}`);
        }

        const data = await response.json();
        console.log("Response data:", data);
        showResult(data.summary);
    } catch (error) {
        console.error("Error in summarization:", error);
        showMessage(error.message, 'error');
    }
}

// Check authentication status on load
document.addEventListener('DOMContentLoaded', () => {
    console.log("Extension loaded, checking auth status");
    
    // Run debug info
    debugExtension();
    
    // Initialize DOM elements
    const loginForm = document.getElementById('loginForm');
    const summaryContent = document.getElementById('summaryContent');
    const loginBtn = document.getElementById('loginBtn');
    const registerBtn = document.getElementById('registerBtn');
    const verifyBtn = document.getElementById('verifyBtn');
    const logoutBtn = document.getElementById('logoutBtn');
    const summarizeBtn = document.getElementById('summarize-btn');
    const debugBtn = document.getElementById('debugBtn');
    const clearStorageBtn = document.getElementById('clearStorageBtn');
    
    // Debug buttons
    if (debugBtn) {
        debugBtn.addEventListener('click', () => {
            console.log("Debug button clicked");
            debugExtension();
            showMessage('Debug info logged to console', 'success');
        });
    }
    
    if (clearStorageBtn) {
        clearStorageBtn.addEventListener('click', () => {
            console.log("Clearing local storage");
            localStorage.clear();
            authToken = null;
            showMessage('Local storage cleared', 'success');
            
            if (loginForm && summaryContent) {
                loginForm.style.display = 'block';
                summaryContent.style.display = 'none';
            }
        });
    }
    
    const testAPIBtn = document.getElementById('testAPIBtn');
    if (testAPIBtn) {
        testAPIBtn.addEventListener('click', () => {
            console.log("Testing API endpoints");
            testAPI();
            showMessage('API test started, check console for results', 'success');
        });
    }
    
    // Check if elements exist
    if (!loginForm || !summaryContent) {
        console.error("Critical UI elements missing");
        return;
    }
    
    if (authToken) {
        console.log("User is authenticated");
        loginForm.style.display = 'none';
        summaryContent.style.display = 'block';
    } else {
        console.log("User is not authenticated");
        loginForm.style.display = 'block';
        summaryContent.style.display = 'none';
    }
    
    // Attach event listeners
    if (loginBtn) {
        loginBtn.addEventListener('click', () => {
            const email = document.getElementById('email').value;
            const password = document.getElementById('password').value;
            
            if (!email || !password) {
                showMessage('Please enter both email and password', 'error');
                return;
            }
            
            console.log(`Attempting to login with email: ${email}`);
            login(email, password);
        });
    }
    
    if (registerBtn) {
        registerBtn.addEventListener('click', () => {
            const email = document.getElementById('email').value;
            const password = document.getElementById('password').value;
            
            if (!email || !password) {
                showMessage('Please enter both email and password', 'error');
                return;
            }
            
            console.log(`Attempting to register with email: ${email}`);
            register(email, password);
        });
    }
    
    if (verifyBtn) {
        verifyBtn.addEventListener('click', () => {
            const email = document.getElementById('verificationEmail').value;
            const code = document.getElementById('verificationCode').value;
            
            if (!code) {
                showMessage('Please enter the verification code', 'error');
                return;
            }
            
            console.log(`Attempting to verify email: ${email} with code: ${code}`);
            verifyEmail(email, code);
        });
    }
    
    if (logoutBtn) {
        logoutBtn.addEventListener('click', () => {
            authToken = null;
            localStorage.removeItem('authToken');
            loginForm.style.display = 'block';
            summaryContent.style.display = 'none';
            showMessage('Logged out successfully', 'success');
        });
    }
    
    if (summarizeBtn) {
        summarizeBtn.addEventListener('click', () => {
            console.log("Summarize button clicked");
            summarizePage();
        });
    }
});