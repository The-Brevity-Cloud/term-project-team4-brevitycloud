# --- ECS Cluster ---
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# --- CloudWatch Log Group for ECS Tasks ---
resource "aws_cloudwatch_log_group" "rekognition_logs" {
  name              = "/ecs/${var.project_name}-${var.environment}-rekognition"
  retention_in_days = var.cloudwatch_log_retention_days
  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "transcribe_logs" {
  name              = "/ecs/${var.project_name}-${var.environment}-transcribe"
  retention_in_days = var.cloudwatch_log_retention_days
  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# --- Rekognition Task Definition ---
resource "aws_ecs_task_definition" "rekognition" {
  family                   = "${var.project_name}-${var.environment}-rekognition"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.rekognition_task_cpu
  memory                   = var.rekognition_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.rekognition_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "rekognition-container"
      image     = var.rekognition_image_uri
      essential = true
      # Pass S3 bucket needed by the container
      environment = [
        { name = "S3_BUCKET", value = var.s3_bucket_name } # Get bucket NAME
        # Other necessary env vars like IMAGE_URL, JOB_ID are passed via RunTask overrides
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.rekognition_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      # portMappings = [] # No inbound ports needed if triggered by RunTask
    }
  ])

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# --- Transcribe Task Definition ---
resource "aws_ecs_task_definition" "transcribe" {
  family                   = "${var.project_name}-${var.environment}-transcribe"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.transcribe_task_cpu
  memory                   = var.transcribe_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.transcribe_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "transcribe-container"
      image     = var.transcribe_image_uri
      essential = true
      # Pass S3 bucket needed by the container, define others expected by override
      environment = [
        { name = "S3_BUCKET", value = var.s3_bucket_name },
        { name = "S3_KEY",    value = "" }, # Placeholder, overridden by Lambda
        { name = "JOB_NAME",  value = "" }  # Placeholder, overridden by Lambda
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.transcribe_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      # portMappings = []
    }
  ])

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# --- Transcribe Service (for Auto Scaling Demo) ---
resource "aws_ecs_service" "transcribe" {
  name            = "${var.project_name}-${var.environment}-transcribe-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.transcribe.arn
  desired_count   = var.transcribe_service_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [var.ecs_tasks_security_group_id]
    assign_public_ip = false # Run tasks in private subnets
  }

  # Enable service discovery or load balancing if needed for direct access (not needed for RunTask)
  # load_balancer {
  #   ...
  # }
  
  # Ensure service waits for steady state before considering deployment successful
  # (Helps prevent issues during updates)
  wait_for_steady_state = true 

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
  
  # Prevent Terraform from destroying the service if tasks are running
  # (useful during development, maybe remove for production teardown)
  # lifecycle {
  #   ignore_changes = [desired_count] # Ignore changes if managed by autoscaling
  # }
}

# --- Transcribe Service Auto Scaling ---
resource "aws_appautoscaling_target" "transcribe" {
  max_capacity       = var.transcribe_service_max_capacity
  min_capacity       = var.transcribe_service_min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.transcribe.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "transcribe_cpu" {
  name               = "${var.project_name}-${var.environment}-transcribe-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.transcribe.resource_id
  scalable_dimension = aws_appautoscaling_target.transcribe.scalable_dimension
  service_namespace  = aws_appautoscaling_target.transcribe.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.transcribe_scaling_cpu_target
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Optional: Add Memory Scaling Policy
# resource "aws_appautoscaling_policy" "transcribe_memory" {
#   ... 
#   target_tracking_scaling_configuration {
#     predefined_metric_specification {
#       predefined_metric_type = "ECSServiceAverageMemoryUtilization"
#     }
#     target_value = var.transcribe_scaling_memory_target 
#     ...
#   }
# } 