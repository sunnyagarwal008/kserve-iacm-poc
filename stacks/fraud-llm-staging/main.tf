module "serve" {
  source  = "qa.harness.io/25NKDX79QPC-YTyninmxRQ/kserve-llm-inference-service/kubernetes"
  version = "v1.1.0"

  name            = var.name
  namespace       = var.namespace
  model_uri       = var.model_uri
  model_format    = var.model_format
  backend         = var.backend
  ingress_domain  = var.ingress_domain
  min_replicas    = var.min_replicas
  max_replicas    = var.max_replicas
  gpu_count       = var.gpu_count
  gpu_type        = var.gpu_type
  team            = var.team
  cost_center     = var.cost_center
}
