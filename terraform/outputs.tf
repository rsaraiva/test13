output "service_endpoint" {
  value       = "${data.aws_apigatewayv2_api.platform.api_endpoint}/${var.service_name}"
  description = "Public service endpoint URL mapped through API Gateway"
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.repo.repository_url
  description = "ECR Repository URL for container image push"
}
