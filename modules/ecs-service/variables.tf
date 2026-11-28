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
  description = "Capacity provider that places the tasks: `FARGATE` or `FARGATE_SPOT`."
  type        = string
  default     = "FARGATE"
}

variable "vpc_id" {
  description = "VPC for the task security group."
  type        = string
}

variable "subnet_ids" {
  description = "Subnets for the task ENIs. Public subnets when assign_public_ip is true."
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

variable "assign_public_ip" {
  description = "Give each task a public IPv4 so it can reach the internet without a NAT. Inbound stays closed unless ingress_security_group_ids is set."
  type        = bool
  default     = false
}

variable "cpu" {
  description = "Task CPU units (1024 = 1 vCPU): 256, 512, 1024, 2048 or 4096."
  type        = number
  default     = 256
}

# Cross-variable validation needs Terraform 1.9. These are the Fargate cpu/memory combinations.
variable "memory" {
  description = "Task memory in MiB, a hard limit. Must be a valid Fargate size for cpu."
  type        = number
  default     = 512

  validation {
    condition = contains(lookup({
      "256"  = [512, 1024, 2048]
      "512"  = range(1024, 4097, 1024)
      "1024" = range(2048, 8193, 1024)
      "2048" = range(4096, 16385, 1024)
      "4096" = range(8192, 30721, 1024)
    }, tostring(var.cpu), []), var.memory)
    error_message = "cpu/memory is not a valid Fargate combination. cpu 256: 512, 1024 or 2048. 512: 1024-4096. 1024: 2048-8192. 2048: 4096-16384. 4096: 8192-30720 (memory in 1024 steps, except 256)."
  }
}

variable "container_port" {
  description = "Port the container listens on. Null for a container that listens on none: no port mapping and no ingress."
  type        = number
  default     = null
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

variable "ssm_secrets" {
  description = "Environment variables read from SSM Parameter Store (SecureString or String): name => parameter ARN. Injected at task start, the value never appears in the task definition or Terraform state."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for arn in values(var.ssm_secrets) : can(regex("^arn:aws[a-z-]*:ssm:[a-z0-9-]+:[0-9]{12}:parameter/.+$", arn))])
    error_message = "Every ssm_secrets value must be an SSM parameter ARN (arn:aws:ssm:<region>:<account>:parameter/...)."
  }

  # Cross-variable validation needs Terraform 1.9.
  validation {
    condition     = length(setintersection(keys(var.ssm_secrets), keys(var.secrets))) == 0
    error_message = "A name may be set in either secrets or ssm_secrets, not both."
  }
}

variable "secrets_kms_key_arns" {
  description = "Customer managed KMS keys that encrypt the secrets and SSM parameters, so the execution role can decrypt them. The AWS managed keys need no entry."
  type        = list(string)
  default     = []
}

variable "ingress_security_group_ids" {
  description = "Security groups allowed to reach the container port. Must be empty when container_port is null."
  type        = list(string)
  default     = []

  validation {
    condition     = var.container_port != null || length(var.ingress_security_group_ids) == 0
    error_message = "ingress_security_group_ids must be empty when container_port is null."
  }
}

variable "target_group_arn" {
  description = "ALB target group the service registers its tasks with. Null for a service without a load balancer."
  type        = string
  default     = null

  validation {
    condition     = var.target_group_arn == null || var.container_port != null
    error_message = "container_port must be set when target_group_arn is set."
  }
}

variable "health_check_grace_period_seconds" {
  description = "Seconds the service ignores failing load balancer health checks after a task starts. Used only with target_group_arn."
  type        = number
  default     = null
}

variable "service_discovery" {
  description = "Cloud Map registration: the private IPs of the tasks are published as A records named `<name>` in the namespace, so other services in the VPC find them. Null for none."
  type = object({
    namespace_id = string
    name         = string
  })
  default = null
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

# 0 and 100 stop the old task before the new one starts, for apps that allow only one running copy.
variable "deployment_minimum_healthy_percent" {
  description = "Lower limit of running tasks during a deployment, in percent of desired_count."
  type        = number
  default     = 100

  validation {
    condition     = var.deployment_minimum_healthy_percent >= 0 && var.deployment_minimum_healthy_percent <= 100
    error_message = "deployment_minimum_healthy_percent must be between 0 and 100."
  }
}

variable "deployment_maximum_percent" {
  description = "Upper limit of running tasks during a deployment, in percent of desired_count."
  type        = number
  default     = 200

  validation {
    condition     = var.deployment_maximum_percent >= 100 && var.deployment_maximum_percent <= 200
    error_message = "deployment_maximum_percent must be between 100 and 200."
  }
}

variable "efs_volumes" {
  description = "EFS volumes to mount, by volume name. Mounted over TLS through the access point, authorized by the task role."
  type = map(object({
    file_system_id  = string
    access_point_id = string
    container_path  = string
    read_only       = optional(bool, false)
  }))
  default = {}
}

variable "enable_execute_command" {
  description = "Allow ECS Exec (SSM sessions and port forwarding) into the tasks."
  type        = bool
  default     = false
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
