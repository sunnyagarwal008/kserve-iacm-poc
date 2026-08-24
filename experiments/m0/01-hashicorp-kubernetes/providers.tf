# Empty config uses in-cluster SA when this runs as a pod on account.k8connnew.
# offline_plan=true is the M0 negative control: no live apiserver.
provider "kubernetes" {
  host                   = var.offline_plan ? "https://127.0.0.1:1" : null
  token                  = var.offline_plan ? "offline-plan-no-cluster" : null
  cluster_ca_certificate = var.offline_plan ? "offline" : null
  insecure               = var.offline_plan ? true : null
}
