# Create a temporary directory for packaging
$tempDir = "auth_package"
New-Item -ItemType Directory -Path $tempDir -Force

# Copy source files
Copy-Item -Path "auth.py" -Destination $tempDir

# Install dependencies
pip install -r requirements_auth.txt -t $tempDir

# Create zip file
Push-Location $tempDir
Compress-Archive -Path * -DestinationPath "../lambda_function_auth.zip" -Force
Pop-Location

# Move zip to infrastructure directory
Move-Item -Path "lambda_function_auth.zip" -Destination "../infrastructure/" -Force

# Clean up
Remove-Item -Path $tempDir -Recurse -Force 