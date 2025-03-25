# AI Web Summarizer Chrome Extension

## Architecture
![Architecture Diagram](https://github.com/SWEN-614-Spring-2025/term-project-team4-brevitycloud/blob/main/resources/Architecture.png)

## Demo POC Setup:
The below explanation will help setup and run the demo code for the sake of showing how the chrome extension can be setup with a basic frontend and backend.
## Tech Stack
- Frontend: Chrome Extension (JavaScript)
- Backend: AWS Lambda (Python 3.9)
- API: Amazon API Gateway (HTTP API)
- AI: AWS Bedrock (Claude v2)
- IaC: Terraform

## Directory Structure
```
.
├── extension/               # Chrome Extension
│   ├── manifest.json       # Extension configuration
│   ├── popup.html         # Extension UI
│   ├── popup.js          # UI logic
│   └── content.js        # Page content extractor
├── backend/               # AWS Lambda Function
│   ├── requirements.txt   # Python dependencies
│   └── summarize.py      # Lambda handler
└── infrastructure/        # Terraform IaC
    ├── main.tf            # Main file that calls modules
├── variables.tf       # Variable definitions
├── outputs.tf         # Output definitions
├── modules/
│   ├── api_gateway/   # API Gateway module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── lambda/        # Lambda functions module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── cognito/       # Cognito module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── dynamodb/      # DynamoDB module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── kendra/        # Kendra module
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
```

## Setup Instructions

### 1. AWS Setup
1. Install AWS CLI
2. Configure AWS credentials:
   ```bash
   aws configure
   ```
3. Enable AWS Bedrock in your account
   - Go to AWS Console → Bedrock
   - Enable Claude 3.5 Sonnet v2 model

### 2. Backend Deployment
```bash
# Install dependencies and create deployment package
cd backend
pip install -r requirements.txt -t .
zip -r ../infrastructure/lambda_function.zip .

# Use this if running on windows powershell:
# Compress-Archive -Path * -DestinationPath ../infrastructure/lambda_function.zip -Force

# Deploy infrastructure
cd ../infrastructure
terraform init
terraform plan
terraform apply

# Save the API endpoint
terraform output api_endpoint
```

### 3. Frontend Setup
1. Update API endpoint in `extension/popup.js`:
   ```javascript
   const API_ENDPOINT = 'your-api-endpoint';
   ```

2. Load extension in Chrome:
   - Open `chrome://extensions/`
   - Enable "Developer mode"
   - Click "Load unpacked"
   - Select `extension` directory

## Usage
1. Navigate to any webpage
2. Click extension icon
3. Click "Summarize This Page"
4. View AI-generated summary


## AWS Resource Costs
- Lambda: Free tier eligible
- API Gateway: Free tier eligible
- Bedrock: Pay per use

