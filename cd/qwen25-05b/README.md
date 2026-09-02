# CD twin: qwen25-05b-cd

Harness CD Kubernetes service `qwen2505bcd` applies this InferenceService.
The IaCM workspace `qwen25_05b` owns `qwen25-05b` — do not reuse that name.

Governance split:

- **CD Service On Save** (`policies/kserve-serve-service.rego`, package `service`): Kubernetes type, GitHub store, connector `sunnygithub`, repo `kserve-iacm-poc`, branch `main`, path `cd/<model>/inferenceservice.yaml`. Harness does not load Git YAML on save, so this policy cannot see `storageUri` / replicas / labels.
- **IaCM plan** (`policies/kserve-serve-plan.rego`): model allowlist, max_replicas, GPU ceiling, team / cost_center. Still the source of those rules for the IaCM twin.

`policies/kserve-serve-manifest.rego` is unused by the CD pipeline (Custom On Step needed a JSON payload; we dropped the Shell reconstruction). Keep it as the CR-shaped rule set if you re-enable a Custom Policy step later.

After Apply, `modelcddeploy` runs Shell step `publishendpoint`. It exports `endpoint_url` as `http://qwen25-05b-cd-kserve-m0.<ingress_domain>` (pipeline variable, default `8.231.51.197.sslip.io`). That is a constructed origin, not a probed KServe status URL and not `/openai/v1/chat/completions`. Keep `ingress_domain` aligned with `kserve-platform-demo`.

With OPA 1.19, run policy tests as `opa test policies/ --v0-compatible`.
