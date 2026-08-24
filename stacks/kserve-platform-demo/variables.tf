variable "kserve_version" {
  type        = string
  description = "KServe Helm chart version installed by the platform workspace."
  default     = "v0.20.0"
}

variable "namespace" {
  type        = string
  description = "Namespace for the KServe control plane."
  default     = "kserve"
}

variable "ingress_domain" {
  type        = string
  default     = null
  nullable    = true
  description = "Public DNS suffix for InferenceService URLs. When null, uses <load-balancer-ip>.sslip.io."
}
