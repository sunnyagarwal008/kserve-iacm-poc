# Expected M0 result: plan FAILS with no cluster (OpenAPI/CRD discovery).
# This documents why kubernetes_manifest is not the offline-plan path.

resource "kubernetes_manifest" "namespace" {
  manifest = yamldecode(templatefile("${path.module}/../manifests/namespace.yaml", {
    namespace = var.namespace
  }))

  field_manager {
    name            = "iacm-kserve-poc"
    force_conflicts = false
  }
}

resource "kubernetes_manifest" "sklearn_iris" {
  manifest = yamldecode(templatefile("${path.module}/../manifests/sklearn-iris.yaml", {
    namespace = var.namespace
  }))

  field_manager {
    name            = "iacm-kserve-poc"
    force_conflicts = false
  }

  depends_on = [kubernetes_manifest.namespace]
}
