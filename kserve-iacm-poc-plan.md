# Implementation Plan — KServe on Harness IaCM (Proof of Concept)

**Goal of this plan:** get to a *working demo* that proves the core thesis — that a KServe model deployment can be driven as a governed IaCM workspace, with an offline plan, GPU cost on the PR, policy enforcement, an approval gate, and quiet drift detection.

**Audience:** CXOs evaluating **model deployments in Harness**. The object they should remember is the **serve** workspace (the model). The **install** workspace is the one-time platform story (“KServe itself is also infra”).

**Explicitly not in scope for the POC:** production hardening, multi-tenant scale, cluster / GPU node-pool provisioning (PRD Phase 3), a third “capacity” workspace, a CD deploy step that applies the `InferenceService` itself, and the intent layer (Phase 4). This plan covers a demo, not a shippable product.

**Status:** Draft for review
**Related:** PRD "Model Serving as Infrastructure — KServe on Harness IaCM"

---

## 0. Two workspaces (demo shape)

Exactly **two** IaCM workspaces. No GPU-provisioning workspace: GPU (or CPU-for-now) is **inputs and a cost line on the serve workspace**.

| Workspace | Persona | Cadence | Module | Job |
|---|---|---|---|---|
| **Install** (`kserve-platform-demo`) | Platform / ops | Once (or rare upgrades) | Slim `kserve-platform` | Install KServe (CRDs + controller; Helm is an acceptable implementation) onto the demo cluster |
| **Serve** (`fraud-llm-staging`) | ML engineer / the CXO loop | Every model change | `kserve-llm-inference-service` | Declare and govern one `InferenceService`: plan, cost, policy, approve, apply, drift |

Shared **variable set**: cluster connector (today: project `iacteamstandard` on GKE `iac-team-standard`, namespace `kserve-m0`) plus any registry creds. Serve **depends on** install having already applied; it does not install KServe.

CD stays **out of the product loop**: if we mention promotion, it is “a CD pipeline would trigger apply on a prod *serve* workspace.” IaCM owns the CR shape; CD does not `kubectl apply` the model.

---

## 1. What "done" means for the POC

A scripted demo we can run in front of a CXO / design partner.

**Once (show, don’t dwell):** apply (or point at an already-applied) **install** workspace so KServe is on the cluster.

**Then the seven-step serve loop:**

1. An ML engineer opens a PR that changes a **serve** workspace variable (e.g. raises `tensor_parallel_size`, or points `model_uri` at a larger model).
2. IaCM runs `init → plan` **with no live cluster connectivity** and produces a valid plan.
3. The plan shows a **GPU cost delta** ("$4.20/hr → $16.80/hr at peak") from declared `gpu_type` / replica bounds — even if the demo cluster is CPU-only today (static price table; say “same contract as GPU”).
4. An **OPA policy** denies a deliberately over-budget variant, and passes the compliant one.
5. A reviewer approves at the **plan → apply gate**, having seen cost and policy results.
6. `apply` uses **server-side apply**; KServe reconciles; the demo curls the live **endpoint URL** (a module output).
7. A benign controller mutation (autoscaler moves the replica count) produces **no drift alert**; a real change to an owned field (`model_uri`) produces a **P1 drift alert**.

If we can run those seven steps on the serve workspace (with install already done), the concept is proven. Everything else is productization.

---

## 2. The three bets, and why we sequence them this way

Phase 1 of the PRD rests on three unproven assumptions. The rest is standard IaCM composition (Module Registry, workspaces, variable sets, an OPA pack) that Harness already knows how to do. The POC exists to kill or confirm these three — in this order, because each depends on the one before it.

| # | Bet | If it fails | Cost to prove |
|---|---|---|---|
| 1 | **Offline plan + server-side apply for KServe CRDs** (PRD §6.2) | The whole value prop collapses to "Argo with extra steps" — no plan-on-PR | Low — a few days of spiking, no product around it |
| 2 | **GPU cost on the plan** (PRD §9) | The demo loses its headline moment | Medium — must derive GPU cost; CCM actuals need another team |
| 3 | **Field-scoped drift detection** (PRD §7) | Customers disable drift on day one; feature is dead weight | Medium–High — hardest engineering problem in the PRD |

**Why the provider goes first:** bets 2 and 3 both assume a working offline plan already exists. If bet 1 fails, nothing downstream matters. It is also the cheapest to test — you can spike it in isolation before writing a line of module or product code. Retire the foundational risk first.

The install workspace is **not** one of the three bets. It is the prerequisite so serve `apply` has CRDs. Keep it thin (upstream Helm / official install, not a multi-tenant platform product).

---

## 3. Milestones

### M0 — Spike: prove the provider (the make-or-break week)

**Question to answer:** can we produce a valid `plan` for a KServe `InferenceService` with **no live cluster reachable**, and `apply` it with server-side apply without fighting KServe's controllers over defaulted fields?

- Use the demo cluster (GKE `iac-team-standard` / connector `iacteamstandard`) rather than a new cluster. **Install KServe via the install workspace** (or a throwaway apply of the same module) before serve `apply` — do not assume KServe is already there.
- Author a minimal Terraform/OpenTofu config for one `InferenceService`, three ways:
  - `hashicorp/kubernetes` `kubernetes_manifest` — **confirm it fails offline** (documents the problem for reviewers).
  - `alekc/kubectl` fork with server-side apply — the PRD's recommended path.
  - `helm_release` with a generated chart — the fallback for the **install** layer and, if needed, serve.
- For each: run `plan` with the cluster network **blocked**, and record whether it succeeds.
- Test server-side apply field ownership: apply, let KServe's controller default a dozen fields, re-plan, confirm no spurious diff (this is the FR-2 requirement and it directly feeds M3 drift work).

**Exit criteria:** one provider path produces a clean offline plan AND a stable no-diff re-plan after controller defaulting. That path is now the POC's foundation. Install workspace has applied successfully on the demo cluster (KServe CRDs present).

**Decision forced here:** community fork vs. Harness-maintained provider vs. Helm. For the POC, use whichever passes the exit criteria fastest — but write down the production liability (a first-party product depending on a single-maintainer fork) as a flag for the real Phase 1. This is PRD open question §13-Q1, and M0 is where the POC answers it. Helm remaining the likely implementation for **install** even if alekc wins **serve**.

### M1 — Two modules + two workspaces

**Depends on:** M0 provider choice; install workspace applied.

**Install**

- Author a slim `kserve-platform` module: KServe operator/CRDs (and Knative or KServe’s documented dependency set) — enough for one `InferenceService`, not a multi-tenant platform product.
- Workspace `kserve-platform-demo` sources that module. Same cluster variable set as serve.
- **Exit (install):** `kubectl get crd inferenceservices.serving.kserve.io` succeeds on the demo cluster after apply.

**Serve**

- Author a single leaf module — `kserve-llm-inference-service` — covering just the LLM path (the PRD says demo LLM, build both; for the POC, one is enough to prove the concept). A CPU sklearn / small CPU model is acceptable for mechanics; keep `gpu_type` on the contract for the cost demo.
- Input contract per PRD §6.4, but tagged by ownership: declared-state inputs (`model_uri`, `tensor_parallel_size`, `gpu_type`, `max_replicas`, `quantization`) vs. runtime-owned fields the module must **not** manage (the live replica count — ceded to the autoscaler).
- Implement **offline semantic validation** (FR-4): `tensor_parallel_size` must divide `gpu_count`; `min_replicas = 0` only if the deployment mode supports scale-to-zero. These run at `plan` with no cluster — catching the "Pending pod" class of error is a big share of the user-visible value.
- Outputs (FR-5): endpoint URL, resolved GPU footprint, resource identity.
- Create workspace `fraud-llm-staging` sourcing the leaf module; cluster connection + registry creds in the **shared variable set** (not duplicated as a third workspace).

**Exit criteria (serve):** changing a variable and running the serve workspace pipeline provisions a working `InferenceService` and outputs a curl-able endpoint.

### M2 — Cost on the plan (the headline)

**Depends on:** M1 **serve** plan output.

- Implement the derived GPU cost estimate (FR-9): `gpu_count × gpu_type × replica bounds`, priced against the target node pool. Show a **range** (min→max replicas), not a point estimate.
- Source the GPU price list — for the POC a static priced table per node pool is fine; note that production wants this live. CPU-only cluster is OK; the number is still from declared GPU intent.
- **CCM actuals (FR-10) is a spike, not a build, for the POC.** Answer the §13-Q4 question: does CCM already expose node-level GPU cost at the granularity we need? Time-box this to a couple of days. If yes, wire a read-only view. If no, the POC shows the *estimate* only and we log CCM-actuals as a real Phase 1 dependency. Do not let the POC block on another team's roadmap.

**Exit criteria:** the PR plan on the **serve** workspace renders "$X/hr → $Y/hr at peak." That's the money shot.

### M3 — Policy + approval gate

**Depends on:** M1 **serve** plan output (runs parallel to M2).

- Write the OPA pack from PRD §8: deny GPUs over a team ceiling; deny `model_uri` outside an allowlist; require `max_replicas` set; require `cost_center`/`team` tags.
- Wire OPA to evaluate the **plan** (not the applied state).
- Add the plan → apply **approval step** (native IaCM) so the reviewer sees cost + policy result before approving.

**Exit criteria:** an over-budget variant is denied at plan; a compliant one passes and can be approved and applied.

### M4 — Drift detection, scoped (the survival test)

**Depends on:** M0 field-ownership work, M1 **serve** module.

- Implement drift on **module-owned spec fields only**, derived from server-side-apply field ownership — never the whole object, never `status` (FR-6).
- Ship the curated ignore list (FR-7): `status.*`, `metadata.generation`, `metadata.resourceVersion`, controller-injected annotations, and — critically — **replica counts when the autoscaler owns them**. A model scaling 1→4 under load is correct behavior, not drift. (This is exactly the autoscaling-vs-footprint distinction: the autoscaler owns position-within-bounds; IaCM owns the bounds.)
- Tier severity (FR-8): changed `model_uri`/`gpu_count` = P1; a new label = informational.

**Exit criteria:** trigger an autoscale event → no alert. Hand-edit `model_uri` on the cluster → P1 alert. This is the test that proves §7 worked.

### M5 — Stitch the demo + IDP self-service surface

**Depends on:** M1–M4.

- Build the golden-path **Workspace Template** ("Serve a model on KServe") for the **serve** workspace and surface it in IDP so the ML-engineer persona fills a form, not HCL (PRD §6.3). Install stays an ops workspace, not the IDP form.
- Script the demo: brief install (already applied) + seven-step serve loop from §1 into a repeatable runbook.
- Dry-run it end to end; time it. PRD success metric is "model ready → endpoint live in under 30 min"; the demo should visibly beat the "days of ticket ping-pong" baseline.

**Exit criteria:** the full demo runs start to finish from the runbook without manual patching.

---

## 4. The CD boundary (keep it out of the POC, name it clearly)

The POC demonstrates **IaCM as model deployment**: the serve workspace’s provision cycle. That is enough for a CXO. The install workspace is platform infra, not a CD pipeline.

**Deliberately excluded:** promoting a model staging → prod with a canary and metric-watching, and any CD step that applies the `InferenceService` directly. Promotion is a **CD pipeline calling IaCM apply** on a prod serve workspace — the interface is still undefined (PRD §13-Q3). Don’t build it.

One thing to fix in the PRD before the demo: the `canary_traffic_percent` field currently sits inside the IaCM module input, which reads like IaCM doing CD's job. Frame it explicitly as "IaCM declares the split; CD sequences it" so a CD-team reviewer doesn't raise it in the first five minutes.

---

## 5. Sequencing at a glance

```
M0 Provider spike + install WS apply ──► M1 two modules / two WS ──┬─► M2 Cost on plan ──┐
   (kill risk #1; CRDs exist)             (install once, serve trunk) │                     ├─► M5 Demo + IDP
                                                                      ├─► M3 Policy + gate ─┤
                                                                      └─► M4 Drift (scoped) ┘
                                                                            (kill risk #3)
```

M0 is strictly first and strictly gating (including “KServe is actually installed”). M1 is the trunk: install then serve. M2/M3/M4 parallelize once the **serve** module exists. M5 stitches.

---

## 6. Risks and how the POC retires them

| Risk (PRD ref) | How the POC addresses it | Residual for real Phase 1 |
|---|---|---|
| Offline plan impossible (§6.2) | M0 spike proves or kills it before any product work | Provider maintenance/liability decision |
| Provider is a single-maintainer fork (§13-Q1) | POC uses whatever passes M0 fastest | Harness-maintained provider investment |
| GPU cost has no standard model (§9) | M2 derives it on the **serve** workspace; static price table acceptable for demo | Live pricing + CCM actuals path; real GPU node pools (Phase 3) |
| CCM granularity unknown (§13-Q4) | M2 time-boxed spike answers yes/no | If no, it's a scoped CCM ask |
| Drift is unusably noisy (§7) | M4 scopes to owned fields; explicit autoscaler carve-out | Generalizing to any operator-heavy cluster |
| CD boundary undefined (§13-Q3) | Excluded from POC, mocked in demo | Define the CD→IaCM interface contract |
| Platform install is a product of its own (Phase 2) | Slim install workspace only; not multi-tenant `kserve-platform` | Full platform module, upgrades, HA |

---

## 7. Open questions to resolve before/during the POC

1. **Which cluster for the demo?** Default: existing GKE `iac-team-standard` via `iacteamstandard` / namespace `kserve-m0`. A small GPU node is *not* required for mechanics; confirm if/when we add one for a live GPU pod.
2. **Predictive or generative model for the demo?** PRD leans "build both, demo LLM." For the POC, CPU sklearn or a single small CPU LLM keeps it cheap; keep the GPU fields on the serve contract.
3. **CCM data path (§13-Q4)** — resolve in the M2 spike; escalate to the CCM team early since it may gate the headline.
4. **Provider decision (§13-Q1)** — M0 answers it for the POC; the *production* decision should be flagged to eng leadership regardless of what the POC uses.
5. **Design partner / CXO** — who do we run the final demo for? Story is “model deployments live in Harness as IaCM,” not “we built CD for KServe.”
