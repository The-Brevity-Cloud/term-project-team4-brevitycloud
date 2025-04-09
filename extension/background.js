// This file is needed for the service worker defined in manifest.json
// For this POC, we'll keep it minimal

// Function to send message to side panel
async function sendMessageToSidePanel(message) {
    try {
        // Find the active tab to ensure we're targeting the correct side panel context
        const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
        if (tab) {
             // Using chrome.runtime.sendMessage targeting the specific tab might be more robust
             // if the side panel isn't guaranteed to be the only listener.
             // However, for simplicity, assuming sidepanel is the primary listener.
            await chrome.runtime.sendMessage(message);
            console.log("Message sent to side panel:", message);
        } else {
            console.error("No active tab found to send message to side panel.");
        }
    } catch (error) {
        console.error("Error sending message to side panel:", error);
    }
}

// Context Menu Setup
chrome.runtime.onInstalled.addListener(() => {
    console.log('AI Web Summarizer extension installed or updated.');

    // Create context menu item for images
    chrome.contextMenus.create({
        id: "detectTextWithRekognition",
        title: "Detect Text Using Amazon Rekognition",
        contexts: ["image"] // Show only for images
    });

    // Other installation tasks...
    chrome.sidePanel.setOptions({ path: welcomePage });
    chrome.sidePanel.setPanelBehavior({ openPanelOnActionClick: true });
});

// Context Menu Click Listener
chrome.contextMenus.onClicked.addListener(async (info, tab) => {
    if (info.menuItemId === "detectTextWithRekognition") {
        if (info.srcUrl) {
            console.log("Image URL for Rekognition:", info.srcUrl);
            // Ensure side panel is open
            try {
                await chrome.sidePanel.open({ windowId: tab.windowId });
                console.log("Side panel opened for Rekognition request.");
                // Send the image URL to the side panel
                sendMessageToSidePanel({
                    action: "detectTextImage",
                    imageUrl: info.srcUrl
                });
            } catch (error) {
                console.error("Error opening side panel or sending message:", error);
            }
        } else {
            console.error("No image source URL found.");
        }
    }
});

chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.action === 'openSidePanel') {
        chrome.sidePanel.setOptions({
            path: 'sidepanel.html'
        }).then(() => {
            console.log('Side panel opened.');
        }).catch((error) => {
            console.error('Error opening side panel:', error);
        });
    } else if (request.action === 'requestMicPermission') {
        // Forward request to inject iframe to the content script
        chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
            if (tabs[0] && tabs[0].id) {
                chrome.tabs.sendMessage(tabs[0].id, { action: "injectMicPermissionIframe" }, (response) => {
                    if (chrome.runtime.lastError) {
                        console.error("Error sending message to content script:", chrome.runtime.lastError.message);
                        sendResponse({ success: false, error: chrome.runtime.lastError.message });
                    } else {
                        console.log("Background script: Injection message sent to content script.", response);
                        sendResponse({ success: true, response: response });
                    }
                });
            } else {
                 console.error("Could not find active tab to send message.");
                 sendResponse({ success: false, error: "Could not find active tab." });
            }
        });
        return true; // Indicate async response
    }
    // Add other message handling if needed
    // Return true ONLY if you intend to send an async response later
});

chrome.action.onClicked.addListener(() => {
    chrome.sidePanel.setOptions({
        path: 'sidepanel.html'
    }).then(() => {
        console.log('Side panel opened.');
    }).catch((error) => {
        console.error('Error opening side panel:', error);
    });
});

const mainPage ='sidepanel.html';
const welcomePage = 'welcome-sp.html';
chrome.tabs.onActivated.addListener(async ({ tabId }) => {
    // This listener might need adjustments depending on desired behavior
    // For now, let's assume we want the main panel on tab activation
   try {
       await chrome.sidePanel.setOptions({ tabId, path: mainPage, enabled: true });
   } catch (error) {
       console.error("Error setting side panel on tab activation:", error);
   }
});

// Listen for Tab Updates (Navigation)
chrome.tabs.onUpdated.addListener(async (tabId, changeInfo, tab) => {
    // Check if the update is for the main frame, the URL changed, and the tab is loaded
    if (changeInfo.status === 'complete' && changeInfo.url && tab.active) {
        console.log(`Background: Tab ${tabId} navigated to ${changeInfo.url}`);
        // Send a message to the side panel to update its state
        try {
            // Ensure the side panel is enabled for this tab before sending message
            // (Optional check, might depend on panel behavior settings)
            // const options = await chrome.sidePanel.getOptions({ tabId });
            // if (options.enabled) { ... }
            
            await chrome.runtime.sendMessage({
                action: "tabNavigated",
                url: changeInfo.url,
                tabId: tabId
            });
            console.log("Background: Sent tabNavigated message to side panel.");
        } catch (error) {
             // Ignore errors if the side panel isn't open or listening
             if (error.message.includes("Could not establish connection") || error.message.includes("Receiving end does not exist")) {
                 console.log("Background: Side panel likely closed, ignoring navigation message error.");
             } else {
                console.error("Background: Error sending tabNavigated message:", error);
             }
        }
    }
});

// Note: Multiple onInstalled listeners are merged. Ensure logic is combined correctly.
// The context menu creation logic is already inside an onInstalled listener above.