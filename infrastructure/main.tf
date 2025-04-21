provider "aws" {
  region = var.aws_region
}

terraform {
  backend "s3" {
    bucket = "tf-state-hemanth-brevity"
    key    = "ci-cd/state.tfstate"
    region = "us-east-1"
  }
}

module "kendra" {
  source       = "./modules/kendra"
  project_name = var.project_name
}

module "dynamodb" {
  source       = "./modules/dynamodb"
  project_name = var.project_name
}

module "cognito" {
  source       = "./modules/cognito"
  project_name = var.project_name
}

module "s3" {
  source           = "./modules/s3"
  project_name     = var.project_name
  aws_region       = var.aws_region
  kendra_index_id  = module.kendra.kendra_index_id
  kendra_role_arn  = module.kendra.kendra_role_arn
}

module "lambda" {
  source                = "./modules/lambda"
  project_name          = var.project_name
  lambda_zip_path       = "${path.module}/lambda_function.zip"
  auth_lambda_zip_path  = "${path.module}/lambda_function_auth.zip"
  kendra_index_id       = module.kendra.kendra_index_id
  dynamodb_table_arn    = module.dynamodb.dynamodb_table_arn
  dynamodb_table_name   = module.dynamodb.dynamodb_table_name
  cognito_user_pool_arn = module.cognito.cognito_user_pool_arn
  cognito_client_id     = module.cognito.cognito_client_id
  s3_bucket_name        = module.s3.s3_bucket_id
  s3_bucket_arn         = module.s3.s3_bucket_arn
}

module "api_gateway" {
  source                    = "./modules/api_gateway"
  project_name              = var.project_name
  summarize_lambda_invoke_arn = module.lambda.summarize_lambda_invoke_arn
  auth_lambda_invoke_arn    = module.lambda.auth_lambda_invoke_arn
  summarize_lambda_name     = module.lambda.summarize_lambda_name
  auth_lambda_name          = module.lambda.auth_lambda_name
}

module "rekognition" {
  source                      = "./modules/rekognition"
  project_name                = var.project_name
  api_gateway_id              = module.api_gateway.api_gateway_id
  api_gateway_execution_arn   = module.api_gateway.api_gateway_execution_arn
  lambda_role_name            = module.lambda.lambda_role_name
  rekognition_lambda_zip_path = "${path.module}/lambda_function_rekognition.zip"
}

module "transcribe" {
  source                      = "./modules/transcribe"
  project_name                = var.project_name
  api_gateway_id              = module.api_gateway.api_gateway_id
  api_gateway_execution_arn   = module.api_gateway.api_gateway_execution_arn
  lambda_role_name            = module.lambda.lambda_role_name
  s3_bucket_name              = module.s3.s3_bucket_id # Use the main content bucket for temp audio
  transcribe_lambda_zip_path  = "${path.module}/lambda_function_transcribe.zip"
  # transcribe_policy_arn is defaulted
  # s3_policy_arn - Assuming shared role policy is sufficient for PutObject
}

module "amplify_landing_page" {
  source = "./modules/amplify"

  app_name               = "brevitycloud-landing-page"
  repo_url               = var.github_repository_url
  github_pat_secret_name = var.github_pat_secret_name
  branch_name            = "main"
  user_tag               = var.user
}