# Offline plan: dummy host, no kubeconfig.
# Apply on KubernetesDirect: in-cluster SA (KUBERNETES_SERVICE_HOST + mounted token).
provider "kubectl" {
  load_config_file  = false
  host              = var.offline_plan ? "https://127.0.0.1:1" : null
  token             = var.offline_plan ? "offline-plan-no-cluster" : null
  insecure          = var.offline_plan ? true : null
  apply_retry_count = 3
}
