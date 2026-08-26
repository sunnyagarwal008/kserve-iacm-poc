package service

good := {
	"serviceEntity": {
		"identifier": "qwen2505bcd",
		"name": "qwen25-05b-cd",
		"orgIdentifier": "default",
		"projectIdentifier": "Model_Deployment",
		"tags": {"poc": "kserve-cd"},
		"serviceDefinition": {
			"type": "Kubernetes",
			"spec": {"manifests": [{
				"manifest": {
					"identifier": "inferenceservice",
					"type": "K8sManifest",
					"spec": {
						"store": {
							"type": "Github",
							"spec": {
								"connectorRef": "sunnygithub",
								"gitFetchType": "Branch",
								"repoName": "kserve-iacm-poc",
								"branch": "main",
								"paths": ["cd/qwen25-05b/inferenceservice.yaml"],
							},
						},
					},
				},
			}]},
		},
	},
}

test_allows_current_cd_service {
	count(deny) == 0 with input as good
}

test_denies_non_kubernetes {
	bad := json.patch(good, [{"op": "replace", "path": "/serviceEntity/serviceDefinition/type", "value": "NativeHelm"}])
	deny["KServe CD services must use Kubernetes type"] with input as bad
}

test_denies_s3_store {
	bad := json.patch(good, [{"op": "replace", "path": "/serviceEntity/serviceDefinition/spec/manifests/0/manifest/spec/store/type", "value": "S3"}])
	deny["KServe CD services must store manifests in GitHub"] with input as bad
}

test_denies_wrong_connector {
	bad := json.patch(good, [{"op": "replace", "path": "/serviceEntity/serviceDefinition/spec/manifests/0/manifest/spec/store/spec/connectorRef", "value": "othergit"}])
	deny["manifest Git connector \"othergit\" is not allowed"] with input as bad
}

test_denies_wrong_repo {
	bad := json.patch(good, [{"op": "replace", "path": "/serviceEntity/serviceDefinition/spec/manifests/0/manifest/spec/store/spec/repoName", "value": "evil-repo"}])
	deny["manifest repo \"evil-repo\" is not allowed"] with input as bad
}

test_denies_wrong_branch {
	bad := json.patch(good, [{"op": "replace", "path": "/serviceEntity/serviceDefinition/spec/manifests/0/manifest/spec/store/spec/branch", "value": "dev"}])
	deny["manifest branch must be main"] with input as bad
}

test_denies_wrong_path {
	bad := json.patch(good, [{"op": "replace", "path": "/serviceEntity/serviceDefinition/spec/manifests/0/manifest/spec/store/spec/paths/0", "value": "k8s/deploy.yaml"}])
	deny["manifest paths must include cd/<model>/inferenceservice.yaml"] with input as bad
}
