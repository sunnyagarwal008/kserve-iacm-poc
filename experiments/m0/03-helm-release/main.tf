# Fallback arm. Helm plan commonly still talks to the cluster for capabilities/CRDs.
# Equal time is not the goal — only run this if both Kubernetes providers fail M0.

resource "helm_release" "sklearn_iris" {
  name             = "sklearn-iris"
  chart            = "${path.module}/chart"
  namespace        = var.namespace
  create_namespace = true
  wait             = false
  atomic           = false

  set {
    name  = "namespace"
    value = var.namespace
  }
}
