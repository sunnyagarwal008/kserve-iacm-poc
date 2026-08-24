# KServe platform demo stack

Root module for the `kserve-platform-demo` Harness IaCM workspace.

- Repository path: `stacks/kserve-platform-demo`
- Module source: IaCM registry `kserve-platform/kubernetes` `v1.0.0`
- Runtime: KubernetesDirect
- Connector: `iacteamstandard`
- Runner namespace: `kserve-m0`
- KServe mode: `Standard` (no Knative dependency)

The workspace installs KServe once, plus a dedicated nginx ingress
controller (`IngressClass` `kserve`). Model `InferenceService` resources belong
to the separate serve workspace. Hostnames are
`<name>-<namespace>.<ingress_domain>` (default `<load-balancer-ip>.sslip.io`).
