# Lower bounds only: the consuming stack pins versions. 1.9 allows variable validations to reference other variables.
terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}
