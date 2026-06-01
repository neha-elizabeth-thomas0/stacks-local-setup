component "ec2" {
  source = "./ec2"
  providers = {
    aws = provider.aws.main
  }
  inputs = {
    instance_name = var.environment
    aws_region    = var.region
  }
}