variable "access_key" {
  description = "AWS access key"
  type        = string
  ephemeral   = true
}

variable "secret_key" {
  description = "AWS sensitive secret key."
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "session_token" {
  description = "AWS session token."
  type        = string
  sensitive   = true
  ephemeral   = true
}

required_providers {
  aws = {
    source  = "hashicorp/aws"
    version = "~> 5.0"
  }
}

provider "aws" "main" {
  config {
    region = var.region
    access_key = var.access_key
    secret_key = var.secret_key
    token      = var.session_token

  }
}
