variable "name" {
  type        = string
  description = "InferenceService name (also the public hostname prefix)."
  default     = "qwen25-05b"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.name))
    error_message = "name must be a valid DNS label."
  }
}

variable "namespace" {
  type        = string
  description = "Namespace the IaCM runner can write InferenceServices into."
  default     = "kserve-m0"
}

variable "model_uri" {
  type        = string
  description = "Model URI. Hugging Face Hub uses the hf:// scheme."
  default     = "hf://Qwen/Qwen2.5-0.5B-Instruct"
}

variable "ingress_domain" {
  type        = string
  description = "Public DNS suffix from the install workspace (e.g. <lb-ip>.sslip.io)."
  default     = ""
}

variable "min_replicas" {
  type        = number
  description = "Lower replica bound owned by IaCM. The autoscaler owns the live count within bounds."
  default     = 1

  validation {
    condition     = var.min_replicas >= 0 && (var.min_replicas > 0 || var.scale_to_zero_supported)
    error_message = "min_replicas = 0 requires a deployment mode that supports scale-to-zero."
  }
}

variable "max_replicas" {
  type        = number
  description = "Upper replica bound owned by IaCM."
  default     = 1

  validation {
    condition     = var.max_replicas >= var.min_replicas
    error_message = "max_replicas must be >= min_replicas."
  }
}

variable "scale_to_zero_supported" {
  type        = bool
  description = "Standard mode without Knative does not scale to zero."
  default     = false
}

variable "gpu_count" {
  type        = number
  description = "Declared GPU count for cost/policy. Not applied as nvidia.com/gpu on this CPU cluster."
  default     = 0
}

variable "gpu_type" {
  type        = string
  description = "Declared GPU SKU for cost on the plan. Not provisioned by this module."
  default     = "l4"
}

variable "tensor_parallel_size" {
  type        = number
  description = "Tensor parallel width. Must divide gpu_count when GPUs are declared."
  default     = 1

  validation {
    condition     = var.gpu_count == 0 || (var.tensor_parallel_size > 0 && var.gpu_count % var.tensor_parallel_size == 0)
    error_message = "tensor_parallel_size must divide gpu_count."
  }
}

variable "cpu_request" {
  type        = string
  default     = "2"
}

variable "cpu_limit" {
  type        = string
  default     = "4"
}

variable "memory_request" {
  type        = string
  default     = "8Gi"
}

variable "memory_limit" {
  type        = string
  default     = "12Gi"
}

variable "team" {
  type        = string
  default     = "ml-platform"
}

variable "cost_center" {
  type        = string
  default     = "kserve-poc"
}

variable "offline_plan" {
  type        = bool
  description = "When true, kubectl talks to a dead API host so plan does not need a cluster."
  default     = false
}
