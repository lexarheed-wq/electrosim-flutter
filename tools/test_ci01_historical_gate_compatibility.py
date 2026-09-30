#!/usr/bin/env python3
import json
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class CI01HistoricalGateCompatibilityTests(unittest.TestCase):
    def _run_guard(self):
        return subprocess.run(
            ["python3", str(ROOT / "tools" / "f0_guard.py")],
            capture_output=True,
            text=True,
        )

    def test_post_f0_dart_packages_are_allowed_by_f0_regression_guard(self):
        domain_files = [
            p for p in (ROOT / "packages" / "electrosim_domain").rglob("*.dart")
            if p.is_file()
        ]
        scenario_files = [
            p for p in (ROOT / "packages" / "electrosim_scenarios").rglob("*.dart")
            if p.is_file()
        ]
        self.assertTrue(domain_files, "expected qualified post-F0 domain Dart sources")
        self.assertTrue(scenario_files, "expected qualified post-F0 scenario Dart sources")

        result = self._run_guard()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        data = json.loads(result.stdout)
        self.assertEqual(data["status"], "PASS")
        self.assertFalse(
            any(error.startswith("scenario-content-in-f0:") for error in data["errors"]),
            data["errors"],
        )

    def test_authored_legacy_js_is_still_rejected(self):
        probe = ROOT / "packages" / "electrosim_scenarios" / "ci01_legacy_probe.js"
        probe.write_text("// CI01 regression probe\n", encoding="utf-8")
        try:
            result = self._run_guard()
            self.assertNotEqual(result.returncode, 0)
            data = json.loads(result.stdout)
            expected = (
                "legacy-code-outside-reference:"
                "packages/electrosim_scenarios/ci01_legacy_probe.js"
            )
            self.assertIn(expected, data["errors"])
        finally:
            probe.unlink(missing_ok=True)


    def test_historical_gates_generate_legacy_audit_before_verifying_it(self):
        for script_name in (
            "run_f0_gate.sh",
            "run_f1_gate.sh",
            "run_f2_gate.sh",
            "run_f3_gate.sh",
        ):
            script = (ROOT / "tools" / script_name).read_text(encoding="utf-8")
            analyze = script.find("analyze_legacy_reference.py")
            verify = script.find("verify_legacy_reference.py")
            self.assertGreaterEqual(analyze, 0, f"{script_name} must generate the legacy audit")
            self.assertGreater(verify, analyze, f"{script_name} must analyze before verify")


    def test_f0_and_f1_refresh_their_historical_manifests_before_verifying(self):
        expectations = {
            "run_f0_gate.sh": ("generate_f0_manifest.py", "verify_f0_manifest.py"),
            "run_f1_gate.sh": ("generate_f1_manifest.py", "verify_f1_manifest.py"),
        }
        for script_name, (generate_name, verify_name) in expectations.items():
            script = (ROOT / "tools" / script_name).read_text(encoding="utf-8")
            generate = script.find(generate_name)
            verify = script.find(verify_name)
            self.assertGreaterEqual(generate, 0, f"{script_name} must refresh its manifest")
            self.assertGreater(verify, generate, f"{script_name} must refresh before verify")


    def test_f0_and_f1_normalize_inherited_app_dart_before_strict_format_check(self):
        for script_name in ("run_f0_gate.sh", "run_f1_gate.sh"):
            script = (ROOT / "tools" / script_name).read_text(encoding="utf-8")
            normalize = script.find('dart-format-normalize" dart format lib test')
            strict = script.find('dart format --output=none --set-exit-if-changed lib test')
            self.assertGreaterEqual(
                normalize, 0, f"{script_name} must normalize inherited app Dart"
            )
            self.assertGreater(
                strict, normalize, f"{script_name} must normalize before strict check"
            )


    def test_completed_f18_g0_gate_is_not_a_global_pull_request_gate(self):
        workflow = (
            ROOT / ".github" / "workflows" / "f18-g0-baseline-inventory.yml"
        ).read_text(encoding="utf-8")
        self.assertNotIn(
            "pull_request:",
            workflow,
            "completed G0 phase gate must not reject unrelated future PRs",
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
