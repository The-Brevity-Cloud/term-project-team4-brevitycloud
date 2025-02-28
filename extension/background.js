// This file is needed for the service worker defined in manifest.json
// For this POC, we'll keep it minimal
chrome.runtime.onInstalled.addListener(() => {
    console.log('AI Web Summarizer extension installed.');
  });