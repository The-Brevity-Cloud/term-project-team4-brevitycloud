#!/bin/bash

# Script to package the Transcribe Lambda function

# Variables
FUNCTION_NAME="transcribe"
ZIP_FILE="../infrastructure/lambda_function_${FUNCTION_NAME}.zip"
REQUIREMENTS_FILE="requirements.txt" # Using main requirements for boto3

# Clean up previous build artifacts
rm -rf package_${FUNCTION_NAME}
rm -f $ZIP_FILE

# Create packaging directory
mkdir package_${FUNCTION_NAME}

# Install dependencies (only boto3 needed, likely already cached)
# If specific dependencies were added, install them:
# pip install -r requirements_transcribe.txt --target ./package_${FUNCTION_NAME}
# For now, copy necessary shared files
cp logger.py ./package_${FUNCTION_NAME}/

# Copy function code
cp ${FUNCTION_NAME}.py ./package_${FUNCTION_NAME}/

# Create zip file
cd package_${FUNCTION_NAME}
zip -r9 $ZIP_FILE .
cd ..

# Clean up packaging directory
rm -rf package_${FUNCTION_NAME}

echo "Transcribe Lambda function packaged successfully: ${ZIP_FILE}" 