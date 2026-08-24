resource "helm_release" "kserve_crd" {
  name             = "kserve-crd"
  chart            = "oci://ghcr.io/kserve/charts/kserve-crd"
  version          = var.kserve_version
  namespace        = var.namespace
  create_namespace = true
  wait             = true
  timeout          = 600
}

resource "helm_release" "kserve_resources" {
  name       = "kserve-resources"
  chart      = "oci://ghcr.io/kserve/charts/kserve-resources"
  version    = var.kserve_version
  namespace  = var.namespace
  wait       = true
  timeout    = 900
  depends_on = [helm_release.kserve_crd]

  set {
    name  = "kserve.controller.deploymentMode"
    value = "Standard"
  }
}
