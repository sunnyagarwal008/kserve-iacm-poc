variable "offline_plan" {
  type        = bool
  description = "When true, skip kubeconfig and use a dead API host."
  default     = false
}

variable "namespace" {
  type        = string
  description = "Namespace for the InferenceService."
  default     = "kserve-demo"
}
