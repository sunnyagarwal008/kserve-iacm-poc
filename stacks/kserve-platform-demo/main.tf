module "kserve_platform" {
  source  = "qa.harness.io/25NKDX79QPC-YTyninmxRQu5st9wY_RziJH_pTw8_p2g/kserve-platform/kubernetes"
  version = "v1.0.0"

  kserve_version = var.kserve_version
  namespace      = var.namespace
  ingress_domain = var.ingress_domain
}
