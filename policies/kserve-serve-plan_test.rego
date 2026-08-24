package terraform_plan

test_allows_qwen_cpu {
	count(deny) == 0 with input as {"variables": {
		"model_uri": {"value": "hf://Qwen/Qwen2.5-0.5B-Instruct"},
		"max_replicas": {"value": 1},
		"gpu_count": {"value": 0},
		"team": {"value": "ml-platform"},
		"cost_center": {"value": "kserve-poc"},
	}}
}

test_denies_unlisted_model {
	deny["model_uri \"hf://evil/model\" is not on the serve allowlist"] with input as {"variables": {
		"model_uri": {"value": "hf://evil/model"},
		"max_replicas": {"value": 1},
		"gpu_count": {"value": 0},
		"team": {"value": "ml-platform"},
		"cost_center": {"value": "kserve-poc"},
	}}
}

test_denies_gpu_over_ceiling {
	deny["gpu_count 8 exceeds the team ceiling of 4"] with input as {"variables": {
		"model_uri": {"value": "hf://Qwen/Qwen2.5-0.5B-Instruct"},
		"max_replicas": {"value": 1},
		"gpu_count": {"value": "8"},
		"team": {"value": "ml-platform"},
		"cost_center": {"value": "kserve-poc"},
	}}
}

test_denies_missing_team {
	deny["team tag is required"] with input as {"variables": {
		"model_uri": {"value": "hf://Qwen/Qwen2.5-0.5B-Instruct"},
		"max_replicas": {"value": 1},
		"gpu_count": {"value": 0},
		"team": {"value": ""},
		"cost_center": {"value": "kserve-poc"},
	}}
}
