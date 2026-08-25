variable "offline_plan" {
  type        = bool
  description = "When true, skip kubeconfig and use a dead API host."
  default     = false
}

variable "name" {
  type        = string
  default     = "qwen25-05b"
}

variable "namespace" {
  type        = string
  default     = "kserve-m0"
}

variable "model_uri" {
  type        = string
  default     = "hf://Qwen/Qwen2.5-0.5B-Instruct"
}

variable "model_format" {
  type        = string
  description = "KServe modelFormat.name."
  default     = "huggingface"
}

variable "backend" {
  type        = string
  description = "Predictor --backend argument."
  default     = "huggingface"
}

variable "ingress_domain" {
  type        = string
  description = "Public DNS suffix from kserve-platform-demo (typically <lb-ip>.sslip.io)."
  default     = "34.177.119.9.sslip.io"
}

variable "min_replicas" {
  type    = number
  default = 1
}

variable "max_replicas" {
  type    = number
  default = 1
}

variable "gpu_count" {
  type    = number
  default = 0
}

variable "gpu_type" {
  type    = string
  default = "l4"
}

variable "team" {
  type    = string
  default = "ml-platform"
}

variable "cost_center" {
  type    = string
  default = "kserve-poc"
}
