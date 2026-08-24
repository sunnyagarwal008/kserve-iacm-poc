mock_provider "kubectl" {}

run "plans_qwen_cpu_huggingface" {
  command = plan

  variables {
    name           = "qwen25-05b"
    namespace      = "kserve-m0"
    model_uri      = "hf://Qwen/Qwen2.5-0.5B-Instruct"
    ingress_domain = "34.0.0.1.sslip.io"
    min_replicas   = 1
    max_replicas   = 1
    gpu_count      = 0
    gpu_type       = "l4"
  }

  assert {
    condition     = local.inference_service.kind == "InferenceService"
    error_message = "Serve must apply a KServe InferenceService."
  }

  assert {
    condition     = local.inference_service.spec.predictor.model.modelFormat.name == "huggingface"
    error_message = "Qwen must use the Hugging Face model format."
  }

  assert {
    condition     = local.inference_service.spec.predictor.model.storageUri == "hf://Qwen/Qwen2.5-0.5B-Instruct"
    error_message = "The declared Hugging Face URI must be on the InferenceService."
  }

  assert {
    condition     = contains(local.inference_service.spec.predictor.model.args, "--backend=huggingface")
    error_message = "CPU serving must force the Hugging Face backend, not vLLM."
  }

  assert {
    condition     = !contains(keys(try(local.inference_service.spec.predictor.model.resources.limits, {})), "nvidia.com/gpu")
    error_message = "This cluster has no GPUs; the pod spec must not request nvidia.com/gpu."
  }

  assert {
    condition     = local.inference_service.spec.predictor.minReplicas == 1 && local.inference_service.spec.predictor.maxReplicas == 1
    error_message = "IaCM owns replica bounds, not the live replica count."
  }

  assert {
    condition     = output.endpoint_url == "http://qwen25-05b-kserve-m0.34.0.0.1.sslip.io"
    error_message = "The serve workspace must output a curl-able public URL from name, namespace, and ingress domain."
  }

  assert {
    condition     = output.gpu_type == "l4" && output.gpu_count == 0
    error_message = "Declared GPU intent must remain an output even when the demo runs on CPU."
  }

  assert {
    condition     = kubectl_manifest.inference_service.force_conflicts == true
    error_message = "Re-applying an existing InferenceService must take field ownership instead of failing."
  }
}

run "rejects_min_replicas_zero_without_scale_to_zero" {
  command = plan

  variables {
    name                    = "qwen25-05b"
    namespace               = "kserve-m0"
    model_uri               = "hf://Qwen/Qwen2.5-0.5B-Instruct"
    min_replicas            = 0
    scale_to_zero_supported = false
  }

  expect_failures = [var.min_replicas]
}

run "rejects_tensor_parallel_that_does_not_divide_gpus" {
  command = plan

  variables {
    name                 = "qwen25-05b"
    namespace            = "kserve-m0"
    model_uri            = "hf://Qwen/Qwen2.5-0.5B-Instruct"
    gpu_count            = 2
    tensor_parallel_size = 3
  }

  expect_failures = [var.tensor_parallel_size]
}
