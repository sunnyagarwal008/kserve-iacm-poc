# Candidate path from the PRD: raw YAML + server-side apply, no typed CRD schema at plan.
# Record whether plan succeeds with offline_plan=true (no cluster).

resource "kubectl_manifest" "namespace" {
  yaml_body = templatefile("${path.module}/../manifests/namespace.yaml", {
    namespace = var.namespace
  })

  server_side_apply = true
  field_manager     = "iacm-kserve-poc"
  force_conflicts   = false
  wait              = false
}

resource "kubectl_manifest" "sklearn_iris" {
  yaml_body = templatefile("${path.module}/../manifests/sklearn-iris.yaml", {
    namespace = var.namespace
  })

  depends_on = [kubectl_manifest.namespace]

  server_side_apply = true
  field_manager     = "iacm-kserve-poc"
  force_conflicts   = false
  wait              = false
  wait_for_rollout  = false
}
