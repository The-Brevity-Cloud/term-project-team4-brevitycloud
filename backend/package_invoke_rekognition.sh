#!/bin/bash
set -e

# Script to package the Lambda invoker function

LAMBDA_FUNC_NAME="invoke_rekognition"
OUTPUT_ZIP="../infrastructure/lambda_function_${LAMBDA_FUNC_NAME}.zip"

echo "Removing old zip file if exists..."
rm -f "$OUTPUT_ZIP"

echo "Creating deployment package for $LAMBDA_FUNC_NAME..."

# Zip the lambda handler file
zip -j "$OUTPUT_ZIP" "${LAMBDA_FUNC_NAME}.py"

# Add dependencies if any (boto3 is included in Lambda runtime, so usually not needed for simple invokers)
# If you add other dependencies:
# echo "Adding dependencies..."
# pip install --target ./package requests # Example dependency
# cd package
# zip -r ../"$OUTPUT_ZIP" .
# cd ..
# rm -rf package

echo "Lambda function $LAMBDA_FUNC_NAME packaged successfully: $OUTPUT_ZIP" 