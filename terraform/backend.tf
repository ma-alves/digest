terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # this is the backend for the Terraform state.
  # it is used to store the state of the Terraform configuration.
  # it is a good practice to use a backend to store the state of the Terraform configuration.
  backend "s3" {
    bucket       = "digest-terraform-state"
    key          = "digest/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
