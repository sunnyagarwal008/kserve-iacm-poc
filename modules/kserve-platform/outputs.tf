output "namespace" {
  description = "Namespace containing the KServe control plane."
  value       = var.namespace
}

output "kserve_version" {
  description = "Installed KServe chart version."
  value       = var.kserve_version
}

output "inference_service_crd" {
  description = "CRD expected after a successful platform apply."
  value       = "inferenceservices.serving.kserve.io"
}
