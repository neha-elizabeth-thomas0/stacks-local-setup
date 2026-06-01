terraform {
    cloud { 
      hostname = "tfcdev-440d497a.ngrok.app" 
      organization = "hashicorp"
    } 

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }
  required_version = ">= 1.2"
}
