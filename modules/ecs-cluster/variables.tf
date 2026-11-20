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

variable "min_size" {
  description = "Fewest container instances. 0 lets ECS stop every instance when no task needs one."
  type        = number
  default     = 1

  validation {
    condition     = var.min_size >= 0
    error_message = "min_size must not be negative."
  }
}

variable "max_size" {
  description = "Most container instances ECS may scale out to. Caps the EC2 cost."
  type        = number
  default     = 2

  validation {
    condition     = var.max_size >= 1 && var.max_size <= 10 && var.max_size >= var.min_size
    error_message = "max_size must be between 1 and 10 and at least min_size."
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
