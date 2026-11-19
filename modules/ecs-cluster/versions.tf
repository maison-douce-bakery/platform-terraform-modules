# Lower bounds only: the consuming stack pins versions. 1.7 adds mock_provider for tests.
terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}
