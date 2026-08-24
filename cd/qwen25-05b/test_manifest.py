#!/usr/bin/env python3
"""Contract tests for the CD twin InferenceService."""
from pathlib import Path
import unittest

try:
    import yaml
except ImportError:
    raise SystemExit("PyYAML required: pip3 install pyyaml")

MANIFEST = Path(__file__).with_name("inferenceservice.yaml")


class TestCdTwinManifest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.doc = yaml.safe_load(MANIFEST.read_text())

    def test_kind_and_name(self):
        self.assertEqual(self.doc["apiVersion"], "serving.kserve.io/v1beta1")
        self.assertEqual(self.doc["kind"], "InferenceService")
        self.assertEqual(self.doc["metadata"]["name"], "qwen25-05b-cd")
        self.assertEqual(self.doc["metadata"]["namespace"], "kserve-m0")

    def test_does_not_collide_with_iacm_name(self):
        self.assertNotEqual(self.doc["metadata"]["name"], "qwen25-05b")

    def test_labels(self):
        labels = self.doc["metadata"]["labels"]
        self.assertEqual(labels["app.kubernetes.io/part-of"], "kserve-iacm-poc")
        self.assertEqual(labels["app.kubernetes.io/managed-by"], "harness-cd")
        self.assertEqual(labels["team"], "ml-platform")
        self.assertEqual(labels["cost_center"], "kserve-poc")

    def test_gpu_annotations(self):
        ann = self.doc["metadata"]["annotations"]
        self.assertEqual(ann["kserve.poc/gpu-count"], "0")
        self.assertEqual(ann["kserve.poc/gpu-type"], "l4")

    def test_predictor(self):
        pred = self.doc["spec"]["predictor"]
        self.assertEqual(pred["minReplicas"], 1)
        self.assertEqual(pred["maxReplicas"], 1)
        model = pred["model"]
        self.assertEqual(model["modelFormat"]["name"], "huggingface")
        self.assertEqual(model["args"], ["--backend=huggingface"])
        self.assertEqual(model["storageUri"], "hf://Qwen/Qwen2.5-0.5B-Instruct")
        self.assertEqual(model["resources"]["requests"], {"cpu": "2", "memory": "8Gi"})
        self.assertEqual(model["resources"]["limits"], {"cpu": "4", "memory": "12Gi"})


if __name__ == "__main__":
    unittest.main()
