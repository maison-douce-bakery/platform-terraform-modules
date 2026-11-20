variable "name" {
  description = "DB instance identifier and resource prefix, for example `mdb-dev`."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,49}$", var.name))
    error_message = "name must start with a letter and use 1-50 lowercase letters, digits or hyphens."
  }
}

variable "vpc_id" {
  description = "VPC for the security group."
  type        = string
}

variable "subnet_ids" {
  description = "Database subnets (no internet route) in at least two AZs."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "subnet_ids needs at least two subnets in different AZs."
  }
}

variable "instance_class" {
  description = "DB instance class, for example db.t4g.micro."
  type        = string
}

# No default: a standby doubles the instance cost, so every caller chooses.
variable "multi_az" {
  description = "Run a synchronous standby in a second AZ."
  type        = bool
}

variable "engine_version" {
  description = "PostgreSQL major version (minor upgrades are automatic) or an exact version."
  type        = string
  default     = "18"

  validation {
    condition     = can(regex("^[0-9]+(\\.[0-9]+)?$", var.engine_version))
    error_message = "engine_version must look like 18 or 18.6."
  }
}

variable "allocated_storage" {
  description = "Initial gp3 storage in GiB."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Upper limit for storage autoscaling in GiB."
  type        = number
  default     = 100

  validation {
    condition     = var.max_allocated_storage >= var.allocated_storage
    error_message = "max_allocated_storage must be at least allocated_storage."
  }
}

variable "backup_retention_days" {
  description = "Days of automated backups (1-35)."
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be between 1 and 35."
  }
}

variable "log_retention_days" {
  description = "Retention of the exported PostgreSQL logs in CloudWatch."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Extra tags for every resource, merged on top of the provider's default_tags."
  type        = map(string)
  default     = {}
}
