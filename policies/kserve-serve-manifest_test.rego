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

test_denies_missing_storage_uri {
	bad := json.patch(good, [{"op": "remove", "path": "/spec/predictor/model/storageUri"}])
	deny["model storageUri must be set"] with input as bad
}

test_denies_max_replicas_zero {
	bad := json.patch(good, [{"op": "replace", "path": "/spec/predictor/maxReplicas", "value": 0}])
	deny["maxReplicas must be at least 1"] with input as bad
}

test_denies_missing_max_replicas {
	bad := json.patch(good, [{"op": "remove", "path": "/spec/predictor/maxReplicas"}])
	deny["maxReplicas must be set"] with input as bad
}

test_denies_nonnumeric_max_replicas {
	bad := json.patch(good, [{"op": "replace", "path": "/spec/predictor/maxReplicas", "value": "many"}])
	deny["maxReplicas must be numeric"] with input as bad
}

test_denies_gpu_over_ceiling {
	bad := json.patch(good, [{"op": "replace", "path": "/metadata/annotations/kserve.poc~1gpu-count", "value": "8"}])
	deny["gpu_count 8 exceeds the team ceiling of 4"] with input as bad
}

test_denies_nonnumeric_gpu_count {
	bad := json.patch(good, [{"op": "replace", "path": "/metadata/annotations/kserve.poc~1gpu-count", "value": "many"}])
	deny["gpu_count must be numeric"] with input as bad
}

test_denies_missing_team {
	bad := json.patch(good, [{"op": "replace", "path": "/metadata/labels/team", "value": ""}])
	deny["team tag is required"] with input as bad
}

test_denies_wrong_kind {
	deny["payload must be an InferenceService"] with input as {"kind": "Deployment"}
}
