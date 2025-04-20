#!/bin/bash
set -e

echo "Checking GitHub CLI login..."
gh auth status || gh auth login

echo "📦 Downloading latest extension config artifact from GitHub Actions..."
rm -f api_endpoint.txt cognito_client_id.txt 
gh run download -n extension-config

echo "Download complete. Verifying files..."

if [[ ! -f api_endpoint.txt || ! -f cognito_client_id.txt ]]; then
  echo "Error: Required config files not found after download."
  exit 1
fi

echo "Config files are ready to use."

API_ENDPOINT=$(cat api_endpoint.txt)
COGNITO_CLIENT_ID=$(cat cognito_client_id.txt)

echo "API_ENDPOINT: $API_ENDPOINT"
echo "COGNITO_CLIENT_ID: $COGNITO_CLIENT_ID"

echo "🛠️ Injecting values into extension/sidepanel.js..."
sed -i '' "s|const API_ENDPOINT = .*|const API_ENDPOINT = '${API_ENDPOINT}';|" extension/sidepanel.js
sed -i '' "s|const COGNITO_CLIENT_ID = .*|const COGNITO_CLIENT_ID = '${COGNITO_CLIENT_ID}';|" extension/sidepanel.js

echo "Cleaning up any old zip..."
rm -f chrome-extension*.zip

echo "Zipping extension directory with timestamp..."
cd extension
timestamp=$(date +%Y%m%d%H%M)
zip -r ../chrome-extension-$timestamp.zip .
cd ..

echo "Cleaning up temp files..."
rm -f api_endpoint.txt cognito_client_id.txt

echo "Done! Chrome Extension is updated"

echo "Launching Chrome with unpacked extension..."

chrome_path="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

"$chrome_path" \
  --load-extension="$(pwd)/extension" \
  --no-first-run \
  --disable-extensions-except="$(pwd)/extension"

echo "Chrome launched with local extension loaded"