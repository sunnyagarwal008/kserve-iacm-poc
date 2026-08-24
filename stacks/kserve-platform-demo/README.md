# KServe platform demo stack

Root module for the `kserve-platform-demo` Harness IaCM workspace.

- Repository path: `stacks/kserve-platform-demo`
- Runtime: KubernetesDirect
- Connector: `iacteamstandard`
- Runner namespace: `kserve-m0`
- KServe mode: `Standard` (no Knative dependency)

The workspace installs KServe once. Model `InferenceService` resources belong
to the separate serve workspace.
