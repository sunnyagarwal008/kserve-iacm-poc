variable "offline_plan" {
  type        = bool
  description = "When true, point Helm at a dead API so plan cannot reach a cluster."
  default     = false
}

variable "namespace" {
  type        = string
  description = "Namespace for the InferenceService."
  default     = "kserve-demo"
}
