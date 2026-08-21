# M0 — Provider spike (IaCM)

Prove or kill: **offline `plan` + server-side apply** for a KServe `InferenceService`.

Harness: QA account `25NKDX79QPC-YTyninmxRQ`, org `default`, project `sunnyplayground`.
Cluster connector: **`account.k8connnew`** (InheritFromDelegate, selector `testiacmnew`, test SUCCESS). Existing project IaCM pipelines use Harness Cloud; Cloud does not inherit that connector's in-cluster kubeconfig. Apply therefore uses a Kubernetes-runtime IaCM stage on that connector.

## Protocol

Each stack is a separate OpenTofu root module. Drive `offline_plan` as a workspace Terraform variable.

| Run | Pipeline | `offline_plan` | What we record |
|-----|----------|----------------|----------------|
| A | `kservem0offlineplan` (Cloud) | `true` | Does `plan` succeed with no live apiserver? |
| B | `kservem0apply` (K8s on `account.k8connnew`) | `false` | Does `apply` with SSA succeed? |
| C | `kservem0apply` again | `false` | Re-plan after KServe defaults fields — empty diff? |

Do **A before B** on `01-hashicorp-kubernetes` (expected: A fails). Then A/B/C on `02-alekc-kubectl`. Only then `03-helm-release`.

## Stacks

- `01-hashicorp-kubernetes` — `kubernetes_manifest` (negative control)
- `02-alekc-kubectl` — `kubectl_manifest` + `server_side_apply` (PRD candidate)
- `03-helm-release` — fallback only

## Workspace path

One IaCM workspace per stack. `repository_path`:

- `experiments/m0/01-hashicorp-kubernetes`
- `experiments/m0/02-alekc-kubectl`
- `experiments/m0/03-helm-release`

Git connector in this project: `sunnygithub`. Push this repo, then create the workspaces (CLI cannot create workspaces today).
