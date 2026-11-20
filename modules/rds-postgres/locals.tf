locals {
  major_version = split(".", var.engine_version)[0]
  log_exports   = ["postgresql", "upgrade"]
}
