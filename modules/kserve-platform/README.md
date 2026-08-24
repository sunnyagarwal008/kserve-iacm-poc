# kserve-platform

Installs KServe in Standard mode plus a dedicated nginx ingress controller.

This is the install-once module. Model `InferenceService` resources belong in
`kserve-llm-inference-service`.

## What it creates

- `ingress-nginx` Helm release with IngressClass `kserve`
- `kserve-crd`, `kserve-resources`, and `kserve-runtime-configs` Helm releases
- Ingress hostnames of the form `<name>-<namespace>.<ingress_domain>`

Helm releases use `upgrade_install = true` so an existing release on the cluster
is adopted instead of failing create.

## Usage

```hcl
module "kserve_platform" {
  source  = "app.harness.io/<account_id>/kserve-platform/kubernetes"
  version = "1.0.0"

  kserve_version = "v0.20.0"
  namespace      = "kserve"
  # ingress_domain = "8.231.51.197.sslip.io" # optional; defaults to <lb-ip>.sslip.io
}
```

On Harness QA, replace `app.harness.io` with `qa.harness.io`.

## Inputs

| Name | Description | Default |
|---|---|---|
| `kserve_version` | KServe Helm chart version (`vX.Y.Z`) | `v0.20.0` |
| `namespace` | Namespace for the KServe control plane | `kserve` |
| `ingress_class_name` | IngressClass name | `kserve` |
| `ingress_nginx_version` | ingress-nginx chart version | `4.12.3` |
| `ingress_domain` | Public DNS suffix. `null` uses `<load-balancer-ip>.sslip.io` | `null` |

## Outputs

| Name | Description |
|---|---|
| `namespace` | Control-plane namespace |
| `kserve_version` | Installed chart version |
| `inference_service_crd` | `inferenceservices.serving.kserve.io` |
| `ingress_class_name` | IngressClass used by InferenceServices |
| `ingress_domain` | DNS suffix for public URLs |
| `ingress_load_balancer_ip` | Ingress controller public IP |

## Requirements

- OpenTofu `>= 1.6.0`
- Providers: `hashicorp/helm ~> 2.17`, `hashicorp/kubernetes ~> 2.35`
- A cluster the IaCM runner can write Helm releases into
