variable "aws_region" {
  type        = string
  description = "Target AWS Region"
  default     = "us-east-1"
}

variable "service_name" {
  type        = string
  description = "Microservice name identifier"
  default     = "test13"
}

variable "environment" {
  type        = string
  description = "Deployment environment"
  default     = "dev"
}

variable "db_engine" {
  type        = string
  description = "RDS engine model (postgres or mysql)"
  default     = "postgres"
}

variable "task_cpu" {
  type        = number
  description = "ECS Task CPU sizing units"
  default     = 256 # Cost Skill will optimize this
}

variable "task_memory" {
  type        = number
  description = "ECS Task Memory sizing units (MB)"
  default     = 512 # Cost Skill will optimize this
}

variable "db_instance_class" {
  type        = string
  description = "Burstable DB Instance class tier"
  default     = "db.t3.micro" # Cost Skill will optimize this
}

variable "desired_count" {
  type        = number
  description = "Active Fargate container counts"
  default     = 1 # Cost Skill will optimize this
}

variable "api_gateway_id" {
  type        = string
  description = "Unified platform API Gateway ID"
  default     = "09nfp64myk"
}

variable "vpc_link_id" {
  type        = string
  description = "Platform API Gateway VPC Link ID for secure private routing"
  default     = "xw0d3e"
}
