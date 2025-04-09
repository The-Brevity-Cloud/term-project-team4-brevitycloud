# PowerShell script to package the Transcribe Lambda function

# Variables
$FunctionName = "transcribe"
$ZipFile = "../infrastructure/lambda_function_${FunctionName}.zip"
$RequirementsFile = "requirements.txt" # Using main requirements for boto3
$PackageDir = "package_${FunctionName}"

# Clean up previous build artifacts
if (Test-Path -Path $PackageDir) {
    Remove-Item -Recurse -Force $PackageDir
}
if (Test-Path -Path $ZipFile) {
    Remove-Item -Force $ZipFile
}

# Create packaging directory
New-Item -ItemType Directory -Path $PackageDir

# Install dependencies (only boto3 needed)
# If specific dependencies were added, install them:
pip install -r $RequirementsFile --target ./$PackageDir
# For now, copy necessary shared files
Copy-Item -Path "logger.py" -Destination ./$PackageDir/

# Copy function code
Copy-Item -Path "${FunctionName}.py" -Destination ./$PackageDir/

# Create zip file
Compress-Archive -Path ./$PackageDir/* -DestinationPath $ZipFile -Force

# Clean up packaging directory
Remove-Item -Recurse -Force $PackageDir

Write-Host "Transcribe Lambda function packaged successfully: $($ZipFile)" 