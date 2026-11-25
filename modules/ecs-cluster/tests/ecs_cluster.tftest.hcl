# Mocked AWS: no credentials, no cost.
mock_provider "aws" {}

variables {
  name = "mdb-test"
}

run "defaults" {
  assert {
    condition     = aws_ecs_cluster.this.name == "mdb-test"
    error_message = "The cluster must be named after the input."
  }

  assert {
    condition     = one([for s in aws_ecs_cluster.this.setting : s.value if s.name == "containerInsights"]) == "disabled"
    error_message = "Container Insights must be off."
  }

  assert {
    condition     = aws_ecs_cluster_capacity_providers.this.capacity_providers == toset(["FARGATE", "FARGATE_SPOT"])
    error_message = "The capacity providers must be exactly FARGATE and FARGATE_SPOT."
  }

  assert {
    condition     = one(aws_ecs_cluster_capacity_providers.this.default_capacity_provider_strategy).capacity_provider == "FARGATE" && one(aws_ecs_cluster_capacity_providers.this.default_capacity_provider_strategy).weight == 1
    error_message = "The default strategy must be FARGATE with weight 1."
  }
}

run "rejects_bad_name" {
  command = plan

  variables {
    name = "Bad_Name"
  }

  expect_failures = [var.name]
}
