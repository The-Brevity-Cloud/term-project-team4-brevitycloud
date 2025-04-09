async function requestMicrophonePermission() {
  console.log("IFrame: Attempting to request microphone permission...");
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    console.log("IFrame: Microphone access granted successfully.");
    // Important: Stop the tracks immediately after permission is granted
    stream.getTracks().forEach((track) => track.stop());
    // Optionally, send a message back to the main script if needed
    // chrome.runtime.sendMessage({ action: "permissionGranted" });
  } catch (error) {
    console.error("IFrame: Error requesting microphone permission:", error);
    // Optionally, send a message back about the error
    // chrome.runtime.sendMessage({ action: "permissionError", error: error.message });
  }
}

// Request permission as soon as the script loads in the iframe
requestMicrophonePermission(); 