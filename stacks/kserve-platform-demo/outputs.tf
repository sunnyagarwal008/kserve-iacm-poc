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

output "ingress_class_name" {
  description = "IngressClass KServe uses for InferenceService Ingresses."
  value       = module.kserve_platform.ingress_class_name
}

output "ingress_domain" {
  description = "DNS suffix for InferenceService hostnames."
  value       = module.kserve_platform.ingress_domain
}

output "ingress_load_balancer_ip" {
  description = "Public IP of the KServe ingress controller."
  value       = module.kserve_platform.ingress_load_balancer_ip
}
