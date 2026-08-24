# kserve-llm-inference-service

Applies a KServe `InferenceService` for a Hugging Face LLM.

This is the per-model serve module. The KServe control plane and ingress come
from `kserve-platform`.

## What it creates

- One `InferenceService` (`serving.kserve.io/v1beta1`) via server-side apply
- Hugging Face backend (`--backend=huggingface`)
- Public URL `http://<name>-<namespace>.<ingress_domain>`

`gpu_count` / `gpu_type` are declared for cost and OPA only. This module does
not request `nvidia.com/gpu`.

## Usage

```hcl
module "serve" {
  source  = "app.harness.io/<account_id>/kserve-llm-inference-service/kubernetes"
  version = "1.0.0"

  name           = "qwen25-05b"
  namespace      = "kserve-m0"
  model_uri      = "hf://Qwen/Qwen2.5-0.5B-Instruct"
  ingress_domain = "8.231.51.197.sslip.io"
  min_replicas   = 1
  max_replicas   = 1
  team           = "ml-platform"
  cost_center    = "kserve-poc"
}
```

On Harness QA, replace `app.harness.io` with `qa.harness.io`.

## Inputs

| Name | Description | Default |
|---|---|---|
| `name` | InferenceService name and hostname prefix | `qwen25-05b` |
| `namespace` | Namespace the runner can write | `kserve-m0` |
| `model_uri` | Hugging Face URI (`hf://...`) | `hf://Qwen/Qwen2.5-0.5B-Instruct` |
| `ingress_domain` | DNS suffix from the platform workspace | `""` |
| `min_replicas` / `max_replicas` | Replica bounds | `1` / `1` |
| `gpu_count` / `gpu_type` | Declared GPU intent for policy/cost | `0` / `l4` |
| `cpu_request` / `cpu_limit` | Predictor CPU | `2` / `4` |
| `memory_request` / `memory_limit` | Predictor memory | `8Gi` / `12Gi` |
| `team` / `cost_center` | Required labels | `ml-platform` / `kserve-poc` |

## Outputs

| Name | Description |
|---|---|
| `endpoint_url` | Public InferenceService URL |
| `predictor_url` | In-cluster predictor Service URL |
| `inference_service_name` | Kubernetes name |
| `inference_service_namespace` | Namespace |
| `model_uri` | Declared model URI |
| `gpu_type` / `gpu_count` | Declared GPU intent |

## Requirements

- OpenTofu `>= 1.6.0`
- Provider: `alekc/kubectl ~> 2.1`
- KServe CRDs from `kserve-platform` already installed
- Serve OPA allowlist must include `model_uri` before apply
