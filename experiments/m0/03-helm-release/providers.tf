provider "helm" {
  kubernetes {
    host                   = var.offline_plan ? "https://127.0.0.1:1" : null
    token                  = var.offline_plan ? "offline-plan-no-cluster" : null
    cluster_ca_certificate = var.offline_plan ? "offline" : null
    insecure               = var.offline_plan ? true : null
  }
}
