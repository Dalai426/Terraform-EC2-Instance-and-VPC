terraform {
  // it is like npm packages
  required_providers {
    aws = {
      // it refers provider name in terraform registry
      source  = "hashicorp/aws"
      version = ">= 5.79.0"
    }
  }
  required_version = ">= 1.0.0"
}