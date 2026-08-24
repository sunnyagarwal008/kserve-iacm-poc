module "serve" {
  source = "../../modules/kserve-llm-inference-service"

  name            = var.name
  namespace       = var.namespace
  model_uri       = var.model_uri
  ingress_domain  = var.ingress_domain
  min_replicas    = var.min_replicas
  max_replicas    = var.max_replicas
  gpu_count       = var.gpu_count
  gpu_type        = var.gpu_type
}
