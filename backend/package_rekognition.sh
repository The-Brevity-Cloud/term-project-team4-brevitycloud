#!/bin/bash

# Script to package the Rekognition Lambda function

# Variables
FUNCTION_NAME="rekognition"
ZIP_NAME="lambda_function_${FUNCTION_NAME}.zip"
ZIP_FILE="../${ZIP_NAME}"
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

# Create zip file in current directory
cd package
zip -r ../$ZIP_NAME .
cd ..

# Ensure target directory exists
mkdir -p ../infrastructure

# Move the zip file to infrastructure folder
mv $ZIP_NAME ../infrastructure/

# Clean up packaging directory
rm -rf package

echo "Rekognition Lambda function packaged successfully: ../infrastructure/${ZIP_NAME}"
