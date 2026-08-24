package terraform_plan

# Evaluated by IaCM after plan (policy set type terraformPlan / afterTerraformPlan).
# Uses root-module variables from stacks/fraud-llm-staging.

allowed_model_uris := {
	"hf://Qwen/Qwen2.5-0.5B-Instruct",
}

gpu_count_ceiling := 4

var_value(name) := object.get(object.get(input, "variables", {}), name, {}).value

deny[msg] {
	model := var_value("model_uri")
	model != null
	not allowed_model_uris[model]
	msg := sprintf("model_uri %q is not on the serve allowlist", [model])
}

deny[msg] {
	var_value("model_uri") == null
	msg := "model_uri must be set"
}

deny[msg] {
	max := var_value("max_replicas")
	max == null
	msg := "max_replicas must be set"
}

deny[msg] {
	max := var_value("max_replicas")
	max != null
	to_number(max) < 1
	msg := "max_replicas must be at least 1"
}

deny[msg] {
	gpus := var_value("gpu_count")
	gpus != null
	to_number(gpus) > gpu_count_ceiling
	msg := sprintf("gpu_count %v exceeds the team ceiling of %v", [gpus, gpu_count_ceiling])
}

deny[msg] {
	not nonempty(var_value("team"))
	msg := "team tag is required"
}

deny[msg] {
	not nonempty(var_value("cost_center"))
	msg := "cost_center tag is required"
}

nonempty(x) {
	x != null
	x != ""
}
