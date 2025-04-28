# BrevityCloud AI Assistant - User Manual (v2 - ECS Architecture)

This document provides detailed instructions on how to set up, configure, deploy, and use the BrevityCloud AI Assistant Chrome Extension with its ECS-based backend components.

## Table of Contents

1.  [Prerequisites](#1-prerequisites)
2.  [AWS Setup](#2-aws-setup)
3.  [Backend Deployment (Terraform & GitHub Actions)](#3-backend-deployment-terraform--github-actions)
    *   [GitHub Actions Workflow Overview](#github-actions-workflow-overview)
    *   [Secrets Configuration](#secrets-configuration)
    *   [Running the Deployment Workflow](#running-the-deployment-workflow)
4.  [Frontend Setup (Extension Loading)](#4-frontend-setup-extension-loading)
5.  [Using the Application](#5-using-the-application)
    *   [Registration & Login](#registration--login)
    *   [Summarizing a Webpage](#summarizing-a-webpage)
    *   [Chatting with Page Context](#chatting-with-page-context)
    *   [Detecting Text in Images (Async)](#detecting-text-in-images-async)
    *   [Using Voice Input (Async)](#using-voice-input-async)
    *   [Viewing History](#viewing-history)
    *   [Logging Out](#logging-out)
6.  [Testing Auto-Scaling](#6-testing-auto-scaling)
7.  [Troubleshooting](#7-troubleshooting)
8.  [Development Notes](#8-development-notes)
9.  [Teardown (Terraform Destroy)](#9-teardown-terraform-destroy)

---

## 1. Prerequisites

*   **Git:** To clone the repository.
*   **GitHub Account:** With access to the project repository and permissions to run Actions.
*   **AWS Account:** With permissions to create the necessary resources (IAM User, Lambda, API Gateway, Cognito, DynamoDB, S3, Kendra, Bedrock, Rekognition, Transcribe, ECR, ECS, VPC, CloudWatch, etc.).
*   **AWS CLI:** Installed locally (optional, for manual checks or creating initial IAM users).
*   **Web Browser:** Google Chrome or a Chromium-based browser.
*   **(Optional) Shell Environment:** Bash (Linux/macOS/WSL) or PowerShell (Windows) for running local scripts (like the extension deployment script or auto-scaling test).
*   **(Optional) Docker:** Installed locally if you want to build/test container images outside of GitHub Actions.

## 2. AWS Setup

1.  **IAM User:** Create an IAM User for each team member who will run the deployment workflow (e.g., `hemanth-github-deployer`).
    *   Navigate to the IAM service in the AWS Console.
    *   Create a new user.
    *   Attach necessary permissions to this user: Permissions to create/manage all resources defined in Terraform (VPC, ECR, ECS, Lambda, API GW, S3, DynamoDB, Cognito, Kendra, Rekognition, Transcribe, Bedrock, CloudWatch, Amplify, Secrets Manager read, IAM roles/policies for services, etc.), plus `ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`, `ecr:PutImage`, `ecs:RunTask`, `iam:PassRole` (for ECS Task roles), `amplify:StartJob`.
    *   **Generate Access Keys:** On the user's security credentials tab, create an Access Key ID and Secret Access Key. **Securely store these keys immediately**, as the secret key is only shown once.
2.  **Enable AWS Bedrock Model Access:**
    *   Navigate to the AWS Bedrock console in your chosen region (`us-east-1`).
    *   Go to "Model access".
    *   Request access and ensure access is granted for `anthropic.claude-3-sonnet-20240229-v1:0` (or the model used in `backend/summarize.py`).
3.  **Secrets Manager:** Create a secret in AWS Secrets Manager (e.g., named `Github-PAT`) containing a GitHub Personal Access Token with `repo` scope. This is used by Terraform to allow Amplify to connect to your repository.

## 3. Backend Deployment (Terraform & GitHub Actions)

The entire backend infrastructure and service deployment is managed by Terraform, executed via a GitHub Actions workflow.

### GitHub Actions Workflow Overview

The primary workflow is defined in `.github/workflows/terraform-apply.yml`. When triggered manually, it performs the following steps:

1.  **Checkout:** Checks out the repository code.
2.  **Configure AWS Credentials:** Assumes the pre-configured IAM Role using OIDC based on the `user` input.
3.  **Login to ECR:** Authenticates Docker with your AWS Elastic Container Registry.
4.  **Build & Push Images:** Builds Docker images for the Rekognition and Transcribe services (`backend/Dockerfile.*`) and pushes them to their respective ECR repositories, tagged with the Git commit SHA.
5.  **Setup Terraform:** Initializes the Terraform CLI.
6.  **Package Lambdas:** Creates deployment packages (.zip files) for the `summarize`, `auth`, `invoke_rekognition`, `invoke_transcribe`, and `get_result` Lambda functions using the `backend/package_*.sh` scripts.
7.  **Terraform Init:** Initializes Terraform using the S3 backend configured for the specified user (e.g., `s3://tf-state-<user>-brevity/...`).
8.  **Terraform Validate:** Checks the Terraform code for syntax errors.
9.  **Terraform Plan:** (Optional but implicitly run) Calculates the changes needed.
10. **Terraform Apply:** Applies the Terraform configuration, creating/updating all AWS resources (VPC, ECR, ECS Cluster/Tasks/Service, Lambdas, API Gateway, S3, DynamoDB, Cognito, Kendra, Amplify, IAM Roles, etc.). The URIs of the newly pushed Docker images are passed as variables to this step.
11. **Export Outputs:** Extracts the API Gateway endpoint and Cognito Client ID into text files (`api_endpoint.txt`, `cognito_client_id.txt`).
12. **Upload Artifact:** Uploads the output text files as a workflow artifact named `extension-config` for use by the local frontend setup script.
13. **Trigger Amplify Deployment:** Starts a build and deployment job in AWS Amplify for the `hemanth` branch to update the landing page.

### Secrets Configuration

Before running the workflow, ensure the following secrets are configured in your GitHub repository settings (`Settings` > `Secrets and variables` > `Actions`):

*   `AWS_ACCOUNT_ID`: Your 12-digit AWS Account ID.
*   `AWS_ACCESS_KEY_ID_<USER>`: The AWS Access Key ID for the IAM user corresponding to the `user` input (e.g., `AWS_ACCESS_KEY_ID_hemanth`).
*   `AWS_SECRET_ACCESS_KEY_<USER>`: The AWS Secret Access Key for the IAM user corresponding to the `user` input (e.g., `AWS_SECRET_ACCESS_KEY_hemanth`).

Replace `<USER>` with the actual team member identifier (`hemanth`, `swetha`, etc.). You need to create separate secrets for each user who will run the workflow.

### Running the Deployment Workflow

1.  Navigate to the "Actions" tab in your GitHub repository.
2.  Select the "Terraform Apply & Deploy Services" workflow.
3.  Click the "Run workflow" dropdown.
4.  Enter your team member identifier (e.g., `hemanth`) in the `user` input field.
5.  Click "Run workflow".
6.  Monitor the workflow progress in the Actions tab.

## 4. Frontend Setup (Extension Loading)

After the GitHub Actions workflow completes successfully, you need to configure and load the Chrome extension locally.

1.  **Download Artifacts:**
    *   Go to the completed workflow run page on GitHub Actions.
    *   Download the `extension-config` artifact. It will be a zip file containing `api_endpoint.txt` and `cognito_client_id.txt`.
    *   Extract these files into the root directory of your local repository clone.
2.  **Run Local Deployment Script:** This script injects the downloaded configuration into the extension code.
    *   **Windows:** Open PowerShell, navigate to the repository root, and run: `.\deployment.ps1`
    *   **macOS/Linux:** Open Terminal, navigate to the repository root, and run: `bash deploy.sh`
    *   *(Note: These scripts previously downloaded artifacts using `gh cli`, you might need to adjust them or manually copy the file contents if `gh run download` doesn't work as expected)*
    *   Alternatively, **Manually Update Configuration:** Open `extension/sidepanel.js`. Find `API_ENDPOINT` and `COGNITO_CLIENT_ID` constants and replace their placeholder values with the content from the downloaded `.txt` files.
3.  **Load the Extension in Chrome:**
    *   Open Chrome and navigate to `chrome://extensions/`.
    *   Enable **Developer mode**.
    *   Click **"Load unpacked"**.
    *   Select the `extension` directory within your repository.
    *   The BrevityCloud AI Assistant should appear. Pin it for easy access.

## 5. Using the Application

### Registration & Login

1.  Click the BrevityCloud extension icon to open the side panel.
2.  If you are a new user, click the "Register" link.
3.  Enter your email address and a desired password. Click "Register".
4.  Check your email for a verification code from AWS Cognito.
5.  Enter the verification code in the side panel and click "Verify".
6.  You will be taken to the login screen. Enter your registered email and password, then click "Login".

### Summarizing a Webpage

1.  Navigate to a webpage you want to summarize.
2.  Ensure you are logged into the extension.
3.  Click the BrevityCloud extension icon.
4.  Select the desired processing model (Kendra or Bedrock) using the toggle buttons.
5.  Click the "Summarize this page" button.
6.  Wait for the loading indicator to finish. The summary will appear in the panel.

### Chatting with Page Context

1.  Summarize a page first (as above) to load its context.
2.  Type a question related to the page content in the input box at the bottom of the panel.
3.  Click "Send".
4.  The AI will answer your question based on the page's content. The response will appear below the summary.

### Detecting Text in Images (Async)

1.  Navigate to a webpage with images.
2.  Ensure you are logged in.
3.  Right-click an image.
4.  Select "Detect Text Using Amazon Rekognition".
5.  The side panel will open, display the image, and show a "Processing..." message in the text area.
6.  The extension will poll for the result in the background.
7.  Once processing is complete (usually within seconds), the detected text will appear in the text area.
8.  If an error occurs, an error message will be shown.

### Using Voice Input (Async)

1.  Ensure you are logged in.
2.  Click the microphone icon.
3.  Grant microphone permission if prompted.
4.  Speak your query.
5.  Click the icon again to stop recording.
6.  A message like "Audio submitted. Processing transcript..." will appear in the chat.
7.  The extension will poll for the result.
8.  Once complete (can take seconds to a minute depending on length), the final transcript will appear as a new message in the chat.
9.  If transcription fails or times out, an error message will appear in the chat.
10. *(Limitation: The transcript appears as a new message, it does not automatically populate the input box for sending as a chat query)*

### Viewing History

1.  Ensure you are logged into the extension.
2.  Click the "View History" button (below the Logout button).
3.  The panel will display your last 5 summaries and chat interactions, sorted by most recent.
4.  Click the "Back" button to return to the main summarization/chat view.

### Logging Out

1.  Click the "Logout" button at the bottom of the main panel.
2.  You will be returned to the login screen.

## 6. Testing Auto-Scaling

The Transcribe backend is deployed as an ECS Service configured for auto-scaling based on CPU utilization.

1.  **Get JWT Token:** Log in to the extension successfully. Open the browser's developer console (F12), go to the "Application" (or "Storage") tab, find "Session Storage", select the extension's origin, and copy the value associated with the `id_token` key.
2.  **Run Test Script:**
    *   Open a Bash terminal (Linux/macOS/WSL).
    *   Make the script executable: `chmod +x test_autoscaling.sh`
    *   Run the script, passing the API endpoint (from `api_endpoint.txt`) and your JWT token:
        ```bash
        ./test_autoscaling.sh <your_api_endpoint_url> <your_jwt_token>
        ```
    *   The script will send multiple concurrent requests to the `/transcribe` endpoint.
3.  **Observe Scaling:**
    *   Go to the AWS Console -> ECS -> Clusters -> Select your cluster (e.g., `brevity-cloud-<user>-cluster`).
    *   Navigate to the `brevity-cloud-<user>-transcribe-service`.
    *   Monitor the "Tasks" tab. You should see the "Running tasks count" increase from the desired count (usually 1) towards the maximum (default 3) as the load increases.
    *   Check the "Events" tab to see messages related to Application Auto Scaling triggering scaling actions.
    *   Check CloudWatch Metrics for the service's `CPUUtilization`. It should spike during the test.
    *   *(Note: Scaling actions take a few minutes to occur after thresholds are met.)*
    *   After the script finishes, the load will decrease, and eventually, the service should scale back down to the minimum task count.

## 7. Troubleshooting

*   **Workflow Failures:** Check the specific step logs in GitHub Actions for errors.
    *   `Configure AWS Credentials` step: Ensure the correct secrets (`AWS_ACCESS_KEY_ID_<USER>`, `AWS_SECRET_ACCESS_KEY_<USER>`) exist in GitHub secrets and match the `user` input provided to the workflow. Verify the IAM user has the necessary permissions listed in the AWS Setup section.
    *   Docker push errors, Terraform errors, AWS CLI errors.
*   **Login/API Errors:** Check API Gateway CloudWatch Logs (`/aws/apigateway/...`) and relevant Lambda logs (`/aws/lambda/...-summarize`, `...-auth`, `...-invoke-rekognition`, `...-invoke-transcribe`, `...-get-result`) for errors.
*   **Rekognition/Transcribe Failures (No Result):**
    *   Check the corresponding *invoker* Lambda logs first (`...-invoke-rekognition`, `...-invoke-transcribe`) to see if `ecs:RunTask` was called successfully.
    *   Check the ECS Task logs in CloudWatch (log groups `/ecs/brevity-cloud-<user>-rekognition` or `/ecs/brevity-cloud-<user>-transcribe`). Look for Python errors or permission issues within the container.
    *   Check the `get_result` Lambda logs if polling seems stuck.
    *   Check the S3 bucket for result files (`rekognition-results/`, `transcribe-results/`) or failure files (`transcribe-results/....FAILED.txt`).
*   **Extension UI Issues:** Use the browser's developer console (F12) for the side panel to check for JavaScript errors related to polling or displaying results.
*   **Terraform State Lock:** If a workflow fails mid-apply, the Terraform state might be locked. You may need to manually unlock it via the AWS CLI (`terraform force-unlock`) after verifying no other process is running.

## 8. Development Notes

*   **Architecture:** Rekognition and Transcribe logic now runs in ECS Fargate tasks, triggered by specific invoker Lambda functions. Results are saved to S3.
*   **Asynchronous Flow:** Frontend polls a `/results/{jobId}` API endpoint to check for task completion and retrieve results.
*   **CI/CD:** The `terraform-apply.yml` workflow handles Docker builds, ECR push, Lambda packaging, Terraform apply, and Amplify deployment.
*   **Result Storage:** Successful results are stored as `.txt` files in `s3://<bucket>/rekognition-results/` or `s3://<bucket>/transcribe-results/`. Transcribe failures are noted in `.FAILED.txt` files.
*   **Configuration:** API Endpoint and Cognito Client ID are passed to the local deployment scripts via the `extension-config` artifact from GitHub Actions.
*   **Dependencies:** Backend dependencies are in `backend/requirements.txt` (used by Dockerfiles). Lambda invokers have minimal dependencies.
*   **Costs:** Monitor AWS costs, especially for ECS Fargate, Bedrock, Kendra, Rekognition, Transcribe, and NAT Gateways.

## 9. Teardown (Terraform Destroy)

A separate GitHub Actions workflow (`.github/workflows/terraform-destroy.yml`) handles infrastructure teardown.

1.  Navigate to the "Actions" tab in your GitHub repository.
2.  Select the "Terraform Destroy" workflow.
3.  Click "Run workflow".
4.  Enter the `user` identifier whose infrastructure you want to destroy.
5.  Click "Run workflow".
6.  This workflow runs `terraform destroy -auto-approve` using the S3 backend state for the specified user, removing the AWS resources managed by Terraform.
    *   **Caution:** This permanently deletes infrastructure. Ensure S3 buckets used for state or results are handled appropriately (e.g., backup results, configure bucket lifecycle/deletion policies). 