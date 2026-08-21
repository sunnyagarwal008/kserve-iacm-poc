variable "offline_plan" {
  type        = bool
  description = "When true, skip kubeconfig and use a dead API host."
  default     = false
}

variable "namespace" {
  type        = string
  description = "Existing namespace the step service account can write to."
  default     = "harness-delegate-ng"
}
