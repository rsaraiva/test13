# Dynamic network discovery (decodes platform base infrastructure VPC)
data "aws_vpc" "platform" {
  tags = {
    Project = "ServiceFlow"
  }
}

# Auto-locate Private Subnet A for high-availability ECS task execution
data "aws_subnet" "private_a" {
  vpc_id = data.aws_vpc.platform.id
  tags = {
    Name = "ServiceFlowVpc/PrivateA"
  }
}

# Auto-locate Private Subnet B for high-availability ECS task execution
data "aws_subnet" "private_b" {
  vpc_id = data.aws_vpc.platform.id
  tags = {
    Name = "ServiceFlowVpc/PrivateB"
  }
}
# Lookup the unified platform API Gateway via id for resolving endpoint output
data "aws_apigatewayv2_api" "platform" {
  api_id = var.api_gateway_id
}

# Lookup the platform Cloud Map Private DNS Namespace for service discovery
data "aws_service_discovery_dns_namespace" "platform" {
  name = "serviceflow.local"
  type = "DNS_PRIVATE"
}
