variable "name" {
  description = "Name prefix for every resource, for example `mdb-dev`."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name))
    error_message = "name must contain only lowercase letters, digits and hyphens."
  }
}

variable "cidr_block" {
  description = "IPv4 CIDR of the VPC. Must be a /16, which the module splits into subnets."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.cidr_block)) && endswith(var.cidr_block, "/16")
    error_message = "cidr_block must be a valid IPv4 /16, for example 10.10.0.0/16."
  }
}

variable "az_count" {
  description = "Number of availability zones to spread subnets across."
  type        = number
  default     = 2

  # Load balancers and RDS subnet groups need at least two AZs.
  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

# No default NAT: it costs money per hour, so callers opt in explicitly.
variable "nat_mode" {
  description = "Internet egress for private subnets: `none`, or `single` (one NAT gateway in the first AZ)."
  type        = string
  default     = "none"

  validation {
    condition     = contains(["none", "single"], var.nat_mode)
    error_message = "nat_mode must be none or single."
  }
}

variable "tags" {
  description = "Extra tags for every resource, merged on top of the provider's default_tags."
  type        = map(string)
  default     = {}
}
