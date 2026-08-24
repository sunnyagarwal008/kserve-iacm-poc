# CD twin: qwen25-05b-cd

Harness CD Kubernetes service `qwen2505bcd` applies this InferenceService.
The IaCM workspace `qwen25_05b` owns `qwen25-05b` — do not reuse that name.

Warning: the Policy step evaluates only a reconstructed nine-field JSON subset produced by `curl` + `awk`, not the full multi-document YAML applied by `K8sApply`. Keep exactly one InferenceService document in `inferenceservice.yaml`; do not add a second document named `qwen25-05b`.

With OPA 1.19, run policy tests as `opa test policies/ --v0-compatible`.
