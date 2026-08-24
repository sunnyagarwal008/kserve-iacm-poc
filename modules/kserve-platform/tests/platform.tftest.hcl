mock_provider "helm" {}

run "plans_standard_mode_install" {
  command = plan

  assert {
    condition     = helm_release.kserve_crd.chart == "oci://ghcr.io/kserve/charts/kserve-crd"
    error_message = "The platform must install the official KServe CRD chart."
  }

  assert {
    condition     = helm_release.kserve_resources.chart == "oci://ghcr.io/kserve/charts/kserve-resources"
    error_message = "The platform must install the official KServe resources chart."
  }

  assert {
    condition     = helm_release.kserve_runtime_configs.chart == "oci://ghcr.io/kserve/charts/kserve-runtime-configs"
    error_message = "The platform must install KServe's built-in model runtimes."
  }

  assert {
    condition     = helm_release.kserve_crd.version == var.kserve_version && helm_release.kserve_resources.version == var.kserve_version && helm_release.kserve_runtime_configs.version == var.kserve_version
    error_message = "All KServe charts must use the selected KServe version."
  }

  assert {
    condition = one([
      for setting in helm_release.kserve_resources.set :
      setting.value if setting.name == "kserve.controller.deploymentMode"
    ]) == "Standard"
    error_message = "KServe must use Standard mode so the POC does not require Knative."
  }
}
