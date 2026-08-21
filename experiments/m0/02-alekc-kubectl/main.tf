# Candidate path from the PRD: raw YAML + server-side apply, no typed CRD schema at plan.
# Namespace is not managed: the IaCM step SA cannot patch cluster-scoped Namespace objects.

resource "kubectl_manifest" "sklearn_iris" {
  yaml_body = templatefile("${path.module}/../manifests/sklearn-iris.yaml", {
    namespace = var.namespace
  })

  server_side_apply = true
  field_manager     = "iacm-kserve-poc"
  force_conflicts   = false
  wait              = false
  wait_for_rollout  = false
}
