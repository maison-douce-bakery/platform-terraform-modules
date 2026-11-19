variable "name" {
  description = "Cluster name, also the prefix for every resource, for example `mdb-dev`."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{1,40}$", var.name))
    error_message = "name must be 1-40 lowercase letters, digits or hyphens."
  }
}

variable "vpc_id" {
  description = "VPC for the instances' security group."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets for the instances. They need egress (NAT) to reach ECS, ECR and SSM."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "subnet_ids must not be empty."
  }
}

# Pinned by the caller and bumped by PR, so a new AWS AMI never shows up as drift.
variable "ami_id" {
  description = "ECS-optimized AMI ID, from /aws/service/ecs/optimized-ami/amazon-linux-2023[/arm64]/recommended/image_id."
  type        = string

  validation {
    condition     = can(regex("^ami-[0-9a-f]{8,17}$", var.ami_id))
    error_message = "ami_id must look like ami-0123456789abcdef0."
  }
}

variable "instance_type" {
  description = "EC2 instance type. Its architecture must match the AMI."
  type        = string
  default     = "t4g.micro"
}

variable "instance_count" {
  description = "Fixed number of container instances. 0 stops all of them."
  type        = number
  default     = 1

  validation {
    condition     = var.instance_count >= 0 && var.instance_count <= 10
    error_message = "instance_count must be between 0 and 10."
  }
}

variable "permissions_boundary_arn" {
  description = "Permissions boundary for the instance role. Required by the account's CI roles."
  type        = string
}

variable "tags" {
  description = "Extra tags for every resource, merged on top of the provider's default_tags."
  type        = map(string)
  default     = {}
}
