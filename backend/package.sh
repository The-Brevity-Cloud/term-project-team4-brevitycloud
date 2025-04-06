#!/bin/bash

# Create a temporary directory for packaging
mkdir -p lambda_package
cp summarize.py clean_text.py logger.py kendra_indexing.py s3_helper.py lambda_package/ 

# Install dependencies
pip install boto3 beautifulsoup4 python-jose -t lambda_package/

# Create zip file
cd lambda_package
zip -r ../lambda_function.zip .
cd ..

# Move zip to infrastructure directory
mv lambda_function.zip ../infrastructure/

# Clean up
rm -rf lambda_package 