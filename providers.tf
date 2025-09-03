terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    pinecone = {
      source  = "pinecone-io/pinecone"
      version = "~> 0.7"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Optional: manage Pinecone indexes via control plane (no secrets in state)
provider "pinecone" {
  api_key     = var.pinecone_api_key
  environment = var.pinecone_environment
}
