provider "aws" {
  region = var.aws_region
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
}

module "api_gateway" {
  source                    = "./modules/api_gateway"
  project_name              = var.project_name
  summarize_lambda_invoke_arn = module.lambda.summarize_lambda_invoke_arn
  auth_lambda_invoke_arn    = module.lambda.auth_lambda_invoke_arn
  summarize_lambda_name     = module.lambda.summarize_lambda_name
  auth_lambda_name          = module.lambda.auth_lambda_name
}