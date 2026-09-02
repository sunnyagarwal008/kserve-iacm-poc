# AGENTS.md

## Project overview

Proof of concept: treat a KServe model as governed infrastructure on Harness QA.

There are two live paths on the same cluster and namespace (`kserve-m0`). They must not share an InferenceService name or field manager.

| Path | What applies | Resource name | Workspace / service |
|---|---|---|---|
| IaCM serve | OpenTofu module `kserve-llm-inference-service` | `qwen25-05b` | workspace `qwen25_05b` |
| CD twin | Kubernetes Apply of Git YAML | `qwen25-05b-cd` | service `qwen2505bcd` |

Platform install is a separate IaCM workspace (`kserve-platform-demo`). It owns KServe CRDs, controllers, and IngressClass `kserve`. Model CRs do not belong there.

GitHub remote is `sunnyagarwal008/kserve-iacm-poc`. The local folder name is `iac-model-hosting`.

## Harness scope

Live objects live on **QA**, not prod.

- Host: `qa.harness.io`
- Account: `25NKDX79QPC-YTyninmxRQ`
- Org: `default`
- Project: `Model_Deployment`
- Cluster connector: `iacteamstandard`
- Git connector: `sunnygithub`

Always pass `--profile qa` on the `harness` CLI. Confirm with `harness auth status --profile qa` before investigating. Do not use MCP or `gh` for Harness resources if the CLI has the command.

List/get only unless the user asked to create, update, execute, or merge.

## Build system

OpenTofu / Terraform roots. No Maven, npm, or Python package.

- **Format**: `terraform fmt -recursive` (or `tofu fmt -recursive`)
- **Validate a stack**: `cd stacks/<name> && terraform init && terraform validate`
- **Module tests**: `cd modules/<name> && terraform init && terraform test`
- IaCM runners use OpenTofu. Local `terraform` and `tofu` both exist; match provider constraints in `versions.tf`.

`terraform test` fails with "unknown provider" until `terraform init` has run in that module.

## Testing

- **OPA** (Rego is v0 syntax; OPA 1.19+ needs the flag): `opa test policies/ --v0-compatible`
- **CD manifest contract**: `python3 -m unittest cd/qwen25-05b/test_manifest.py`
- **Harness CD YAML ids**: `python3 -m unittest harness/cd/test_yaml_ids.py`
- **Both Python files**: `python3 -m unittest cd/qwen25-05b/test_manifest.py harness/cd/test_yaml_ids.py`
- **Serve module**: `cd modules/kserve-llm-inference-service && terraform init && terraform test`
- **Platform module**: `cd modules/kserve-platform && terraform init && terraform test`

CD tests need PyYAML (`pip3 install pyyaml`).

## Linting and formatting

- **Terraform format check**: `terraform fmt -check -recursive modules stacks`
- **Terraform format fix**: `terraform fmt -recursive modules stacks`
- **OPA**: `opa test policies/ --v0-compatible`
- **Auto-run on commit**: No git hooks

## Git workflow

- **Default branch**: `main`
- **Commit style**: Imperative sentence. No conventional-commit prefix. No Jira keys.
- **PRs**: Keep focused. Match existing module/stack/Harness YAML patterns.

Examples from this repo: `Add serve workspace for Qwen 2.5 0.5B on KServe.`

## DOs

- Keep IaCM `qwen25-05b` and CD `qwen25-05b-cd` as two CRs. Do not reuse the IaCM name in CD.
- Put model InferenceServices in `modules/kserve-llm-inference-service` or `cd/<model>/inferenceservice.yaml`. Not in the platform module.
- Pin stacks to IaCM registry module versions, not relative `../../modules/...`.
- Treat `gpu_count` / `gpu_type` as cost and OPA inputs. Do not add `nvidia.com/gpu` on this demo cluster.
- Run OPA and the Python contract tests when changing serve variables, CD YAML, or policies.
- Update the matching README when module inputs or Harness identifiers change.
- Use `alekc/kubectl` + server-side apply for serve. Hashicorp `kubernetes_manifest` was the M0 negative control (offline plan fails).

## DON'Ts

- Do not force-push `main`.
- Do not commit `.terraform/`, `.terraform.lock.hcl`, tfstate, or secrets.
- Do not install KServe from a serve stack or CD pipeline.
- Do not point CD Git store at a path other than `cd/<model>/inferenceservice.yaml` without updating `policies/kserve-serve-service.rego`.
- Do not expect Service On Save OPA to see `storageUri`, replicas, or labels from Git. Harness does not load that YAML on save. Model allowlist, replica caps, and GPU ceiling stay on IaCM `policies/kserve-serve-plan.rego`.
- Do not re-enable a Custom OPA step on `model-cd-deploy` without a JSON payload. `policies/kserve-serve-manifest.rego` is unused by the live CD pipeline.
- Do not scale-to-zero (`min_replicas = 0`) unless `scale_to_zero_supported` is true. Standard mode has no Knative.

## Commands to never run

- `git push --force origin main`
- `harness` create/update/execute/merge without an explicit user request
- `kubectl delete` of `qwen25-05b` or KServe CRDs while debugging CD
- `terraform apply` / `tofu apply` against the shared demo cluster unless the user asked

## Project structure

```
modules/kserve-platform/                 # Install-once: KServe Helm + ingress-nginx
modules/kserve-llm-inference-service/    # Per-model InferenceService (kubectl SSA)
stacks/kserve-platform-demo/             # IaCM root: workspace kserve-platform-demo
stacks/fraud-llm-staging/                # IaCM root: workspace qwen25_05b
cd/qwen25-05b/                           # CD twin manifest + unittest
policies/                                # OPA: plan, unused manifest rules, service-on-save
harness/pipelines/                       # IaCM + CD pipeline YAML
harness/cd/                              # Service, env, infra YAML + id tests
harness/policies/                        # Harness policy-set wrappers
harness/templates/                       # IaCM workspace template kservemodelworkspace
harness/connectors/                      # Git + K8s connector YAML
harness/delegates/                       # Delegate YAML
experiments/m0/                          # Provider spike (hashicorp vs alekc vs helm)
docs/superpowers/                        # CD twin spec/plan
kserve-iacm-poc-plan.md                  # Original IaCM POC plan
```

## Important folders

- `modules/kserve-platform` and `stacks/kserve-platform-demo`: platform install. Helm `upgrade_install = true` adopts existing releases.
- `modules/kserve-llm-inference-service` and `stacks/fraud-llm-staging`: serve contract. Replica bounds are `min_replicas` / `max_replicas`. KServe autoscaler owns the live count inside those bounds.
- `cd/qwen25-05b`: CD twin. Same model URI, replicas, CPU/memory, team/cost_center as the IaCM defaults. Different name and `app.kubernetes.io/managed-by=harness-cd`.
- `policies/`: `kserve-serve-plan.rego` (package `terraform_plan`) for IaCM; `kserve-serve-service.rego` (package `service`) for CD Service On Save; `kserve-serve-manifest.rego` kept if a Custom Policy step comes back.
- `harness/pipelines/model-deploy.yaml` (`modeldeploy`): IaCM init/plan/approve/apply. Runtime input `workspace` defaults to `qwen25_05b`.
- `harness/pipelines/model-cd-deploy.yaml` (`modelcddeploy`): approval then `K8sApply` with `skipSteadyStateCheck: true`, then Shell `publishendpoint` exporting constructed `endpoint_url`.
- `harness/templates/kserve-model-workspace.yaml`: new serve workspaces. Locked OpenTofu 1.11.2, git path `stacks/fraud-llm-staging`, namespace `kserve-m0`. Unlocked: name, model, backend, replicas, GPU declaration.

## Pipelines (identifiers)

| Identifier | Role |
|---|---|
| `platformdeploy` / `kserveplatforminstall` | Install KServe |
| `modeldeploy` / `kserveserveapply` | Serve workspace plan/apply |
| `modelcddeploy` | CD twin apply |
| `kservem0offlineplan` / `kservem0apply` | M0 provider spike |

## Adding a new model

**IaCM.** Copy the serve workspace from template `kservemodelworkspace`, or clone `stacks/fraud-llm-staging` inputs. Add the `model_uri` to `allowed_model_uris` in `policies/kserve-serve-plan.rego`. Do not change `kserve-platform` for a new model.

**CD twin.** Add `cd/<model>/inferenceservice.yaml` with a unique `metadata.name` (suffix `-cd`). Point a Kubernetes service Git path at that file. Keep connector `sunnygithub` and repo `kserve-iacm-poc`. Extend `cd/qwen25-05b/test_manifest.py` or add a sibling test.

## Language notes

This is not a Python/Go/Java app. Python is unittest-only. Terraform modules use `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `README.md`, and `tests/*.tftest.hcl`.

## Additional notes

Hostnames are `<name>-<namespace>.<ingress_domain>` from the platform ingress. CD does not create Ingress objects.

`experiments/m0` is historical. Do not treat it as the live serve path.

The early POC plan said CD would not `kubectl apply` the model. The CD twin was added later as a parallel demo. IaCM remains the CXO loop (plan, cost, policy, drift). CD is the side-by-side Kubernetes service story.
