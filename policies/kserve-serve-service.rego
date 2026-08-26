package service

# Evaluated by Harness OPA On Save for Service entities.
# Does not see InferenceService YAML from Git (storageUri, replicas, tags).
# Those stay on IaCM terraform_plan for the serve workspace.

allowed_connector_refs := {
	"sunnygithub",
	"account.sunnygithub",
}

allowed_repo_names := {
	"kserve-iacm-poc",
	"sunnyagarwal008/kserve-iacm-poc",
}

svc := input.serviceEntity

manifests := object.get(object.get(object.get(svc, "serviceDefinition", {}), "spec", {}), "manifests", [])

store(m) := object.get(object.get(m, "spec", {}), "store", {})

store_spec(m) := object.get(store(m), "spec", {})

deny[msg] {
	svc.serviceDefinition.type != "Kubernetes"
	msg := "KServe CD services must use Kubernetes type"
}

deny[msg] {
	svc.serviceDefinition.type == "Kubernetes"
	count(github_k8s_manifests) == 0
	msg := "KServe CD services must store manifests in GitHub"
}

deny[msg] {
	svc.serviceDefinition.type == "Kubernetes"
	m := github_k8s_manifests[_]
	not allowed_connector_refs[store_spec(m).connectorRef]
	msg := sprintf("manifest Git connector %q is not allowed", [store_spec(m).connectorRef])
}

deny[msg] {
	svc.serviceDefinition.type == "Kubernetes"
	m := github_k8s_manifests[_]
	not allowed_repo_names[store_spec(m).repoName]
	msg := sprintf("manifest repo %q is not allowed", [store_spec(m).repoName])
}

deny[msg] {
	svc.serviceDefinition.type == "Kubernetes"
	m := github_k8s_manifests[_]
	store_spec(m).branch != "main"
	msg := "manifest branch must be main"
}

deny[msg] {
	svc.serviceDefinition.type == "Kubernetes"
	count(github_k8s_manifests) > 0
	not has_inferenceservice_path
	msg := "manifest paths must include cd/<model>/inferenceservice.yaml"
}

github_k8s_manifests[m] {
	item := manifests[_]
	m := item.manifest
	m.type == "K8sManifest"
	store(m).type == "Github"
}

has_inferenceservice_path {
	m := github_k8s_manifests[_]
	p := store_spec(m).paths[_]
	re_match(`^cd/[^/]+/inferenceservice\.yaml$`, p)
}
