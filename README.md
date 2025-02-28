# AI Web Summarizer Chrome Extension

We've all had moments when browsing a website and need to quickly find specific information or get a summary of the content without reading through everything. Standard keyword search (Cmd+F) works in some cases, but not when there are multiple aliases for a term or when the page is too long. This is especially relevant for job applications, research papers, or documentation-heavy websites where users need key insights fast.
To address this, we're building an AI-powered Chrome extension that acts as a smart assistant while browsing. The extension will provide three core functionalities:
1. Summarization – Quickly generate concise summaries of webpages and videos.
2. Smart Keyword Search – Find relevant information even when exact keywords aren't known, using AI-based alias detection.
3. Basic Question Answering – Answer simple queries based on webpage or video content, without requiring users to scan through everything manually.

## Initial POC - Text Summarization
Updated as of 27th Feb - trial setup for deploying text summarizer

### Overview

This POC demonstrates:
1. Text extraction from web pages
2. AI-powered summarization using AWS Bedrock
3. Simple Chrome extension UI
4. Infrastructure as Code with Terraform
5. CI/CD with GitHub Actions

### Project Structure

- `extension/`: Chrome Extension code - javascript
- `backend/`: AWS Lambda function code - python
- `infrastructure/`: Terraform IaC
