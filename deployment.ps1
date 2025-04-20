# Chrome Extension Deployment PowerShell Script

# Check GitHub CLI login
Write-Host "Checking GitHub CLI login..." -ForegroundColor Cyan
try {
    gh auth status
}
catch {
    Write-Host "Not logged in. Logging in..." -ForegroundColor Yellow
    gh auth login
}

# Download extension config artifact
Write-Host "📦 Downloading latest extension config artifact from GitHub Actions..." -ForegroundColor Cyan
Remove-Item -Path api_endpoint.txt, cognito_client_id.txt -ErrorAction SilentlyContinue
gh run download -n extension-config

# Verify files
Write-Host "Download complete. Verifying files..." -ForegroundColor Cyan
if (-not (Test-Path "api_endpoint.txt") -or -not (Test-Path "cognito_client_id.txt")) {
    Write-Host "Error: Required config files not found after download." -ForegroundColor Red
    exit 1
}

Write-Host "Config files are ready to use." -ForegroundColor Green

# Extract just the URL from the files
# Read the content and extract just the URL part
$apiEndpointContent = Get-Content "api_endpoint.txt" -Raw
if ($apiEndpointContent -match "https://[^:\s]+") {
    $API_ENDPOINT = $matches[0]
}
else {
    Write-Host "Error: Could not extract valid API endpoint URL" -ForegroundColor Red
    Write-Host "Content of api_endpoint.txt:" -ForegroundColor Red
    Get-Content "api_endpoint.txt"
    exit 1
}

$COGNITO_CLIENT_ID = (Get-Content "cognito_client_id.txt" -Raw).Trim()

Write-Host "Extracted API_ENDPOINT: $API_ENDPOINT" -ForegroundColor Green
Write-Host "Extracted COGNITO_CLIENT_ID: $COGNITO_CLIENT_ID" -ForegroundColor Green

# Inject values into sidepanel.js
Write-Host "🛠️ Injecting values into extension/sidepanel.js..." -ForegroundColor Cyan
$sidepanelContent = Get-Content "extension/sidepanel.js" -Raw
$updatedContent = $sidepanelContent -replace "const API_ENDPOINT = .*", "const API_ENDPOINT = '$API_ENDPOINT';"
$updatedContent = $updatedContent -replace "const COGNITO_CLIENT_ID = .*", "const COGNITO_CLIENT_ID = '$COGNITO_CLIENT_ID';"
Set-Content -Path "extension/sidepanel.js" -Value $updatedContent

# Clean up old zip files
Write-Host "Cleaning up any old zip..." -ForegroundColor Cyan
Remove-Item -Path chrome-extension*.zip -ErrorAction SilentlyContinue

# Create the zip file with timestamp
Write-Host "Zipping extension directory with timestamp..." -ForegroundColor Cyan
$timestamp = Get-Date -Format "yyyyMMddHHmm"
$zipFileName = "chrome-extension-$timestamp.zip"

# Using PowerShell to create zip file
Push-Location extension
Compress-Archive -Path * -DestinationPath "../$zipFileName" -Force
Pop-Location

Write-Host "Cleaning up temp files..." -ForegroundColor Cyan
Remove-Item -Path api_endpoint.txt, cognito_client_id.txt -ErrorAction SilentlyContinue

Write-Host "Done! Chrome Extension is updated" -ForegroundColor Green

# Launch Chrome with the unpacked extension
Write-Host "Launching Chrome with unpacked extension..." -ForegroundColor Cyan
$chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
$extensionPath = Resolve-Path ".\extension"

if (Test-Path $chromePath) {
    & $chromePath --load-extension="$extensionPath" --no-first-run --disable-extensions-except="$extensionPath"
    Write-Host "Chrome launched with local extension loaded" -ForegroundColor Green
}
else {
    Write-Host "Chrome executable not found at $chromePath. Please check your Chrome installation path." -ForegroundColor Yellow
    Write-Host "To manually launch Chrome with the extension, run:" -ForegroundColor Yellow
    Write-Host "chrome.exe --load-extension='$extensionPath' --no-first-run --disable-extensions-except='$extensionPath'" -ForegroundColor Yellow
}