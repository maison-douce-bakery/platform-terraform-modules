variable "name" {
  description = "Service name, also the prefix for every resource, for example `mdb-dev-marmot`."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,39}$", var.name))
    error_message = "name must start with a letter and use 1-40 lowercase letters, digits or hyphens."
  }
}

variable "cluster_name" {
  description = "ECS cluster to run in."
  type        = string
}

variable "capacity_provider_name" {
  description = "Capacity provider that places the tasks."
  type        = string
}

variable "vpc_id" {
  description = "VPC for the task security group."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets for the task ENIs."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "subnet_ids must not be empty."
  }
}

# A digest makes every deployment reproducible; a moving tag could change what runs without a plan.
variable "image" {
  description = "Container image pinned by digest, for example `ghcr.io/org/app@sha256:...`."
  type        = string

  validation {
    condition     = can(regex("@sha256:[0-9a-f]{64}$", var.image))
    error_message = "image must be pinned by digest (@sha256:<64 hex>)."
  }
}

variable "cpu" {
  description = "Task CPU units (1024 = 1 vCPU)."
  type        = number
  default     = 256
}

variable "memory" {
  description = "Task memory in MiB, a hard limit."
  type        = number
  default     = 512
}

variable "container_port" {
  description = "Port the container listens on."
  type        = number
}

variable "command" {
  description = "Override the image's command. Null keeps the image default."
  type        = list(string)
  default     = null
}

variable "environment" {
  description = "Plain environment variables. Never put secrets here."
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Environment variables read from Secrets Manager at task start: name => secret ARN and optional JSON key."
  type = map(object({
    secret_arn = string
    json_key   = optional(string)
  }))
  default = {}
}

variable "secrets_kms_key_arns" {
  description = "Customer managed KMS keys that encrypt the secrets, so the execution role can decrypt them."
  type        = list(string)
  default     = []
}

variable "ingress_security_group_ids" {
  description = "Security groups allowed to reach the container port."
  type        = list(string)
  default     = []
}

variable "task_role_policy_json" {
  description = "IAM policy for the application's own AWS calls. Null gives the task no AWS permissions."
  type        = string
  default     = null
}

variable "desired_count" {
  description = "Number of tasks to keep running."
  type        = number
  default     = 1
}

variable "permissions_boundary_arn" {
  description = "Permissions boundary for the task and execution roles."
  type        = string
}

variable "log_retention_days" {
  description = "Retention of the container logs in CloudWatch."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Extra tags for every resource, merged on top of the provider's default_tags."
  type        = map(string)
  default     = {}
}
