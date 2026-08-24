output "endpoint_url" {
  description = "Public URL for the Qwen InferenceService."
  value       = module.serve.endpoint_url
}

output "predictor_url" {
  value = module.serve.predictor_url
}

output "gpu_type" {
  value = module.serve.gpu_type
}

output "gpu_count" {
  value = module.serve.gpu_count
}

output "model_uri" {
  value = module.serve.model_uri
}
