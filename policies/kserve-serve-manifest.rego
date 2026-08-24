package custom

# Evaluated by a Harness Custom Policy step. Payload is the InferenceService
# object, optionally wrapped as {"manifest": {...}}.

allowed_model_uris := {
	"hf://Qwen/Qwen2.5-0.5B-Instruct",
}

gpu_count_ceiling := 4

doc := input.manifest {
	input.manifest.kind == "InferenceService"
}

doc := input {
	not input.manifest
	input.kind == "InferenceService"
}

predictor := object.get(object.get(doc, "spec", {}), "predictor", {})

model := object.get(predictor, "model", {})

storage_uri := object.get(model, "storageUri", null)

max_replicas := object.get(predictor, "maxReplicas", null)

gpu_count_raw := object.get(object.get(doc.metadata, "annotations", {}), "kserve.poc/gpu-count", "0")

team := object.get(object.get(doc.metadata, "labels", {}), "team", "")

cost_center := object.get(object.get(doc.metadata, "labels", {}), "cost_center", "")

deny[msg] {
	not doc
	msg := "payload must be an InferenceService"
}

deny[msg] {
	doc
	doc.metadata.name == "qwen25-05b"
	msg := "CD must not apply InferenceService name \"qwen25-05b\" (owned by IaCM)"
}

deny[msg] {
	doc
	storage_uri == null
	msg := "model storageUri must be set"
}

deny[msg] {
	doc
	storage_uri != null
	not allowed_model_uris[storage_uri]
	msg := sprintf("model storageUri %q is not on the serve allowlist", [storage_uri])
}

deny[msg] {
	doc
	max_replicas == null
	msg := "maxReplicas must be set"
}

deny[msg] {
	doc
	max_replicas != null
	not numeric(max_replicas)
	msg := "maxReplicas must be numeric"
}

deny[msg] {
	doc
	max_replicas != null
	numeric(max_replicas)
	to_number(max_replicas) < 1
	msg := "maxReplicas must be at least 1"
}

deny[msg] {
	doc
	not numeric(gpu_count_raw)
	msg := "gpu_count must be numeric"
}

deny[msg] {
	doc
	numeric(gpu_count_raw)
	to_number(gpu_count_raw) > gpu_count_ceiling
	msg := sprintf("gpu_count %v exceeds the team ceiling of %v", [to_number(gpu_count_raw), gpu_count_ceiling])
}

deny[msg] {
	doc
	not nonempty(team)
	msg := "team tag is required"
}

deny[msg] {
	doc
	not nonempty(cost_center)
	msg := "cost_center tag is required"
}

nonempty(x) {
	x != null
	x != ""
}

numeric(x) {
	is_number(x)
}

numeric(x) {
	is_string(x)
	to_number(x)
}
