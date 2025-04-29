variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "brevitycloud"
}

variable "environment" {
  description = "The deployment environment (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of Availability Zones to use"
  type        = list(string)
  # Ensure these are available in your selected region
  default     = ["us-east-1a", "us-east-1b"] 
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets (must match AZ count)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets (must match AZ count)"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
} 