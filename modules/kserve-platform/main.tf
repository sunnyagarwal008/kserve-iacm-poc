locals {
  ingress_controller_service = "kserve-ingress-nginx-controller"
  ingress_load_balancer_ip = try(
    data.kubernetes_service_v1.ingress_nginx[0].status[0].load_balancer[0].ingress[0].ip,
    null
  )
  ingress_domain = var.ingress_domain != null ? var.ingress_domain : (
    local.ingress_load_balancer_ip != null ? "${local.ingress_load_balancer_ip}.sslip.io" : null
  )
}

resource "helm_release" "ingress_nginx" {
  name             = "kserve-ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.ingress_nginx_version
  namespace        = var.namespace
  create_namespace = true
  wait             = true
  timeout          = 600

  set {
    name  = "fullnameOverride"
    value = "kserve-ingress-nginx"
  }

  set {
    name  = "controller.ingressClassResource.name"
    value = var.ingress_class_name
  }

  set {
    name  = "controller.ingressClassResource.controllerValue"
    value = "k8s.io/kserve-ingress-nginx"
  }

  set {
    name  = "controller.ingressClass"
    value = var.ingress_class_name
  }

  set {
    name  = "controller.ingressClassResource.enabled"
    value = "true"
  }

  set {
    name  = "controller.watchIngressWithoutClass"
    value = "false"
  }
}

data "kubernetes_service_v1" "ingress_nginx" {
  count = var.ingress_domain == null ? 1 : 0

  metadata {
    name      = local.ingress_controller_service
    namespace = var.namespace
  }

  depends_on = [helm_release.ingress_nginx]
}

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
  depends_on = [helm_release.kserve_crd, helm_release.ingress_nginx]

  set {
    name  = "kserve.controller.deploymentMode"
    value = "Standard"
  }

  set {
    name  = "kserve.controller.gateway.ingressGateway.className"
    value = var.ingress_class_name
  }

  set {
    name  = "kserve.controller.gateway.domain"
    value = local.ingress_domain
  }

  set {
    name  = "kserve.controller.gateway.disableIngressCreation"
    value = "false"
  }

  set {
    name  = "kserve.controller.gateway.disableIstioVirtualHost"
    value = "true"
  }

  lifecycle {
    precondition {
      condition     = local.ingress_domain != null
      error_message = "KServe ingress domain could not be resolved from ingress_domain or the ingress LoadBalancer IP."
    }
  }
}

resource "helm_release" "kserve_runtime_configs" {
  name       = "kserve-runtime-configs"
  chart      = "oci://ghcr.io/kserve/charts/kserve-runtime-configs"
  version    = var.kserve_version
  namespace  = var.namespace
  wait       = true
  timeout    = 600
  depends_on = [helm_release.kserve_resources]

  set {
    name  = "kserve.servingruntime.enabled"
    value = "true"
  }
}
