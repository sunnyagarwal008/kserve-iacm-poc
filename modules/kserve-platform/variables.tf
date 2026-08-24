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
