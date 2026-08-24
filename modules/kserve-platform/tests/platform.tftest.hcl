mock_provider "helm" {}
mock_provider "kubernetes" {}

run "plans_standard_mode_install" {
  command = plan

  variables {
    ingress_domain = "kserve.test"
  }

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

  assert {
    condition = one([
      for setting in helm_release.kserve_runtime_configs.set :
      setting.value if setting.name == "kserve.servingruntime.enabled"
    ]) == "true"
    error_message = "Built-in model runtimes must be enabled explicitly."
  }

  assert {
    condition = alltrue([
      helm_release.ingress_nginx.upgrade_install,
      helm_release.kserve_crd.upgrade_install,
      helm_release.kserve_resources.upgrade_install,
      helm_release.kserve_runtime_configs.upgrade_install,
    ])
    error_message = "Helm releases must upgrade-install so an existing cluster release does not fail apply."
  }

  assert {
    condition     = helm_release.ingress_nginx.chart == "ingress-nginx"
    error_message = "The platform must install a dedicated ingress controller for KServe."
  }

  assert {
    condition = one([
      for setting in helm_release.ingress_nginx.set :
      setting.value if setting.name == "controller.ingressClassResource.name"
    ]) == "kserve"
    error_message = "The ingress controller must expose a dedicated kserve IngressClass."
  }

  assert {
    condition = one([
      for setting in helm_release.kserve_resources.set :
      setting.value if setting.name == "kserve.controller.gateway.ingressGateway.className"
    ]) == "kserve"
    error_message = "KServe must create Ingresses for the dedicated kserve class, not Istio."
  }

  assert {
    condition = one([
      for setting in helm_release.kserve_resources.set :
      setting.value if setting.name == "kserve.controller.gateway.domain"
    ]) == "kserve.test"
    error_message = "KServe ingress domain must come from the platform workspace."
  }

  assert {
    condition = one([
      for setting in helm_release.kserve_resources.set :
      setting.value if setting.name == "kserve.controller.gateway.disableIngressCreation"
    ]) == "false"
    error_message = "KServe must create Ingress resources for InferenceServices."
  }

  assert {
    condition = one([
      for setting in helm_release.kserve_resources.set :
      setting.value if setting.name == "kserve.controller.gateway.disableIstioVirtualHost"
    ]) == "true"
    error_message = "Standard-mode ingress must not depend on Istio VirtualServices."
  }
}
