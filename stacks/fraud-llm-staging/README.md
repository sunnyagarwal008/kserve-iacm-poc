# Fraud LLM staging stack

Root module for the `fraud-llm-staging` Harness IaCM serve workspace.

- Repository path: `stacks/fraud-llm-staging`
- Runtime: KubernetesDirect
- Connector: `iacteamstandard`
- Runner namespace: `kserve-m0`
- Model: `hf://Qwen/Qwen2.5-0.5B-Instruct` on the Hugging Face CPU backend

GPU fields on this workspace are declared cost/policy inputs. This demo cluster
does not schedule `nvidia.com/gpu`.
