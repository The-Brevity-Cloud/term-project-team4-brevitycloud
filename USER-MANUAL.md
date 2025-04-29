# BrevityCloud AI Assistant - User Manual (v3 - ECS Architecture, Automated Buckets)

This document provides detailed instructions on how to set up, configure, deploy, and use the BrevityCloud AI Assistant Chrome Extension with its ECS-based backend components.

## Table of Contents

1.  [Prerequisites (AWS Account & IAM User Setup)](#1-prerequisites-aws-account--iam-user-setup)
2.  [Prerequisites (GitHub Setup)](#2-prerequisites-github-setup)
3.  [Deployment (GitHub Actions Workflow)](#3-deployment-github-actions-workflow)
4.  [Frontend Setup (Local Extension Configuration)](#4-frontend-setup-local-extension-configuration)
5.  [Using the Application](#5-using-the-application)
    *   [Registration & Login](#registration--login)
    *   [Summarizing a Webpage](#summarizing-a-webpage)
    *   [Chatting with Page Context](#chatting-with-page-context)
    *   [Detecting Text in Images (Async)](#detecting-text-in-images-async)
    *   [Using Voice Input (Async)](#using-voice-input-async)
    *   [Viewing History](#viewing-history)
    *   [Viewing Landing Page](#viewing-landing-page)
    *   [Logging Out](#logging-out)
6.  [Testing Auto-Scaling](#6-testing-auto-scaling)
7.  [Troubleshooting](#7-troubleshooting)
8.  [Teardown (Destroy Workflow & Manual Cleanup)](#8-teardown-destroy-workflow--manual-cleanup)
9.  [Development Notes](#9-development-notes)

---

## 1. Prerequisites (AWS Account & IAM User Setup)

These steps need to be performed **once per AWS account** that will be used for deployment (e.g., each grader needs to do this in their own account).

1.  **AWS Account:** Ensure you have access to an AWS account.
2.  **IAM User Creation:**
    *   Log in to the AWS Management Console and navigate to the **IAM** service.
    *   Go to **Users** and click **Create user**.
    *   Enter a username (e.g., `michael-deployer`, `shireen-deployer`).
    *   Click **Next**.
    *   Choose **Attach policies directly**.
    *   Search for and attach policies that grant the necessary permissions. A combination like the following is recommended, but review your organization's policies:
        *   `IAMFullAccess` (Or more scoped IAM permissions if preferred, needs ability to create roles/policies for services)
        *   `AmazonS3FullAccess` (Needed for state bucket creation and interaction)
        *   `AmazonEC2ContainerRegistryFullAccess` (For ECR push/pull)
        *   `AmazonECS_FullAccess` (For ECS cluster/service/task management)
        *   `AWSLambda_FullAccess` (For Lambda creation/management)
        *   `AmazonAPIGatewayAdministrator` (For API Gateway setup)
        *   `AmazonDynamoDBFullAccess` (For DynamoDB table)
        *   `AmazonCognitoPowerUser` (For Cognito User Pool)
        *   `AmazonKendraFullAccess` (For Kendra Index)
        *   `AmazonBedrockFullAccess` (Or specifically allow `bedrock:InvokeModel` on the required models)
        *   `AmazonRekognitionFullAccess`
        *   `AmazonTranscribeFullAccess`
        *   `AmazonAmplifyAdministrator` (For Amplify deployment)
        *   `SecretsManagerReadWrite` (To read the GitHub PAT secret)
        *   `CloudWatchLogsFullAccess` (For log access)
        *   *(Note: Using `AdministratorAccess` grants all necessary permissions but is less secure. Use more granular policies if possible.)*
    *   Click **Next**, review, and click **Create user**.
3.  **Generate Access Keys:**
    *   Click on the newly created username in the IAM Users list.
    *   Go to the **Security credentials** tab.
    *   Scroll down to **Access keys** and click **Create access key**.
    *   Select **Command Line Interface (CLI)** as the use case.
    *   Acknowledge the recommendation and click **Next**.
    *   (Optional) Set a description tag.
    *   Click **Create access key**.
    *   **CRITICAL:** Immediately copy both the **Access key ID** and the **Secret access key**. Store them securely. The Secret access key will *not* be shown again.
4.  **Enable Bedrock Model Access:**
    *   Navigate to the **Amazon Bedrock** service console in the **us-east-1** region.
    *   In the bottom-left menu, click **Model access**.
    *   Click **Manage model access** (top-right).
    *   Find **Anthropic** -> **Claude 3 Sonnet** and check the box.
    *   Click **Save changes**.
5.  **Create GitHub PAT Secret in Secrets Manager:**
    *   Navigate to the **AWS Secrets Manager** service console in the **us-east-1** region.
    *   Click **Store a new secret**.
    *   Select **Other type of secret**.
    *   Under **Secret key/value**, click **Plaintext**.
    *   Paste your GitHub Personal Access Token (PAT) into the plaintext field. The PAT needs the `repo` scope to allow Amplify to access your repository.
    *   Click **Next**.
    *   Enter the **Secret name** exactly as `Github-PAT`.
    *   Click **Next** through the rotation settings (can leave as default).
    *   Review and click **Store**.

## 2. Prerequisites (GitHub Setup)

1.  **GitHub Account:** Ensure you have a GitHub account.
2.  **Repository Access:** Be added as a collaborator to the `The-Brevity-Cloud/term-project-team4-brevitycloud` repository.
3.  **Create GitHub Personal Access Token (PAT):** This token is needed for Amplify to access the repository code during deployment. You'll store this token in AWS Secrets Manager (see Section 1.5).
    *   Go to your GitHub **Settings**.
    *   In the left sidebar, scroll down and click **Developer settings**.
    *   Click **Personal access tokens** -> **Tokens (classic)**.
    *   Click **Generate new token** -> **Generate new token (classic)**.
    *   Give the token a descriptive **Note** (e.g., `brevitycloud-amplify-deploy`).
    *   Set the **Expiration** (e.g., 30 days, 90 days, or custom).
    *   Under **Select scopes**, check the box next to **`repo`** (Full control of private repositories). *No other scopes are needed.*
    *   Scroll down and click **Generate token**.
    *   **CRITICAL:** Immediately copy the generated token string. Store it securely, as you won't be able to see it again after leaving the page. You will paste this value into AWS Secrets Manager in step 1.5.
4.  **Configure GitHub Secrets:**
    *   Navigate to the repository on GitHub (`The-Brevity-Cloud/term-project-team4-brevitycloud`).
    *   Go to `Settings` > `Secrets and variables` > `Actions`.
    *   Click **New repository secret** for each of the following:
        *   `AWS_ACCOUNT_ID`: Enter your 12-digit AWS Account ID.
        *   `AWS_ACCESS_KEY_<YOUR_NAME_UPPERCASE>`: Enter the Access Key ID generated for your IAM User (e.g., for user `michael`, the secret name is `AWS_ACCESS_KEY_MICHAEL`).
        *   `AWS_SECRET_KEY_<YOUR_NAME_UPPERCASE>`: Enter the Secret Access Key generated for your IAM User (e.g., for user `michael`, the secret name is `AWS_SECRET_KEY_MICHAEL`).

## 3. Deployment (GitHub Actions Workflow)

This workflow deploys the entire backend infrastructure, Docker services, and the landing page.

1.  **Navigate to Actions:** Go to the **Actions** tab in the GitHub repository.
2.  **Select Workflow:** Find the **"Terraform Apply & Deploy Services"** workflow in the list.
3.  **Run Workflow:**
    *   Click the **"Run workflow"** dropdown button.
    *   Ensure the correct branch is selected (usually `main` for final deployment/grading, or `hemanth` for development).
    *   In the **"Team member identifier"** input box, enter your **lowercase** first name (e.g., `michael`, `shireen`, `peyton`, `hemanth`). This **must** match the suffix used in your GitHub secret names (but in lowercase).
    *   Click the green **"Run workflow"** button.
4.  **Monitor:** Observe the workflow progress in the Actions tab. It performs the following key steps:
    *   Checks out code from the selected branch.
    *   Configures AWS credentials using the secrets matching your input name.
    *   Creates an S3 bucket (`tf-state-<your_name>-brevity`) for Terraform state if it doesn't exist.
    *   Creates `terraform.tfvars` with your username and the current branch name.
    *   Packages Lambda functions.
    *   Initializes Terraform using your user-specific S3 state bucket/key.
    *   Applies Terraform to create ECR repositories.
    *   Builds and pushes Rekognition/Transcribe Docker images (from the current branch code) to ECR.
    *   Applies the full Terraform configuration (VPC, ECS, Lambdas, API Gateway, etc.).
    *   Exports API endpoint and Cognito Client ID.
    *   Uploads configuration as an artifact.
    *   Triggers an Amplify deployment using the code from the current branch.

## 4. Frontend Setup (Local Extension Configuration)

These steps configure the locally cloned Chrome extension to communicate with the deployed backend.

1.  **Load Extension in Chrome:**
    *   Open Google Chrome.
    *   Navigate to `chrome://extensions/`.
    *   Ensure **Developer mode** (top-right toggle) is **enabled**.
    *   Click **"Load unpacked"**.
    *   Select the `extension` directory within your local repository clone.
    *   The BrevityCloud AI Assistant should appear. Pin it to your toolbar for easy access.
2.  **Install github CLI:**
    *   **Windows:** Install chocolatey and then run: `choco install gh`
    *   **macOS:** Run: `brew install gh`
3.  **Run Deployment Script:**
    *   **Windows:** Open PowerShell in the repository root and run: `.\deployment.ps1`
    *   **macOS/Linux:** Open Terminal in the repository root and run: `bash deploy.sh`
    *   If you are running this script for the first time, please follow the instructions to grant access to our repo using the github CLI.
    *   This script reads the `.txt` files and injects the values into `extension/sidepanel.js`.
4. **If extension is already loaded:**
    *  Directly run the deployment.ps1 or deploy.sh and it will update the extension folder that is unpacked.

Extras:
1.  **Download Artifact:** Once the "Terraform Apply & Deploy Services" workflow completes successfully, navigate to the workflow run summary page.
2.  Scroll down to **Artifacts** and download the `extension-config` artifact (it will be a zip file).
3.  **Extract Files:** Extract the contents (`api_endpoint.txt`, `cognito_client_id.txt`) into the root directory of your locally cloned repository, overwriting if they exist.

## 5. Using the Application

Open the BrevityCloud side panel by clicking its icon in the Chrome toolbar.

### Registration & Login

*   Click the BrevityCloud extension icon.
*   If new, click "Register", enter email/password, click "Register".
*   Check email for verification code, enter it in the side panel, click "Verify".
*   Enter registered email/password, click "Login".

### Summarizing a Webpage

*   Navigate to a webpage.
*   Ensure logged in.
*   Click the extension icon.
*   Select model (Kendra/Bedrock).
*   Click "Summarize this page".
*   Wait for the summary to appear.

### Chatting with Page Context

*   Summarize a page first.
*   Type question in the input box at the bottom.
*   Click "Send".
*   The response appears below the summary.

### Detecting Text in Images (Async)

*   Navigate to a webpage with images.
*   Ensure logged in.
*   Right-click an image.
*   Select "Detect Text Using Amazon Rekognition".
*   Side panel opens/updates, shows the image, and displays "Processing...".
*   Detected text appears in the text area after polling completes (seconds). Errors are shown if failed.
    *   *(Screenshot Idea: Show side panel with image displayed and "Processing..." text, then another with detected text)*

### Using Voice Input (Async)

*   Ensure logged in.
*   Click the microphone icon.
*   Grant permission if prompted.
*   Speak query.
*   Click mic icon again to stop.
*   "Audio submitted..." message appears in chat.
*   Final transcript appears as a new chat message after polling (seconds-minutes). Errors are shown if failed.
    *   *(Screenshot Idea: Show chat area with "Audio submitted..." message, then another with the transcribed text message)*

### Viewing History

*   Ensure logged in.
*   Click "View History" button.
*   Panel displays recent summaries and chats.
*   Click "Back" to return.

### Viewing Landing Page

*   Go to the completed "Terraform Apply & Deploy Services" workflow run on GitHub Actions.
*   Expand the logs for the "Export Terraform outputs" step.
*   Find the URL labeled "Amplify Landing Page URL:".
*   Copy and paste this URL into your browser.

### Logging Out

*   Click "Logout" button.
*   Returns to login screen.

## 6. Testing Auto-Scaling

This tests the Transcribe ECS service's ability to scale under load.

1.  **Get JWT Token:** Log in to the extension. Open browser Dev Tools (F12) -> Application/Storage -> Session Storage -> Find extension origin -> Copy `id_token` value.
2.  **Run Test Script:**
    *   Open Bash terminal (Linux/macOS/WSL) in the repository root.
    *   Get API endpoint from `api_endpoint.txt` (created by `deployment.ps1`/`deploy.sh`).
    *   Run: `bash test_autoscaling.sh <API_ENDPOINT> <JWT_TOKEN>`
3.  **Observe Scaling (AWS Console):**
    *   Go to **ECS** -> Clusters -> Select your cluster (`brevity-cloud-<user>-cluster`).
    *   Navigate to the **Services** tab -> click `brevity-cloud-<user>-transcribe-service`.
    *   **Tasks Tab:** Watch "Running tasks count" increase (e.g., 1 -> 3). *(Screenshot: Show task count increasing)*
    *   **Events Tab:** Look for "service ... reached steady state" and "service ... registered X targets ..." events indicating scaling actions. *(Screenshot: Show scaling events)*
    *   **CloudWatch Metrics:** Go to CloudWatch -> Metrics -> ECS -> Cluster Name, Service Name. Graph `CPUUtilization`. Watch it spike during the test and drop afterward. *(Screenshot: Show CPU graph spiking)*
4.  **Verify Scale-In:** After the script finishes, observe the task count eventually return to the minimum (usually 1) as CPU usage drops.

## 7. Troubleshooting

*   **Workflow Failures:**
    *   `Configure AWS Credentials` step: Check GitHub Actions secret names match `AWS_ACCESS_KEY_<YOUR_NAME_UPPERCASE>` / `AWS_SECRET_KEY_<YOUR_NAME_UPPERCASE>`. Verify the corresponding IAM user has required permissions (Section 1).
    *   `Create S3 Backend Bucket` step: Verify IAM user has `s3:CreateBucket` and related S3 permissions.
    *   `Terraform Init/Plan/Apply`: Check detailed Terraform error message printed in the logs. Common issues: missing permissions for creating specific resources, invalid configuration, state lock errors.
    *   `Docker Push`: Verify ECR repository exists and IAM user has ECR push permissions.
    *   `Trigger Amplify Deployment`: Ensure the target branch exists in GitHub and the IAM user has `amplify:StartJob` permission.
*   **Login/API Errors (Extension UI):** Check browser developer console (F12) for network errors (4xx/5xx). Check API Gateway CloudWatch Logs (`/aws/apigateway/...`) and relevant Lambda logs (`/aws/lambda/...-summarize`, etc.).
*   **Rekognition/Transcribe Failures (UI Error / No Result):**
    *   Check **Invoker Lambda Logs First:** `/aws/lambda/brevity-cloud-<user>-invoke-rekognition` and `/aws/lambda/brevity-cloud-<user>-invoke-transcribe`. Look for errors invoking `ecs:RunTask` or `iam:PassRole`.
    *   Check **ECS Task Logs:** `/ecs/brevity-cloud-<user>-rekognition` and `/ecs/brevity-cloud-<user>-transcribe`. Look for Python errors (`rekognition.py`, `transcribe.py`), permission errors calling AWS services (Rekognition, Transcribe, S3), or missing environment variables.
    *   Check **Get Result Lambda Logs:** `/aws/lambda/brevity-cloud-<user>-get-result` if polling seems stuck or returns errors.
    *   Check **S3 Bucket:** Look in the results bucket (`<project>-results-<user>`) for output files (`rekognition-results/*.txt`, `transcribe-results/*.txt`) or failure markers (`transcribe-results/*.FAILED.txt`).
*   **Terraform State Lock:** If Terraform commands hang or explicitly mention a lock, follow manual unlock procedure (Section 8) *only if certain no other process is running*.

## 8. Teardown (Destroy Workflow & Manual Cleanup)

1.  **Run Destroy Workflow:**
    *   Navigate to GitHub Actions -> **"Terraform Destroy"**.
    *   Click **"Run workflow"** dropdown.
    *   Select the branch (usually doesn't matter for destroy).
    *   Enter your **lowercase** first name (e.g., `michael`) as the `user` input.
    *   Click **"Run workflow"**.
    *   This workflow authenticates, creates the S3 bucket if needed for init, packages Lambdas (for hash calculation), initializes Terraform using your state file, and runs `terraform destroy -auto-approve`.
2.  **Manual S3 Bucket Cleanup (Recommended):**
    *   The `terraform destroy` command **does not** delete the S3 state bucket (`tf-state-<user>-brevity`) as it's required for Terraform to operate.
    *   To fully clean up, navigate to the S3 service in the AWS Console and manually delete the `tf-state-<user>-brevity` bucket **after** the destroy workflow completes successfully. Ensure the bucket is empty first (Terraform state file and lock files should be gone).
3.  **Manual ECR Image Cleanup (Optional):**
    *   Terraform is configured with `force_delete=true` for the ECR repositories, which *should* delete the repositories even if they contain images.
    *   If for some reason images remain, you may need to manually delete them from the ECR console before deleting the repositories (if the destroy failed to remove the repo).

## 9. Development Notes

*   **Architecture:** Rekognition/Transcribe run in ECS Fargate tasks triggered by invoker Lambdas. Results stored in S3, status polled via API Gateway/Lambda.
*   **State:** Each user has a separate Terraform state file in a dedicated S3 bucket (`tf-state-<user>-brevity/user/terraform.tfstate`). Bucket created automatically by workflow.
*   **CI/CD:** `terraform-apply.yml` handles bucket creation, packaging, Terraform apply, Docker build/push, Amplify deploy. `terraform-destroy.yml` handles packaging and Terraform destroy.
*   **Landing Page:** Deployed via Amplify, triggered by the apply workflow using code from the branch the workflow ran on.
*   **Costs:** Monitor AWS costs, especially ECS Fargate, NAT Gateways, Bedrock, Kendra, Rekognition, Transcribe. Remember to run teardown/destroy when finished.