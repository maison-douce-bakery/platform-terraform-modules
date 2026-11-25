variable "name" {
  description = "Cluster name, also the prefix for every resource, for example `mdb-dev`."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{1,40}$", var.name))
    error_message = "name must be 1-40 lowercase letters, digits or hyphens."
  }
}

variable "tags" {
  description = "Extra tags for every resource, merged on top of the provider's default_tags."
  type        = map(string)
  default     = {}
}
