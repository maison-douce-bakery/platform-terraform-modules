# ECS registers the private IP of each running task as an A record and removes it when the task stops.
resource "aws_service_discovery_service" "this" {
  count = var.service_discovery == null ? 0 : 1

  name = var.service_discovery.name

  dns_config {
    namespace_id   = var.service_discovery.namespace_id
    routing_policy = "MULTIVALUE"

    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {}

  tags = var.tags
}
