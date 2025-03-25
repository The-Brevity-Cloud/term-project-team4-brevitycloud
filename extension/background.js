// This file is needed for the service worker defined in manifest.json
// For this POC, we'll keep it minimal
chrome.runtime.onInstalled.addListener(() => {
    console.log('AI Web Summarizer extension installed.');
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
    }
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
  const { path } = await chrome.sidePanel.getOptions({ tabId });

    chrome.sidePanel.setOptions({ path: mainPage });
  
});


chrome.runtime.onInstalled.addListener(() => {
  chrome.sidePanel.setOptions({ path: welcomePage });
  chrome.sidePanel.setPanelBehavior({ openPanelOnActionClick: true });
});