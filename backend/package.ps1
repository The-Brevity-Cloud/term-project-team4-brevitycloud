# Create a temporary directory for packaging
$tempDir = "lambda_package"
New-Item -ItemType Directory -Path $tempDir -Force

# Copy source files
Copy-Item -Path "summarize.py", "clean_text.py", "logger.py", "kendra_indexing.py", "s3_helper.py" -Destination $tempDir

# Install dependencies
pip install -r requirements.txt -t $tempDir

# Create zip file
Push-Location $tempDir
Compress-Archive -Path * -DestinationPath "../lambda_function.zip" -Force
Pop-Location

# Move zip to infrastructure directory
Move-Item -Path "lambda_function.zip" -Destination "../infrastructure/" -Force

# Clean up
Remove-Item -Path $tempDir -Recurse -Force 