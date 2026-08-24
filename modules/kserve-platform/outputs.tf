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

output "ingress_class_name" {
  description = "IngressClass KServe uses for InferenceService Ingresses."
  value       = var.ingress_class_name
}

output "ingress_domain" {
  description = "DNS suffix for InferenceService hostnames."
  value       = local.ingress_domain
}

output "ingress_load_balancer_ip" {
  description = "Public IP of the KServe ingress controller, if provisioned."
  value       = local.ingress_load_balancer_ip
}
