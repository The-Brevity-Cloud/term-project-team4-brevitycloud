#!/bin/bash

# Script to package the Transcribe Lambda function

# Variables
FUNCTION_NAME="transcribe"
PACKAGE_DIR="package_${FUNCTION_NAME}"
ZIP_NAME="lambda_function_${FUNCTION_NAME}.zip"
ZIP_FILE="../${ZIP_NAME}"
REQUIREMENTS_FILE="requirements.txt" # Shared requirements, mainly boto3

# Clean up previous build artifacts
rm -rf $PACKAGE_DIR
rm -f $ZIP_NAME

# Create packaging directory
mkdir $PACKAGE_DIR

# Copy shared files and function code
cp logger.py ${PACKAGE_DIR}/
cp ${FUNCTION_NAME}.py ${PACKAGE_DIR}/

# (Optional) Install dependencies if needed
# pip install -r requirements_transcribe.txt --target ./$PACKAGE_DIR

# Create zip file in current directory
cd $PACKAGE_DIR
zip -r ../$ZIP_NAME .
cd ..

# Ensure target directory exists
mkdir -p ../infrastructure

# Move the zip file to infrastructure folder
mv $ZIP_NAME ../infrastructure/

# Clean up packaging directory
rm -rf $PACKAGE_DIR

echo "Transcribe Lambda function packaged successfully: ../infrastructure/${ZIP_NAME}"
