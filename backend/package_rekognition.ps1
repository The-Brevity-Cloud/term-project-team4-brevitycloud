# PowerShell script to package the Rekognition Lambda function

# Variables
$FunctionName = "rekognition"
$ZipFile = "../infrastructure/lambda_function_${FunctionName}.zip"
$RequirementsFile = "requirements.txt"

# Clean up previous build artifacts
if (Test-Path -Path package) {
    Remove-Item -Recurse -Force package
}
if (Test-Path -Path $ZipFile) {
    Remove-Item -Force $ZipFile
}

# Create packaging directory
New-Item -ItemType Directory -Path package

# Install dependencies
pip install -r $RequirementsFile --target ./package

# Copy function code
Copy-Item -Path "${FunctionName}.py" -Destination ./package/
Copy-Item -Path "logger.py" -Destination ./package/

# Create zip file
Compress-Archive -Path ./package/* -DestinationPath $ZipFile -Force

# Clean up packaging directory
Remove-Item -Recurse -Force package

Write-Host "Rekognition Lambda function packaged successfully: $($ZipFile)" 