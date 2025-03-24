#!/bin/bash

# Create a temporary directory for packaging
mkdir -p auth_package
cp auth.py auth_package/

# Install dependencies
pip install boto3 python-jose -t auth_package/

# Create zip file
cd auth_package
zip -r ../lambda_function_auth.zip .
cd ..

# Move zip to infrastructure directory
mv lambda_function_auth.zip ../infrastructure/

# Clean up
rm -rf auth_package 