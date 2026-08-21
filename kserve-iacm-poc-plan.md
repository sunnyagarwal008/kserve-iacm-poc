# Implementation Plan — KServe on Harness IaCM (Proof of Concept)

**Goal of this plan:** get to a *working demo* that proves the core thesis — that a KServe model deployment can be driven as a governed IaCM workspace, with an offline plan, GPU cost on the PR, policy enforcement, an approval gate, and quiet drift detection.

**Explicitly not in scope for the POC:** production hardening, multi-tenant scale, the `kserve-platform` install module (PRD Phase 2), cluster provisioning (Phase 3), and the intent layer (Phase 4). This plan covers a demo, not a shippable product.

**Status:** Draft for review
**Related:** PRD "Model Serving as Infrastructure — KServe on Harness IaCM"

---

## 1. What "done" means for the POC

A single scripted demo we can run end to end in front of a design partner:

1. An ML engineer opens a PR that changes a workspace variable (e.g. raises `tensor_parallel_size`, or points `model_uri` at a larger model).
2. IaCM runs `init → plan` **with no live cluster connectivity** and produces a valid plan.
3. The plan shows a **GPU cost delta** ("$4.20/hr → $16.80/hr at peak").
4. An **OPA policy** denies a deliberately over-budget variant, and passes the compliant one.
5. A reviewer approves at the **plan → apply gate**, having seen cost and policy results.
6. `apply` uses **server-side apply**; KServe reconciles; the demo curls the live **endpoint URL** (a module output).
7. A benign controller mutation (autoscaler moves the replica count) produces **no drift alert**; a real change to an owned field (`model_uri`) produces a **P1 drift alert**.

If we can run those seven steps, the concept is proven. Everything else is productization.

---

## 2. The three bets, and why we sequence them this way

Phase 1 of the PRD rests on three unproven assumptions. The rest is standard IaCM composition (Module Registry, workspaces, variable sets, an OPA pack) that Harness already knows how to do. The POC exists to kill or confirm these three — in this order, because each depends on the one before it.

| # | Bet | If it fails | Cost to prove |
|---|---|---|---|
| 1 | **Offline plan + server-side apply for KServe CRDs** (PRD §6.2) | The whole value prop collapses to "Argo with extra steps" — no plan-on-PR | Low — a few days of spiking, no product around it |
| 2 | **GPU cost on the plan** (PRD §9) | The demo loses its headline moment | Medium — must derive GPU cost; CCM actuals need another team |
| 3 | **Field-scoped drift detection** (PRD §7) | Customers disable drift on day one; feature is dead weight | Medium–High — hardest engineering problem in the PRD |

**Why the provider goes first:** bets 2 and 3 both assume a working offline plan already exists. If bet 1 fails, nothing downstream matters. It is also the cheapest to test — you can spike it in isolation before writing a line of module or product code. Retire the foundational risk first.

---

## 3. Milestones

### M0 — Spike: prove the provider (the make-or-break week)

**Question to answer:** can we produce a valid `plan` for a KServe `InferenceService` with **no live cluster reachable**, and `apply` it with server-side apply without fighting KServe's controllers over defaulted fields?

- Stand up a throwaway cluster with KServe installed (single model, e.g. a small Qwen or a sklearn iris model — cheap, no big GPU needed for the mechanics).
- Author a minimal Terraform/OpenTofu config for one `InferenceService`, three ways:
  - `hashicorp/kubernetes` `kubernetes_manifest` — **confirm it fails offline** (documents the problem for reviewers).
  - `alekc/kubectl` fork with server-side apply — the PRD's recommended path.
  - `helm_release` with a generated chart — the fallback for the platform layer.
- For each: run `plan` with the cluster network **blocked**, and record whether it succeeds.
- Test server-side apply field ownership: apply, let KServe's controller default a dozen fields, re-plan, confirm no spurious diff (this is the FR-2 requirement and it directly feeds M3 drift work).

**Exit criteria:** one provider path produces a clean offline plan AND a stable no-diff re-plan after controller defaulting. That path is now the POC's foundation.

**Decision forced here:** community fork vs. Harness-maintained provider vs. Helm. For the POC, use whichever passes the exit criteria fastest — but write down the production liability (a first-party product depending on a single-maintainer fork) as a flag for the real Phase 1. This is PRD open question §13-Q1, and M0 is where the POC answers it.

### M1 — The one module + the workspace

**Depends on:** M0 provider choice.

- Author a single leaf module — `kserve-llm-inference-service` — covering just the LLM path (the PRD says demo LLM, build both; for the POC, one is enough to prove the concept).
- Input contract per PRD §6.4, but tagged by ownership: declared-state inputs (`model_uri`, `tensor_parallel_size`, `gpu_type`, `max_replicas`, `quantization`) vs. runtime-owned fields the module must **not** manage (the live replica count — ceded to the autoscaler).
- Implement **offline semantic validation** (FR-4): `tensor_parallel_size` must divide `gpu_count`; `min_replicas = 0` only if the deployment mode supports scale-to-zero. These run at `plan` with no cluster — catching the "Pending pod" class of error is a big share of the user-visible value.
- Outputs (FR-5): endpoint URL, resolved GPU footprint, resource identity.
- Create one workspace (`fraud-llm-staging`) sourcing the module; put cluster connection + registry creds in a **variable set**.

**Exit criteria:** changing a variable and running the workspace pipeline provisions a working `InferenceService` and outputs a curl-able endpoint.

### M2 — Cost on the plan (the headline)

**Depends on:** M1 plan output.

- Implement the derived GPU cost estimate (FR-9): `gpu_count × gpu_type × replica bounds`, priced against the target node pool. Show a **range** (min→max replicas), not a point estimate.
- Source the GPU price list — for the POC a static priced table per node pool is fine; note that production wants this live.
- **CCM actuals (FR-10) is a spike, not a build, for the POC.** Answer the §13-Q4 question: does CCM already expose node-level GPU cost at the granularity we need? Time-box this to a couple of days. If yes, wire a read-only view. If no, the POC shows the *estimate* only and we log CCM-actuals as a real Phase 1 dependency. Do not let the POC block on another team's roadmap.

**Exit criteria:** the PR plan renders "$X/hr → $Y/hr at peak." That's the money shot.

### M3 — Policy + approval gate

**Depends on:** M1 plan output (runs parallel to M2).

- Write the OPA pack from PRD §8: deny GPUs over a team ceiling; deny `model_uri` outside an allowlist; require `max_replicas` set; require `cost_center`/`team` tags.
- Wire OPA to evaluate the **plan** (not the applied state).
- Add the plan → apply **approval step** (native IaCM) so the reviewer sees cost + policy result before approving.

**Exit criteria:** an over-budget variant is denied at plan; a compliant one passes and can be approved and applied.

### M4 — Drift detection, scoped (the survival test)

**Depends on:** M0 field-ownership work, M1 module.

- Implement drift on **module-owned spec fields only**, derived from server-side-apply field ownership — never the whole object, never `status` (FR-6).
- Ship the curated ignore list (FR-7): `status.*`, `metadata.generation`, `metadata.resourceVersion`, controller-injected annotations, and — critically — **replica counts when the autoscaler owns them**. A model scaling 1→4 under load is correct behavior, not drift. (This is exactly the autoscaling-vs-footprint distinction: the autoscaler owns position-within-bounds; IaCM owns the bounds.)
- Tier severity (FR-8): changed `model_uri`/`gpu_count` = P1; a new label = informational.

**Exit criteria:** trigger an autoscale event → no alert. Hand-edit `model_uri` on the cluster → P1 alert. This is the test that proves §7 worked.

### M5 — Stitch the demo + IDP self-service surface

**Depends on:** M1–M4.

- Build the golden-path **Workspace Template** ("Serve a model on KServe") and surface it in IDP so the ML-engineer persona fills a form, not HCL (PRD §6.3).
- Script the seven-step demo from §1 of this plan into a repeatable runbook.
- Dry-run it end to end; time it. PRD success metric is "model ready → endpoint live in under 30 min"; the demo should visibly beat the "days of ticket ping-pong" baseline.

**Exit criteria:** the full demo runs start to finish from the runbook without manual patching.

---

## 4. The CD boundary (keep it out of the POC, name it clearly)

The POC demonstrates a **single workspace's** provision cycle: bringing capacity into existence and governing its shape. That is pure IaCM and it is enough to prove the thesis.

**Deliberately excluded:** promoting a model staging → prod with a canary and metric-watching. That is a **CD pipeline calling IaCM**, not IaCM itself, and the interface is still undefined (PRD §13-Q3). Pulling it into the POC would blur the exact boundary the PRD is trying to draw. For the demo, if we want to *show* promotion, mock it as "a CD pipeline would trigger the prod workspace's apply here" — don't build it.

One thing to fix in the PRD before the demo: the `canary_traffic_percent` field currently sits inside the IaCM module input, which reads like IaCM doing CD's job. Frame it explicitly as "IaCM declares the split; CD sequences it" so a CD-team reviewer doesn't raise it in the first five minutes.

---

## 5. Sequencing at a glance

```
M0 Provider spike ──► M1 Module + workspace ──┬─► M2 Cost on plan ──┐
   (kill risk #1)        (foundation)          │                     ├─► M5 Demo + IDP
                                               ├─► M3 Policy + gate ─┤
                                               └─► M4 Drift (scoped) ┘
                                                     (kill risk #3)
```

M0 is strictly first and strictly gating. M1 is the trunk. M2/M3/M4 parallelize once the module exists. M5 stitches.

---

## 6. Risks and how the POC retires them

| Risk (PRD ref) | How the POC addresses it | Residual for real Phase 1 |
|---|---|---|
| Offline plan impossible (§6.2) | M0 spike proves or kills it before any product work | Provider maintenance/liability decision |
| Provider is a single-maintainer fork (§13-Q1) | POC uses whatever passes M0 fastest | Harness-maintained provider investment |
| GPU cost has no standard model (§9) | M2 derives it; static price table acceptable for demo | Live pricing + CCM actuals path |
| CCM granularity unknown (§13-Q4) | M2 time-boxed spike answers yes/no | If no, it's a scoped CCM ask |
| Drift is unusably noisy (§7) | M4 scopes to owned fields; explicit autoscaler carve-out | Generalizing to any operator-heavy cluster |
| CD boundary undefined (§13-Q3) | Excluded from POC, mocked in demo | Define the CD→IaCM interface contract |

---

## 7. Open questions to resolve before/during the POC

1. **Which cluster for the demo?** A cheap managed cluster with one small GPU node is enough for the mechanics — we don't need H100s to prove plan/apply/cost/drift. Confirm budget + who owns it.
2. **Predictive or generative model for the demo?** PRD leans "build both, demo LLM." For the POC, a single small LLM keeps it cheap and on-message. Confirm.
3. **CCM data path (§13-Q4)** — resolve in the M2 spike; escalate to the CCM team early since it may gate the headline.
4. **Provider decision (§13-Q1)** — M0 answers it for the POC; the *production* decision should be flagged to eng leadership regardless of what the POC uses.
5. **Design partner** — who do we run the final demo for? Ideally someone already running KServe, per the PRD's "value in an afternoon" claim.
