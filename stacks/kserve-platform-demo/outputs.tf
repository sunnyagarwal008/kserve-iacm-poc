output "namespace" {
  description = "Namespace containing the KServe control plane."
  value       = module.kserve_platform.namespace
}

output "kserve_version" {
  description = "Installed KServe chart version."
  value       = module.kserve_platform.kserve_version
}

output "inference_service_crd" {
  description = "CRD expected after the install workspace applies."
  value       = module.kserve_platform.inference_service_crd
}
