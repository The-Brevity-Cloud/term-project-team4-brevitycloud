#!/bin/bash

# Script to package the Rekognition Lambda function

# Variables
FUNCTION_NAME="rekognition"
ZIP_FILE="../infrastructure/lambda_function_${FUNCTION_NAME}.zip"
REQUIREMENTS_FILE="requirements.txt"

# Clean up previous build artifacts
rm -rf package
rm -f $ZIP_FILE

# Create packaging directory
mkdir package

# Install dependencies
pip install -r $REQUIREMENTS_FILE --target ./package

# Copy function code
cp ${FUNCTION_NAME}.py ./package/
cp logger.py ./package/

# Create zip file
cd package
zip -r9 $ZIP_FILE .
cd ..

# Clean up packaging directory
rm -rf package

echo "Rekognition Lambda function packaged successfully: ${ZIP_FILE}" 