provider "kubectl" {
  load_config_file  = var.offline_plan ? false : true
  host              = var.offline_plan ? "https://127.0.0.1:1" : null
  token             = var.offline_plan ? "offline-plan-no-cluster" : null
  insecure          = var.offline_plan ? true : null
  apply_retry_count = 3
}
