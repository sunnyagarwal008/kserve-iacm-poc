variable "kserve_version" {
  type        = string
  description = "KServe Helm chart version."
  default     = "v0.20.0"

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+$", var.kserve_version))
    error_message = "kserve_version must be a semantic version prefixed with v."
  }
}

variable "namespace" {
  type        = string
  description = "Namespace where KServe control-plane resources are installed."
  default     = "kserve"
}

variable "ingress_class_name" {
  type        = string
  description = "IngressClass used by the dedicated KServe ingress controller."
  default     = "kserve"
}

variable "ingress_nginx_version" {
  type        = string
  description = "ingress-nginx Helm chart version."
  default     = "4.12.3"
}

variable "ingress_domain" {
  type        = string
  default     = null
  nullable    = true
  description = "Public DNS suffix for InferenceService URLs. When null, uses <load-balancer-ip>.sslip.io."
}
