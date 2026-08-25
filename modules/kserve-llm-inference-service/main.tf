locals {
  inference_service = {
    apiVersion = "serving.kserve.io/v1beta1"
    kind       = "InferenceService"
    metadata = {
      name      = var.name
      namespace = var.namespace
      labels = {
        "app.kubernetes.io/part-of"    = "kserve-iacm-poc"
        "app.kubernetes.io/managed-by" = "iacm"
        team                           = var.team
        cost_center                    = var.cost_center
      }
    }
    spec = {
      predictor = {
        minReplicas = var.min_replicas
        maxReplicas = var.max_replicas
        model = {
          modelFormat = {
            name = var.model_format
          }
          args = [
            "--backend=${var.backend}",
          ]
          storageUri = var.model_uri
          resources = {
            requests = {
              cpu    = var.cpu_request
              memory = var.memory_request
            }
            limits = {
              cpu    = var.cpu_limit
              memory = var.memory_limit
            }
          }
        }
      }
    }
  }
}

resource "kubectl_manifest" "inference_service" {
  yaml_body = yamlencode(local.inference_service)

  server_side_apply = true
  field_manager     = "iacm-kserve-poc"
  force_conflicts   = true
  wait              = false
  wait_for_rollout  = false
}
