#!/usr/bin/env python3
from pathlib import Path
import unittest
import yaml

ROOT = Path(__file__).resolve().parent


class TestHarnessCdIds(unittest.TestCase):
    def test_service_id(self):
        d = yaml.safe_load((ROOT / "service-qwen2505bcd.yaml").read_text())
        self.assertEqual(d["service"]["identifier"], "qwen2505bcd")
        self.assertEqual(d["service"]["serviceDefinition"]["type"], "Kubernetes")
        spec = d["service"]["serviceDefinition"]["spec"]["manifests"][0]["manifest"]["spec"]
        self.assertEqual(
            spec["store"]["spec"]["paths"],
            ["cd/qwen25-05b/inferenceservice.yaml"],
        )

    def test_env_and_infra(self):
        env = yaml.safe_load((ROOT / "environment-kservestaging.yaml").read_text())
        inf = yaml.safe_load((ROOT / "infrastructure-kservem0.yaml").read_text())
        self.assertEqual(env["environment"]["identifier"], "kservestaging")
        self.assertEqual(env["environment"]["type"], "PreProduction")
        self.assertEqual(inf["infrastructureDefinition"]["identifier"], "kservem0")
        self.assertEqual(inf["infrastructureDefinition"]["environmentRef"], "kservestaging")
        self.assertEqual(inf["infrastructureDefinition"]["spec"]["namespace"], "kserve-m0")
        self.assertEqual(inf["infrastructureDefinition"]["spec"]["connectorRef"], "iacteamstandard")

    def test_pipeline_steps(self):
        p = yaml.safe_load((ROOT.parent / "pipelines" / "model-cd-deploy.yaml").read_text())
        self.assertEqual(p["pipeline"]["identifier"], "modelcddeploy")
        steps = p["pipeline"]["stages"][0]["stage"]["spec"]["execution"]["steps"]
        types = [s["step"]["type"] for s in steps]
        self.assertEqual(types, ["HarnessApproval", "K8sApply"])
        apply = steps[1]["step"]["spec"]
        self.assertTrue(apply["skipSteadyStateCheck"])
        self.assertEqual(
            apply["filePaths"],
            ["cd/qwen25-05b/inferenceservice.yaml"],
        )


if __name__ == "__main__":
    unittest.main()
