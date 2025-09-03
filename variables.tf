variable "aws_region" {
  type        = string
  description = "AWS region for BYOC (e.g., us-east-1)"
  default     = "us-east-1"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.52.0.0/16"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  default     = ["10.52.1.0/24", "10.52.2.0/24"]
}

variable "public_subnet_cidrs" {
  type        = list(string)
  default     = ["10.52.101.0/24", "10.52.102.0/24"]
}

# Provided by Pinecone BYOC onboarding
variable "pinecone_aws_account_id" {
  type        = string
  description = "Pinecone AWS account that will assume the deployment role (BYOC)"
}

variable "pinecone_external_id" {
  type        = string
  description = "External ID Pinecone requires in the trust policy"
  sensitive   = true
}

variable "pinecone_api_key" {
  type        = string
  description = "Pinecone API key (for optional index mgmt only; keep out of state)"
  sensitive   = true
  default     = null
}

variable "pinecone_environment" {
  type        = string
  description = "Pinecone control-plane environment/project (if applicable)"
  default     = null
}

# AWS Interface endpoint services for private egress (adjust as needed)
variable "interface_endpoint_services" {
  type        = list(string)
  description = "Interface endpoint services created for private egress"
  default = [
    "com.amazonaws.${var.aws_region}.ecr.api",
    "com.amazonaws.${var.aws_region}.ecr.dkr",
    "com.amazonaws.${var.aws_region}.logs",
    "com.amazonaws.${var.aws_region}.ssm",
    "com.amazonaws.${var.aws_region}.ec2",
    "com.amazonaws.${var.aws_region}.kms",
    "com.amazonaws.${var.aws_region}.sts"
  ]
}

# Third‑party PrivateLink services (e.g., Pinecone service names). Optional.
variable "pinecone_vpce_services" {
  type        = list(string)
  description = "Third‑party Interface endpoint service names provided by Pinecone"
  default     = []
}

# App/service tunables
variable "app_name"        { type = string  default = "byoc-agents" }
variable "container_image" { type = string  description = "ECR image URI (or DockerHub) for your app" }
variable "container_port"  { type = number  default = 8080 }
variable "desired_count"   { type = number  default = 2 }
variable "task_cpu"        { type = number  default = 512 }   # 0.5 vCPU
variable "task_memory"     { type = number  default = 1024 }  # 1 GB

# Principals allowed to read the app secret at runtime (task role ARN, Lambda role ARN, etc.)
variable "app_reader_principal_arns" {
  type        = list(string)
  description = "IAM principal ARNs permitted to read Secrets Manager secret"
  default     = []
}
