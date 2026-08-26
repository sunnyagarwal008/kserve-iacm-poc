# kserve-model-workspace

Project-scoped IaCM **Workspace** template `kservemodelworkspace` / `v1`.

Use **Use Template** (stay linked) or **Copy Template** (one-shot) when creating a new model workspace in `Model_Deployment`.

Locked: OpenTofu 1.11.2, git `stacks/fraud-llm-staging` on `main`, namespace `kserve-m0`, registry PAT env var, `offline_plan=false`.

Not locked: `name`, `model_uri`, `model_format`, `backend`, replicas, GPU declaration, tags, ingress domain.

Default apply pipeline is `modeldeploy`. That pipeline takes runtime input `workspace` (default `qwen25_05b`).
