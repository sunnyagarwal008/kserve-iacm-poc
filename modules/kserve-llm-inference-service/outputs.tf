output "endpoint_url" {
  description = "Public InferenceService URL from the install workspace ingress domain."
  value       = var.ingress_domain != "" ? "http://${var.name}-${var.namespace}.${var.ingress_domain}" : null
}

output "predictor_url" {
  description = "In-cluster predictor Service URL."
  value       = "http://${var.name}-predictor.${var.namespace}.svc.cluster.local"
}

output "inference_service_name" {
  description = "Kubernetes name of the InferenceService."
  value       = var.name
}

output "inference_service_namespace" {
  description = "Namespace of the InferenceService."
  value       = var.namespace
}

output "gpu_type" {
  description = "Declared GPU SKU for cost/policy. Not scheduled on the CPU demo cluster."
  value       = var.gpu_type
}

output "gpu_count" {
  description = "Declared GPU count for cost/policy."
  value       = var.gpu_count
}

output "model_uri" {
  description = "Declared model URI."
  value       = var.model_uri
}
