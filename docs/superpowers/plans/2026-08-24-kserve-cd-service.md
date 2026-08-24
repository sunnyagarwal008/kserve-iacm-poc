# KServe CD Service Twin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a parallel Harness CD path in `Model_Deployment` that deploys twin InferenceService `qwen25-05b-cd` with Custom OPA on the manifest, without changing the IaCM serve workspace.

**Architecture:** Git-tracked Kubernetes manifest + Harness Kubernetes service/env/infra + pipeline (read manifest → Custom OPA → approval → K8sApply). Platform and `qwen25_05b` stay IaCM. Two CRs in namespace `kserve-m0`.

**Tech Stack:** Kubernetes InferenceService YAML, OPA/Rego, Harness CD v0 YAML, Harness CLI (`--profile qa`), Python 3 for YAML contract tests.

**Spec:** `docs/superpowers/specs/2026-08-24-kserve-cd-service-design.md`

## Global Constraints

- Org `default`, project `Model_Deployment`, profile `qa` (`qa.harness.io`), account `25NKDX79QPC-YTyninmxRQ`.
- Connectors: GitHub `sunnygithub` (account URL `https://github.com/sunnyagarwal008`, repo `kserve-iacm-poc`, branch `main`); K8s `iacteamstandard`; namespace `kserve-m0`.
- Twin name **must** be `qwen25-05b-cd` (never `qwen25-05b`).
- Model URI allowlist is exactly `hf://Qwen/Qwen2.5-0.5B-Instruct`.
- GPU ceiling is `4`; GPU is annotation-only (`kserve.poc/gpu-count`, `kserve.poc/gpu-type`), not `nvidia.com/gpu`.
- Labels: `team=ml-platform`, `cost_center=kserve-poc`, `app.kubernetes.io/managed-by=harness-cd`.
- Do not modify IaCM stacks, modules, `qwen25_05b` workspace, `model-deploy`, or `platform-deploy`.
- No Helm. No HTTP verify step (optional in spec; skip for v1).
- Harness identifiers: service `qwen2505bcd`, env `kservestaging`, infra `kservem0`, pipeline `modelcddeploy`, policy `kserveservemanifest`, policy set `kserveservemanifest`.
- Custom OPA package name is `custom`. Policy set type is Custom, enforcement Error.
- Use `harness` CLI with `--profile qa`; no MCP for Harness writes.
- Do not change git config; do not skip hooks; commit only files this task owns.

---

## File map

- Create: `cd/qwen25-05b/inferenceservice.yaml` — twin CR
- Create: `cd/qwen25-05b/README.md` — pointer for humans
- Create: `cd/qwen25-05b/test_manifest.py` — contract tests
- Create: `policies/kserve-serve-manifest.rego` — CD OPA
- Create: `policies/kserve-serve-manifest_test.rego` — OPA unit tests
- Create: `harness/cd/service-qwen2505bcd.yaml`
- Create: `harness/cd/environment-kservestaging.yaml`
- Create: `harness/cd/infrastructure-kservem0.yaml`
- Create: `harness/pipelines/model-cd-deploy.yaml`
- Create: `harness/policies/kserve-serve-manifest.yaml` — policy + set notes for CLI create
- Unchanged: everything under `stacks/`, `modules/`, `harness/pipelines/model-deploy.yaml`, `harness/pipelines/platform-deploy.yaml`, `policies/kserve-serve-plan.rego`

---

### Task 1: Twin InferenceService manifest and contract tests

**Files:**
- Create: `cd/qwen25-05b/inferenceservice.yaml`
- Create: `cd/qwen25-05b/test_manifest.py`
- Create: `cd/qwen25-05b/README.md`

**Interfaces:**
- Consumes: spec manifest contract
- Produces: YAML at `cd/qwen25-05b/inferenceservice.yaml` with `metadata.name = qwen25-05b-cd`

- [ ] **Step 1: Write the failing contract test**

```python
#!/usr/bin/env python3
"""Contract tests for the CD twin InferenceService."""
from pathlib import Path
import unittest

try:
    import yaml
except ImportError:
    raise SystemExit("PyYAML required: pip3 install pyyaml")

MANIFEST = Path(__file__).with_name("inferenceservice.yaml")


class TestCdTwinManifest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.doc = yaml.safe_load(MANIFEST.read_text())

    def test_kind_and_name(self):
        self.assertEqual(self.doc["apiVersion"], "serving.kserve.io/v1beta1")
        self.assertEqual(self.doc["kind"], "InferenceService")
        self.assertEqual(self.doc["metadata"]["name"], "qwen25-05b-cd")
        self.assertEqual(self.doc["metadata"]["namespace"], "kserve-m0")

    def test_does_not_collide_with_iacm_name(self):
        self.assertNotEqual(self.doc["metadata"]["name"], "qwen25-05b")

    def test_labels(self):
        labels = self.doc["metadata"]["labels"]
        self.assertEqual(labels["app.kubernetes.io/part-of"], "kserve-iacm-poc")
        self.assertEqual(labels["app.kubernetes.io/managed-by"], "harness-cd")
        self.assertEqual(labels["team"], "ml-platform")
        self.assertEqual(labels["cost_center"], "kserve-poc")

    def test_gpu_annotations(self):
        ann = self.doc["metadata"]["annotations"]
        self.assertEqual(ann["kserve.poc/gpu-count"], "0")
        self.assertEqual(ann["kserve.poc/gpu-type"], "l4")

    def test_predictor(self):
        pred = self.doc["spec"]["predictor"]
        self.assertEqual(pred["minReplicas"], 1)
        self.assertEqual(pred["maxReplicas"], 1)
        model = pred["model"]
        self.assertEqual(model["modelFormat"]["name"], "huggingface")
        self.assertEqual(model["args"], ["--backend=huggingface"])
        self.assertEqual(model["storageUri"], "hf://Qwen/Qwen2.5-0.5B-Instruct")
        self.assertEqual(model["resources"]["requests"], {"cpu": "2", "memory": "8Gi"})
        self.assertEqual(model["resources"]["limits"], {"cpu": "4", "memory": "12Gi"})


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 cd/qwen25-05b/test_manifest.py`
Expected: FAIL (file missing or fields missing)

- [ ] **Step 3: Write the manifest and README**

`cd/qwen25-05b/inferenceservice.yaml`:

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: qwen25-05b-cd
  namespace: kserve-m0
  labels:
    app.kubernetes.io/part-of: kserve-iacm-poc
    app.kubernetes.io/managed-by: harness-cd
    team: ml-platform
    cost_center: kserve-poc
  annotations:
    kserve.poc/gpu-count: "0"
    kserve.poc/gpu-type: l4
spec:
  predictor:
    minReplicas: 1
    maxReplicas: 1
    model:
      modelFormat:
        name: huggingface
      args:
        - --backend=huggingface
      storageUri: hf://Qwen/Qwen2.5-0.5B-Instruct
      resources:
        requests:
          cpu: "2"
          memory: 8Gi
        limits:
          cpu: "4"
          memory: 12Gi
```

`cd/qwen25-05b/README.md`:

```markdown
# CD twin: qwen25-05b-cd

Harness CD Kubernetes service `qwen2505bcd` applies this InferenceService.
The IaCM workspace `qwen25_05b` owns `qwen25-05b` — do not reuse that name.
```

- [ ] **Step 4: Run tests and make sure they pass**

Run: `python3 cd/qwen25-05b/test_manifest.py`
Expected: PASS (`OK`)

- [ ] **Step 5: Commit**

```bash
git add cd/qwen25-05b/inferenceservice.yaml cd/qwen25-05b/test_manifest.py cd/qwen25-05b/README.md
git commit -m "$(cat <<'EOF'
Add the CD twin InferenceService manifest.

Keep qwen25-05b-cd as a second CR so Harness CD does not share a field manager with IaCM.
EOF
)"
```

---

### Task 2: Custom OPA policy for the InferenceService manifest

**Files:**
- Create: `policies/kserve-serve-manifest.rego`
- Create: `policies/kserve-serve-manifest_test.rego`
- Test: `opa test policies/` (install `opa` via `brew install opa` if missing)

**Interfaces:**
- Consumes: Kubernetes object as `input` (root `kind`) or `input.manifest`
- Produces: `deny` set; package `custom`

- [ ] **Step 1: Write failing OPA tests**

`policies/kserve-serve-manifest_test.rego`:

```rego
package custom

good := {
	"apiVersion": "serving.kserve.io/v1beta1",
	"kind": "InferenceService",
	"metadata": {
		"name": "qwen25-05b-cd",
		"namespace": "kserve-m0",
		"labels": {"team": "ml-platform", "cost_center": "kserve-poc"},
		"annotations": {"kserve.poc/gpu-count": "0"},
	},
	"spec": {"predictor": {
		"maxReplicas": 1,
		"model": {"storageUri": "hf://Qwen/Qwen2.5-0.5B-Instruct"},
	}},
}

test_allows_good_manifest {
	count(deny) == 0 with input as good
}

test_allows_wrapped_manifest {
	count(deny) == 0 with input as {"manifest": good}
}

test_denies_iacm_name {
	bad := json.patch(good, [{"op": "replace", "path": "/metadata/name", "value": "qwen25-05b"}])
	deny["CD must not apply InferenceService name \"qwen25-05b\" (owned by IaCM)"] with input as bad
}

test_denies_unlisted_model {
	bad := json.patch(good, [{"op": "replace", "path": "/spec/predictor/model/storageUri", "value": "hf://evil/model"}])
	deny["model storageUri \"hf://evil/model\" is not on the serve allowlist"] with input as bad
}

test_denies_max_replicas_zero {
	bad := json.patch(good, [{"op": "replace", "path": "/spec/predictor/maxReplicas", "value": 0}])
	deny["maxReplicas must be at least 1"] with input as bad
}

test_denies_gpu_over_ceiling {
	bad := json.patch(good, [{"op": "replace", "path": "/metadata/annotations/kserve.poc~1gpu-count", "value": "8"}])
	deny["gpu_count 8 exceeds the team ceiling of 4"] with input as bad
}

test_denies_missing_team {
	bad := json.patch(good, [{"op": "replace", "path": "/metadata/labels/team", "value": ""}])
	deny["team tag is required"] with input as bad
}

test_denies_wrong_kind {
	deny["payload must be an InferenceService"] with input as {"kind": "Deployment"}
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `opa test policies/kserve-serve-manifest_test.rego policies/kserve-serve-manifest.rego -v`
Expected: FAIL (undefined `deny` / missing file)

- [ ] **Step 3: Write the policy**

`policies/kserve-serve-manifest.rego`:

```rego
package custom

# Evaluated by a Harness Custom Policy step. Payload is the InferenceService
# object, optionally wrapped as {"manifest": {...}}.

allowed_model_uris := {
	"hf://Qwen/Qwen2.5-0.5B-Instruct",
}

gpu_count_ceiling := 4

doc := input.manifest {
	input.manifest.kind == "InferenceService"
}

doc := input {
	not input.manifest
	input.kind == "InferenceService"
}

storage_uri := doc.spec.predictor.model.storageUri

max_replicas := doc.spec.predictor.maxReplicas

gpu_count_raw := object.get(object.get(doc.metadata, "annotations", {}), "kserve.poc/gpu-count", "0")

team := object.get(object.get(doc.metadata, "labels", {}), "team", "")

cost_center := object.get(object.get(doc.metadata, "labels", {}), "cost_center", "")

deny[msg] {
	not doc
	msg := "payload must be an InferenceService"
}

deny[msg] {
	doc
	doc.metadata.name == "qwen25-05b"
	msg := "CD must not apply InferenceService name \"qwen25-05b\" (owned by IaCM)"
}

deny[msg] {
	doc
	storage_uri == null
	msg := "model storageUri must be set"
}

deny[msg] {
	doc
	storage_uri != null
	not allowed_model_uris[storage_uri]
	msg := sprintf("model storageUri %q is not on the serve allowlist", [storage_uri])
}

deny[msg] {
	doc
	max_replicas == null
	msg := "maxReplicas must be set"
}

deny[msg] {
	doc
	max_replicas != null
	to_number(max_replicas) < 1
	msg := "maxReplicas must be at least 1"
}

deny[msg] {
	doc
	to_number(gpu_count_raw) > gpu_count_ceiling
	msg := sprintf("gpu_count %v exceeds the team ceiling of %v", [to_number(gpu_count_raw), gpu_count_ceiling])
}

deny[msg] {
	doc
	not nonempty(team)
	msg := "team tag is required"
}

deny[msg] {
	doc
	not nonempty(cost_center)
	msg := "cost_center tag is required"
}

nonempty(x) {
	x != null
	x != ""
}
```

- [ ] **Step 4: Run tests and make sure they pass**

Run: `opa test policies/ -v`
Expected: all tests PASS (existing `kserve-serve-plan_test.rego` still green)

If `opa` is missing: `brew install opa` then re-run.

- [ ] **Step 5: Commit**

```bash
git add policies/kserve-serve-manifest.rego policies/kserve-serve-manifest_test.rego
git commit -m "$(cat <<'EOF'
Add Custom OPA rules for the CD InferenceService manifest.

Mirror the IaCM allowlist, replica floor, GPU ceiling, and required tags on YAML fields.
EOF
)"
```

---

### Task 3: Harness CD YAML in git

**Files:**
- Create: `harness/cd/service-qwen2505bcd.yaml`
- Create: `harness/cd/environment-kservestaging.yaml`
- Create: `harness/cd/infrastructure-kservem0.yaml`
- Create: `harness/pipelines/model-cd-deploy.yaml`
- Create: `harness/policies/kserve-serve-manifest.yaml`

**Interfaces:**
- Consumes: manifest path `cd/qwen25-05b`, connector IDs from Global Constraints
- Produces: YAML ready for `harness create` in Task 4

- [ ] **Step 1: Write a parser smoke test**

Create `harness/cd/test_yaml_ids.py`:

```python
#!/usr/bin/env python3
from pathlib import Path
import unittest
import yaml

ROOT = Path(__file__).resolve().parent


class TestHarnessCdIds(unittest.TestCase):
    def test_service_id(self):
        d = yaml.safe_load((ROOT / "service-qwen2505bcd.yaml").read_text())
        self.assertEqual(d["service"]["identifier"], "qwen2505bcd")
        self.assertEqual(d["service"]["serviceDefinition"]["type"], "Kubernetes")
        spec = d["service"]["serviceDefinition"]["spec"]["manifests"][0]["manifest"]["spec"]
        self.assertEqual(spec["store"]["spec"]["paths"], ["cd/qwen25-05b"])

    def test_env_and_infra(self):
        env = yaml.safe_load((ROOT / "environment-kservestaging.yaml").read_text())
        inf = yaml.safe_load((ROOT / "infrastructure-kservem0.yaml").read_text())
        self.assertEqual(env["environment"]["identifier"], "kservestaging")
        self.assertEqual(env["environment"]["type"], "PreProduction")
        self.assertEqual(inf["infrastructureDefinition"]["identifier"], "kservem0")
        self.assertEqual(inf["infrastructureDefinition"]["environmentRef"], "kservestaging")
        self.assertEqual(inf["infrastructureDefinition"]["spec"]["namespace"], "kserve-m0")
        self.assertEqual(inf["infrastructureDefinition"]["spec"]["connectorRef"], "iacteamstandard")

    def test_pipeline_steps(self):
        p = yaml.safe_load((ROOT.parent / "pipelines" / "model-cd-deploy.yaml").read_text())
        self.assertEqual(p["pipeline"]["identifier"], "modelcddeploy")
        steps = p["pipeline"]["stages"][0]["stage"]["spec"]["execution"]["steps"]
        types = [s["step"]["type"] for s in steps]
        self.assertEqual(types, ["ShellScript", "Policy", "HarnessApproval", "K8sApply"])
        apply = steps[3]["step"]["spec"]
        self.assertTrue(apply["skipSteadyStateCheck"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it — expect FAIL (files missing)**

Run: `python3 harness/cd/test_yaml_ids.py`

- [ ] **Step 3: Write the YAML files**

`harness/cd/service-qwen2505bcd.yaml`:

```yaml
service:
  name: qwen25-05b-cd
  identifier: qwen2505bcd
  orgIdentifier: default
  projectIdentifier: Model_Deployment
  tags:
    poc: kserve-cd
  serviceDefinition:
    type: Kubernetes
    spec:
      manifests:
        - manifest:
            identifier: inferenceservice
            type: K8sManifest
            spec:
              skipResourceVersioning: true
              store:
                type: Github
                spec:
                  connectorRef: sunnygithub
                  gitFetchType: Branch
                  repoName: kserve-iacm-poc
                  branch: main
                  paths:
                    - cd/qwen25-05b
```

`harness/cd/environment-kservestaging.yaml`:

```yaml
environment:
  name: kserve-staging
  identifier: kservestaging
  orgIdentifier: default
  projectIdentifier: Model_Deployment
  type: PreProduction
  tags:
    poc: kserve-cd
```

`harness/cd/infrastructure-kservem0.yaml`:

```yaml
infrastructureDefinition:
  name: kserve-m0
  identifier: kservem0
  orgIdentifier: default
  projectIdentifier: Model_Deployment
  environmentRef: kservestaging
  deploymentType: Kubernetes
  type: KubernetesDirect
  spec:
    connectorRef: iacteamstandard
    namespace: kserve-m0
    releaseName: qwen2505bcd-<+INFRA_KEY_SHORT_ID>
  allowSimultaneousDeployments: false
```

`harness/pipelines/model-cd-deploy.yaml`:

```yaml
pipeline:
  name: model-cd-deploy
  identifier: modelcddeploy
  projectIdentifier: Model_Deployment
  orgIdentifier: default
  tags:
    poc: kserve-cd
  description: Deploy the qwen25-05b-cd InferenceService via Kubernetes Apply with Custom OPA.
  stages:
    - stage:
        name: deploy-model
        identifier: deploymodel
        type: Deployment
        spec:
          deploymentType: Kubernetes
          service:
            serviceRef: qwen2505bcd
          environment:
            environmentRef: kservestaging
            deployToAll: false
            infrastructureDefinitions:
              - identifier: kservem0
          execution:
            steps:
              - step:
                  type: ShellScript
                  name: read-manifest
                  identifier: readmanifest
                  timeout: 5m
                  spec:
                    shell: Bash
                    source:
                      type: Inline
                      spec:
                        script: |
                          set -euo pipefail
                          MANIFEST_JSON=$(python3 - <<'PY'
                          import json, urllib.request
                          try:
                              import yaml
                          except ImportError:
                              import subprocess, sys
                              subprocess.check_call([sys.executable, "-m", "pip", "install", "--user", "pyyaml", "-q"])
                              import yaml
                          url = "https://raw.githubusercontent.com/sunnyagarwal008/kserve-iacm-poc/main/cd/qwen25-05b/inferenceservice.yaml"
                          doc = yaml.safe_load(urllib.request.urlopen(url, timeout=30).read())
                          print(json.dumps(doc, separators=(",", ":")))
                          PY
                          )
                          export MANIFEST_JSON
                    outputVariables:
                      - name: MANIFEST_JSON
                        type: String
                        value: MANIFEST_JSON
                    onDelegate: true
              - step:
                  type: Policy
                  name: evaluate-serve-opa
                  identifier: evaluateserveopa
                  timeout: 5m
                  spec:
                    policySets:
                      - kserveservemanifest
                    type: Custom
                    policySpec:
                      payload: <+steps.readmanifest.output.outputVariables.MANIFEST_JSON>
              - step:
                  type: HarnessApproval
                  name: approve-cd-apply
                  identifier: approvecdapply
                  timeout: 1d
                  spec:
                    approvalMessage: Review CD OPA result, then apply qwen25-05b-cd.
                    includePipelineExecutionHistory: true
                    approvers:
                      userGroups:
                        - _project_all_users
                      minimumCount: 1
                      disallowPipelineExecutor: false
              - step:
                  type: K8sApply
                  name: apply
                  identifier: apply
                  timeout: 15m
                  spec:
                    skipDryRun: false
                    skipSteadyStateCheck: true
                    filePaths:
                      - inferenceservice.yaml
          rollbackSteps: []
        failureStrategies:
          - onFailure:
              errors:
                - AllErrors
              action:
                type: StageRollback
        tags: {}
```

`harness/policies/kserve-serve-manifest.yaml` (documentation for Task 4 CLI; identifier must match):

```yaml
policy:
  identifier: kserveservemanifest
  name: kserve-serve-manifest
  orgIdentifier: default
  projectIdentifier: Model_Deployment
  type: Custom
  file: policies/kserve-serve-manifest.rego
policySet:
  identifier: kserveservemanifest
  name: kserve-serve-manifest
  orgIdentifier: default
  projectIdentifier: Model_Deployment
  type: Custom
  action: onstep
  enforcement: error
  policies:
    - identifier: kserveservemanifest
```

- [ ] **Step 4: Run the smoke test**

Run: `python3 harness/cd/test_yaml_ids.py`
Expected: PASS

If ShellScript `outputVariables.value: MANIFEST_JSON` fails the test only on pipeline parse, do not invent extra keys; the test only checks step types and `skipSteadyStateCheck`.

- [ ] **Step 5: Commit**

```bash
git add harness/cd harness/pipelines/model-cd-deploy.yaml harness/policies/kserve-serve-manifest.yaml
git commit -m "$(cat <<'EOF'
Add Harness CD service, environment, infra, and model-cd-deploy YAML.

Wire Custom OPA and approval in front of Kubernetes Apply for the twin InferenceService.
EOF
)"
```

---

### Task 4: Create Harness resources and run once

**Files:** none new in git except fixes if CLI rejects YAML.

**Interfaces:**
- Consumes: YAML from Task 3, Rego from Task 2, public `main` for the raw GitHub URL
- Produces: live service/env/infra/pipeline/policy in `Model_Deployment`; one pipeline execution

**Precondition:** Tasks 1–3 commits must be on `origin/main` before the ShellScript curl and the CD Git fetch will see the manifest. Push `main` if this branch is ahead.

- [ ] **Step 1: Push commits so GitHub `main` has `cd/qwen25-05b`**

```bash
git push origin HEAD:main
```

Only push if the user already committed on this branch and remote is `origin`. If not on `main`, merge or push this branch and temporarily set the service `branch` + curl URL to that branch — prefer pushing `main` because the spec and YAML say `main`.

- [ ] **Step 2: Discover CLI nouns**

```bash
harness get module platform --profile qa
harness get noun policy --profile qa
harness get noun policy_set --profile qa
harness create service --help
harness create environment --help
harness create infrastructure --help
harness create pipeline --help
```

Create policy using whatever noun the CLI documents (`policy` / `governance_policy`). If `harness create policy` is missing, use the QA gateway:

```
POST https://qa.harness.io/gateway/pm/api/v1/policies?accountIdentifier=25NKDX79QPC-YTyninmxRQ&orgIdentifier=default&projectIdentifier=Model_Deployment
```

with `x-api-key` from `~/.harness/credentials` profile `qa`, body including `identifier: kserveservemanifest`, `rego` text from the file, and type Custom. Then create a policy set of type Custom referencing that policy with error enforcement.

- [ ] **Step 3: Create objects in order**

```bash
harness create environment --profile qa --project Model_Deployment -f harness/cd/environment-kservestaging.yaml
harness create infrastructure --profile qa --project Model_Deployment -f harness/cd/infrastructure-kservem0.yaml
harness create service --profile qa --project Model_Deployment -f harness/cd/service-qwen2505bcd.yaml
# policy + policy set via CLI or API as discovered
harness create pipeline --profile qa --project Model_Deployment -f harness/pipelines/model-cd-deploy.yaml
```

If create fails because the identifier exists, `harness update ...` instead. Do not delete IaCM pipelines.

- [ ] **Step 4: Execute model-cd-deploy**

```bash
harness execute pipeline modelcddeploy --profile qa --project Model_Deployment
```

Follow until Policy succeeds. Approval may wait; do not fail the task solely because approval is pending — record the execution URL. If Policy fails, fix payload path (`<+execution.steps.readmanifest.output.outputVariables.MANIFEST_JSON>` vs `steps.readmanifest...`) and update the pipeline YAML + Harness, then re-run.

- [ ] **Step 5: Verify twin exists only after apply succeeds**

After approval+apply (if apply ran):

```bash
kubectl get inferenceservice -n kserve-m0
```

Expect both `qwen25-05b` and `qwen25-05b-cd` if kube context is the demo cluster. If kubectl context is wrong, skip and record that apply succeeded in Harness instead.

- [ ] **Step 6: Commit any YAML fixes**

```bash
git add harness/pipelines/model-cd-deploy.yaml harness/cd harness/policies
git commit -m "$(cat <<'EOF'
Fix CD pipeline expressions after the first Harness create/execute.

Keep git YAML aligned with what QA actually accepted.
EOF
)"
```

Skip this commit if nothing changed.

---

## Self-review

- Spec twin name, OPA rules, connectors, skip verify, no IaCM edits — covered in Tasks 1–4.
- Policy payload shape: both root and `.manifest` wrapper in Rego.
- IaCM name protection deny included.
- No TBD/placeholder identifiers.
