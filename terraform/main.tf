# 1. Security Groups (VPC Privilege Isolation)
resource "aws_security_group" "ecs_sg" {
  name        = "${var.service_name}-${var.environment}-ecs-sg"
  description = "Security Group for ECS Fargate Tasks"
  vpc_id      = data.aws_vpc.platform.id

  ingress {
    description = "Allow HTTP ingress from internal VPC traffic (API Gateway VPC Link)"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.platform.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.service_name}-ecs-sg"
    Environment = var.environment
  }
}

# 2. Cloud Map Service Discovery Registration
resource "aws_service_discovery_service" "service" {
  name = var.service_name

  dns_config {
    namespace_id = data.aws_service_discovery_dns_namespace.platform.id

    dns_records {
      ttl  = 10
      type = "SRV"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

# 3. ECR Repository (Pushed docker assets live here)
resource "aws_ecr_repository" "repo" {
  name                 = "${var.service_name}-${var.environment}-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = var.environment
  }
}

# 4. ECS Cluster, Task Definition, and IAM execution roles
resource "aws_ecs_cluster" "cluster" {
  name = "${var.service_name}-${var.environment}-cluster"

  tags = {
    Environment = var.environment
  }
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.service_name}-${var.environment}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_attach" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.service_name}-${var.environment}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
      }
    ]
  })
}

# Grant cloudwatch log access to task execution roles
resource "aws_iam_policy" "cw_logs_policy" {
  name        = "${var.service_name}-${var.environment}-cw-logs-policy"
  description = "Allow task execution to push logs to Cloudwatch"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_attach_cw" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.cw_logs_policy.arn
}

resource "aws_cloudwatch_log_group" "ecs_log_grp" {
  name              = "/ecs/${var.service_name}-${var.environment}"
  retention_in_days = 30

  tags = {
    Environment = var.environment
  }
}

resource "aws_ecs_task_definition" "task" {
  family                   = "${var.service_name}-${var.environment}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = var.service_name
      image     = "${aws_ecr_repository.repo.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
        }
      ]
      environment = [
        { name = "PORT", value = "8080" },
        { name = "ENVIRONMENT", value = var.environment },
        { name = "SERVICE_NAME", value = var.service_name }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_log_grp.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = var.service_name
        }
      }
    }
  ])

  tags = {
    Environment = var.environment
  }
}

# 5. API Gateway Integrations & Dynamic Custom Route Mapping
resource "aws_apigatewayv2_integration" "integration" {
  api_id             = var.api_gateway_id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  connection_type    = "VPC_LINK"
  connection_id      = var.vpc_link_id

  # Connects directly to the Cloud Map service via its ARN (required for HTTP APIs with VPC Link)
  integration_uri = aws_service_discovery_service.service.arn

  request_parameters = {
    "overwrite:path" = "$request.path.proxy"
  }
}

resource "aws_apigatewayv2_route" "route" {
  api_id    = var.api_gateway_id
  route_key = "ANY /${var.service_name}/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.integration.id}"
}

resource "aws_apigatewayv2_route" "route_root" {
  api_id    = var.api_gateway_id
  route_key = "ANY /${var.service_name}"
  target    = "integrations/${aws_apigatewayv2_integration.integration.id}"
}

# 6. ECS Fargate Service (Securely isolated in Private Subnets)
resource "aws_ecs_service" "service" {
  name            = "${var.service_name}-${var.environment}-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [data.aws_subnet.private_a.id, data.aws_subnet.private_b.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn   = aws_service_discovery_service.service.arn
    container_name = var.service_name
    container_port = 8080
  }

  tags = {
    Environment = var.environment
  }
}

# 7. SRE Observability: Metric alarms
# Observability Skill can inject resource tags and high-fidelity latency alarms here.
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.service_name}-${var.environment}-high-cpu-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alert when task CPU utilization exceeds 80%"

  dimensions = {
    ClusterName = aws_ecs_cluster.cluster.name
    ServiceName = aws_ecs_service.service.name
  }
}
