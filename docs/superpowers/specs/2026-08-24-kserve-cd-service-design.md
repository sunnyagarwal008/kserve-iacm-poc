# KServe model as a Harness CD service (parallel twin)

**Date:** 2026-08-24  
**Status:** Draft for review  
**Related:** `kserve-iacm-poc-plan.md` (IaCM serve loop remains the CXO thesis)

## Problem

The live model is an IaCM workspace (`qwen25_05b`) that applies a KServe `InferenceService`. A colleague asked whether that object is really a **CD service**. We need a side-by-side demo in project `Model_Deployment` that deploys the **same model contract** through CD, including OPA, without replacing or fighting the IaCM workspace.

## Decision

Keep platform and the existing serve workspace on IaCM. Add a **twin** Kubernetes CD service that applies a second InferenceService (`qwen25-05b-cd`) on the same cluster/namespace, with a **Custom OPA Policy step** on the manifest before apply.

Do **not** use Helm for the twin. Do **not** wrap the IaCM pipeline as fake CD.

## Goals

1. A Harness CD Service + Environment + Infrastructure + Pipeline in `Model_Deployment` that deploys `qwen25-05b-cd`.
2. Same model URI, replica bounds, CPU/memory, and team/cost-center labels as the IaCM twin.
3. OPA denies the same class of bad deploys (allowlist, max replicas, GPU ceiling, required tags) **on the YAML**, then a human approval, then Kubernetes Apply.
4. Public hostname does not collide with IaCM (`qwen25-05b-cd.<ingress_domain>`).
5. IaCM `qwen25_05b` and `model-deploy` keep working unchanged.

## Non-goals

- Retiring the serve workspace.
- Cost-on-plan for CD (still IaCM M2).
- Field-scoped drift detection for CD (still IaCM M3).
- Promotion across a second cluster/environment.
- Canary / traffic split.
- Changing `kserve-platform` or the module registry sources.

## Architecture

```
Git main
  stacks/...                  IaCM (unchanged)
  cd/qwen25-05b/
    inferenceservice.yaml     CD twin manifest
  policies/
    kserve-serve-plan.rego    IaCM (unchanged)
    kserve-serve-manifest.rego  CD Custom OPA

Model_Deployment
  IaCM: kserve_platform, qwen25_05b
  CD:   service qwen2505bcd
        env kservestaging
        infra kservem0  (iacteamstandard, ns kserve-m0)
        pipeline model-cd-deploy
        policy set kserve-serve-manifest (Custom, Error)
```

**Apply owners**

| Owner | Resource name | Field manager |
|---|---|---|
| IaCM `kubectl_manifest` | `qwen25-05b` | `iacm-kserve-poc` |
| CD Kubernetes Apply | `qwen25-05b-cd` | Harness CD default |

Two CRs, one namespace, one ingress class. No shared field manager.

## Manifest contract

File: `cd/qwen25-05b/inferenceservice.yaml`

Fields that must match the IaCM module defaults (except name and `managed-by`):

- `metadata.name`: `qwen25-05b-cd`
- `metadata.namespace`: `kserve-m0`
- `metadata.labels`: `app.kubernetes.io/part-of=kserve-iacm-poc`, `app.kubernetes.io/managed-by=harness-cd`, `team=ml-platform`, `cost_center=kserve-poc`
- `metadata.annotations["kserve.poc/gpu-count"]`: `"0"` (policy-visible; not scheduled as `nvidia.com/gpu`)
- `metadata.annotations["kserve.poc/gpu-type"]`: `l4`
- `spec.predictor.minReplicas` / `maxReplicas`: `1`
- Hugging Face model, `--backend=huggingface`, `storageUri: hf://Qwen/Qwen2.5-0.5B-Instruct`
- CPU/memory requests/limits: `2`/`4`, `8Gi`/`12Gi`

KServe Standard + nginx IngressClass `kserve` already forms the host as `<name>-<namespace>.<ingress_domain>`. CD does not set Ingress; platform owns that.

## CD objects (Harness)

All project-scoped in org `default`, project `Model_Deployment`. Reuse connectors `sunnygithub` and `iacteamstandard`.

**Service `qwen2505bcd`**

- Type: Kubernetes
- Manifest: GitHub, connector `sunnygithub`, repo `sunnyagarwal008/kserve-iacm-poc`, branch `main`, path `cd/qwen25-05b`

**Environment `kservestaging`**

- Type: PreProduction
- One infra definition `kservem0`: Kubernetes Direct, connector `iacteamstandard`, namespace `kserve-m0`, release name `qwen2505bcd-<+INFRA_KEY_SHORT_ID>`

**Pipeline `model-cd-deploy`**

Deployment stage using that service/env/infra:

1. Kubernetes / Fetch manifests (or implicit with Apply)
2. **Policy** step: type `Custom`, policy set `kserve-serve-manifest`, payload = the InferenceService document (JSON). Enforcement **Error** (deny fails the pipeline).
3. **HarnessApproval**: same gate as `model-deploy` (`_project_all_users`, include history).
4. Kubernetes **Apply** of the InferenceService (not Rolling — the object is not a Deployment). Skip steady-state check so KServe's long model pull does not time out the step.
5. Optional HTTP verify: `GET` against `http://qwen25-05b-cd-kserve-m0.<ingress_domain>/v1/models` — **warn-only** if the model is still loading; do not block first apply on cold start.

Ingress domain is a pipeline variable defaulted from the current platform LB (`<lb-ip>.sslip.io`), documented in the pipeline YAML, not hardcoded as a secret.

## OPA (CD)

New file `policies/kserve-serve-manifest.rego`, package `custom` (Harness Custom Policy step).

Input is a single Kubernetes object (or `{ "manifest": { ... } }` if the Policy step wraps it — the implementation plan must pin the payload shape with a fixture from a dry-run Policy step).

**deny** when:

1. `kind != "InferenceService"` (wrong payload).
2. `storageUri` missing or not in `{ "hf://Qwen/Qwen2.5-0.5B-Instruct" }` (same allowlist as IaCM).
3. `maxReplicas` missing or `< 1`.
4. annotation `kserve.poc/gpu-count` present and numeric value `> 4`.
5. label `team` or `cost_center` missing or empty.

Unit tests in `policies/kserve-serve-manifest_test.rego` using `opa test` with fixtures for allow, bad URI, maxReplicas 0, gpu 8, missing team.

Policy set `kserve-serve-manifest`: type Custom, linked only to the Policy step (not account-wide on every pipeline).

IaCM policy set on terraform plan is **unchanged**.

## Data flow

1. Engineer edits `cd/qwen25-05b/inferenceservice.yaml` (or pipeline var for verify URL).
2. `model-cd-deploy` runs on the `model-deployment-delegate` in `kserve-m0`.
3. OPA evaluates the fetched manifest. Deny → pipeline fails before approval.
4. Approval → Apply → KServe reconciles `qwen25-05b-cd`.
5. IaCM workspace `qwen25_05b` is not in this graph.

## Failure modes

- **OPA deny:** expected for bad YAML; no cluster write.
- **Apply conflict with IaCM:** must not happen if names differ. If someone names the CD CR `qwen25-05b`, that is a bug — policy may optionally deny `metadata.name == "qwen25-05b"` to protect the IaCM object.
- **Ingress 404:** platform not applied, or wrong domain variable.
- **Model pull delay:** verify step must not be a hard gate on first deploy.

## Testing

- `opa test policies/` covers both plan and manifest policies.
- Manifest YAML is valid `InferenceService` (kubeconform or `kubectl apply --dry-run=server` from a machine with cluster access, if available).
- One successful `model-cd-deploy` in QA; `kubectl get inferenceservice -n kserve-m0` shows **both** `qwen25-05b` and `qwen25-05b-cd`.
- A deliberate bad `storageUri` on a branch or a pipeline input fails at the Policy step.

## Success criteria

A reviewer can open IaCM `model-deploy` and CD `model-cd-deploy` in the same project and see: two services on the cluster, two OPA gates, two approval steps, one shared platform.
