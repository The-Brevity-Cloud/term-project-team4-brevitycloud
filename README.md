# BrevityCloud AI Assistant - Chrome Extension

![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Python](https://img.shields.io/badge/python-3670A0?style=for-the-badge&logo=python&logoColor=ffdd54)
![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)
![JavaScript](https://img.shields.io/badge/javascript-%23323330.svg?style=for-the-badge&logo=javascript&logoColor=%23F7DF1E)
![HTML5](https://img.shields.io/badge/html5-%23E34F26.svg?style=for-the-badge&logo=html5&logoColor=white)
![CSS3](https://img.shields.io/badge/css3-%231572B6.svg?style=for-the-badge&logo=css3&logoColor=white)
![Chrome Extension](https://img.shields.io/badge/Chrome%20Extension-%234285F4.svg?style=for-the-badge&logo=googlechrome&logoColor=white)

***BrevityCloud enhances your browsing experience by providing AI-powered text summarization, page interaction via chat, image text detection, and voice input directly within your browser.***

## Features

*   **Webpage Summarization:** Get concise summaries of web articles using AWS Bedrock (Claude 3 Sonnet) or AWS Kendra.
*   **Chat with Page Context:** Ask questions about the current webpage content.
*   **Image Text Detection:** Right-click on any image on a webpage to detect and extract text using AWS Rekognition.
*   **Voice Input:** Use your microphone to dictate queries instead of typing.
*   **User Authentication:** Secure user accounts managed by AWS Cognito.
*   **History:** View your recent summaries and chat interactions.

## Architecture

![Architecture Diagram](resources/Architecture.png)

*   **Frontend:** Chrome Extension (Manifest V3) using HTML, CSS, JavaScript.
*   **Backend:** Serverless functions on AWS Lambda (Python 3.9).
*   **API:** Amazon API Gateway (HTTP API).
*   **AI/ML Services:**
    *   AWS Bedrock (Anthropic Claude 3 Sonnet) for summarization & chat QA.
    *   AWS Kendra for Retrieval-Augmented Generation (RAG) based summarization/chat.
    *   AWS Rekognition for image text detection.
    *   AWS Transcribe for voice-to-text.
*   **Authentication:** AWS Cognito.
*   **Database:** AWS DynamoDB for user data and history.
*   **Storage:** AWS S3 for webpage content indexing (Kendra) and temporary audio files (Transcribe).
*   **Infrastructure as Code:** Terraform with modular structure.

## Getting Started

For detailed setup instructions, usage scenarios, and development information, please see the **[USER MANUAL](USER-MANUAL.md)**.

