provider "aws" {
  region = var.aws_region
}

terraform {
  backend "s3" {
    # Bucket name will be dynamically configured in workflow init step
    # bucket = "..." 
    # Key prefix will be dynamically configured in workflow init step
    # key    = "..." 
    region = "us-east-1"
    # Removed explicit bucket/key, will rely on -backend-config in init
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
  environment           = var.user
  lambda_zip_path       = "${path.module}/lambda_function.zip"
  auth_lambda_zip_path  = "${path.module}/lambda_function_auth.zip"
  rekognition_lambda_zip_path = "${path.module}/lambda_function_invoke_rekognition.zip"
  transcribe_lambda_zip_path  = "${path.module}/lambda_function_invoke_transcribe.zip"
  get_result_lambda_zip_path = "${path.module}/lambda_function_get_result.zip"
  kendra_index_id       = module.kendra.kendra_index_id
  dynamodb_table_arn    = module.dynamodb.dynamodb_table_arn
  dynamodb_table_name   = module.dynamodb.dynamodb_table_name
  cognito_user_pool_arn = module.cognito.cognito_user_pool_arn
  cognito_client_id     = module.cognito.cognito_client_id
  s3_bucket_name        = module.s3.s3_bucket_id
  s3_bucket_arn         = module.s3.s3_bucket_arn
  ecs_cluster_arn               = module.ecs.ecs_cluster_arn
  rekognition_task_def_arn      = module.ecs.rekognition_task_definition_arn
  transcribe_task_def_arn       = module.ecs.transcribe_task_definition_arn
  private_subnet_ids            = module.network.private_subnet_ids
  task_security_group_id        = module.network.ecs_tasks_security_group_id
  ecs_rekognition_task_role_arn = module.ecs.rekognition_task_role_arn
  ecs_transcribe_task_role_arn  = module.ecs.transcribe_task_role_arn
  ecs_task_execution_role_arn   = module.ecs.ecs_task_execution_role_arn
}

module "api_gateway" {
  source                      = "./modules/api_gateway"
  project_name                = var.project_name

  # Existing lambda integrations
  summarize_lambda_invoke_arn = module.lambda.summarize_lambda_invoke_arn
  summarize_lambda_name       = module.lambda.summarize_lambda_name
  auth_lambda_invoke_arn      = module.lambda.auth_lambda_invoke_arn
  auth_lambda_name            = module.lambda.auth_lambda_name
  get_result_lambda_invoke_arn = module.lambda.get_result_lambda_invoke_arn
  get_result_lambda_name      = module.lambda.get_result_lambda_name
}

module "rekognition" {
  source                      = "./modules/rekognition"
  project_name                = var.project_name
  api_gateway_id              = module.api_gateway.api_gateway_id
  api_gateway_execution_arn   = module.api_gateway.api_gateway_execution_arn
  invoke_rekognition_lambda_arn = module.lambda.invoke_rekognition_lambda_arn
  invoke_rekognition_lambda_name = module.lambda.invoke_rekognition_lambda_name
}

module "transcribe" {
  source                      = "./modules/transcribe"
  project_name                = var.project_name
  api_gateway_id              = module.api_gateway.api_gateway_id
  api_gateway_execution_arn   = module.api_gateway.api_gateway_execution_arn
  s3_bucket_name              = module.s3.s3_bucket_id
  invoke_transcribe_lambda_arn = module.lambda.invoke_transcribe_lambda_arn
  invoke_transcribe_lambda_name = module.lambda.invoke_transcribe_lambda_name
}

module "amplify_landing_page" {
  source = "./modules/amplify"

  app_name               = "brevitycloud-landing-page"
  repo_url               = var.github_repository_url
  github_pat_secret_name = var.github_pat_secret_name
  branch_name            = var.landing_page_source_branch
  user_tag               = var.user
}

# --- Networking --- 
module "network" {
  source = "./modules/network"

  project_name = var.project_name
  environment  = var.user
  aws_region   = var.aws_region
  # You can override defaults from variables.tf here if needed
  # vpc_cidr = "10.1.0.0/16"
  # availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
  # public_subnet_cidrs = [...] 
  # private_subnet_cidrs = [...] 
}

# --- ECR Repositories ---
module "ecr_rekognition" {
  source = "./modules/ecr"

  repository_name = "${var.project_name}-rekognition-service"
  project_name    = var.project_name
  environment     = var.user # Using 'user' for environment tag
}

module "ecr_transcribe" {
  source = "./modules/ecr"

  repository_name = "${var.project_name}-transcribe-service"
  project_name    = var.project_name
  environment     = var.user # Using 'user' for environment tag
}

# --- ECS Cluster, Tasks, Service ---
module "ecs" {
  source = "./modules/ecs"

  project_name                = var.project_name
  environment                 = var.user
  aws_region                  = var.aws_region
  vpc_id                      = module.network.vpc_id
  private_subnet_ids          = module.network.private_subnet_ids
  ecs_tasks_security_group_id = module.network.ecs_tasks_security_group_id
  rekognition_image_uri       = var.rekognition_image_uri # Passed from workflow
  transcribe_image_uri        = var.transcribe_image_uri # Passed from workflow
  s3_bucket_arn               = module.s3.s3_bucket_arn
  dynamodb_table_arn          = module.dynamodb.dynamodb_table_arn # Pass if needed
  s3_bucket_name              = module.s3.s3_bucket_id # Add S3 bucket name

  # Optional: Override CPU/Memory/Scaling defaults if necessary
  # transcribe_service_max_capacity = 5 
  # transcribe_scaling_cpu_target = 60
}

# --- Existing Modules needing network info / Future ECS module ---
# Ensure these do not conflict with networking resources if they create their own implicitly.
# If any existing modules require VPC/subnet/SG info, pass it from module.network outputs.
# Example for a hypothetical Lambda module needing VPC config:
# module "some_lambda" {
#   source = "./modules/lambda" 
#   vpc_id = module.network.vpc_id
#   subnet_ids = module.network.private_subnet_ids
#   security_group_ids = [module.network.ecs_tasks_security_group_id] # Or a specific Lambda SG
#   ...
# }

# Add other module calls here...