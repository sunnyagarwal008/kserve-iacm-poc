module "kserve_platform" {
  source = "../../modules/kserve-platform"

  kserve_version = var.kserve_version
  namespace      = var.namespace
}
