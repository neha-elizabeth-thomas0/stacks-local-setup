variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "varset_id" {
  type        = string
  description = "The ID of the variable set containing AWS credentials"
}