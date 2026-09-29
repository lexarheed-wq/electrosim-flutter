#!/usr/bin/env python3
import json, subprocess, unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

class F0ToolingTests(unittest.TestCase):
    def test_required_files_exist(self):
        for rel in [
            "apps/electrosim/pubspec.yaml","apps/electrosim/lib/main.dart","apps/electrosim/test/f0_smoke_test.dart",
            "reference/REFERENCE_BASELINE.json",".github/workflows/f0-gate.yml","ci/TOOLCHAIN_PIN.md","ci/TOOLCHAIN_LOCK.json",
            "tools/validate_test_vectors.py","tools/generate_f0_manifest.py","tools/verify_f0_manifest.py","tools/verify_legacy_reference.py","tools/analyze_legacy_reference.py",
        ]: self.assertTrue((ROOT/rel).is_file(),rel)
    def test_reference_baseline_is_json(self):
        data=json.loads((ROOT/"reference/REFERENCE_BASELINE.json").read_text())
        self.assertIn("legacy_zip",data); self.assertEqual(len(data["legacy_zip"]["sha256"]),64)
    def test_toolchain_lock(self):
        d=json.loads((ROOT/"ci/TOOLCHAIN_LOCK.json").read_text())
        self.assertEqual(d["flutter"]["version"],"3.38.10")
        self.assertEqual(d["flutter"]["dartVersion"],"3.10.9")
        for a in d["archives"].values(): self.assertEqual(len(a["sha256"]),64)
    def test_ci_uses_locked_flutter(self):
        wf=(ROOT/".github/workflows/f0-gate.yml").read_text()
        self.assertIn("flutter-version: '3.38.10'",wf)
        self.assertIn("audit/runtime/f0_gate_runtime.json",wf)
        self.assertIn("audit/runtime/f0_gate.log",wf)
    def test_f0_guard_passes(self):
        p=subprocess.run(["python3",str(ROOT/"tools/f0_guard.py")],capture_output=True,text=True)
        self.assertEqual(p.returncode,0,p.stdout+p.stderr); self.assertEqual(json.loads(p.stdout)["status"],"PASS")
    def test_external_toolchain_js_is_ignored_by_guard(self):
        probe=ROOT/".toolchain"/"guard-regression"/"sdk_probe.js"
        probe.parent.mkdir(parents=True,exist_ok=True)
        probe.write_text("// external SDK fixture\n")
        try:
            p=subprocess.run(["python3",str(ROOT/"tools/f0_guard.py")],capture_output=True,text=True)
            self.assertEqual(p.returncode,0,p.stdout+p.stderr)
            data=json.loads(p.stdout)
            self.assertEqual(data["status"],"PASS")
            self.assertFalse(any(".toolchain" in e for e in data["errors"]))
        finally:
            probe.unlink(missing_ok=True)
            try: probe.parent.rmdir()
            except OSError: pass

    def test_authored_js_is_rejected_by_guard(self):
        probe=ROOT/"apps"/"electrosim"/"lib"/"guard_regression_legacy.js"
        probe.write_text("// authored JS must be rejected in F0\n")
        try:
            p=subprocess.run(["python3",str(ROOT/"tools/f0_guard.py")],capture_output=True,text=True)
            self.assertNotEqual(p.returncode,0,p.stdout+p.stderr)
            data=json.loads(p.stdout)
            self.assertIn("legacy-code-outside-reference:apps/electrosim/lib/guard_regression_legacy.js",data["errors"])
        finally:
            probe.unlink(missing_ok=True)

    def test_vectors_pass(self):
        p=subprocess.run(["python3",str(ROOT/"tools/validate_test_vectors.py")],capture_output=True,text=True)
        self.assertEqual(p.returncode,0,p.stdout+p.stderr); self.assertEqual(json.loads(p.stdout)["status"],"PASS")
    def test_manifest_passes(self):
        p=subprocess.run(["python3",str(ROOT/"tools/verify_f0_manifest.py")],capture_output=True,text=True)
        self.assertEqual(p.returncode,0,p.stdout+p.stderr)
    def test_legacy_analysis_is_present_and_verified(self):
        data=json.loads((ROOT/"audit/legacy_reference_analysis.json").read_text())
        self.assertEqual(data["status"],"PASS")
        self.assertGreaterEqual(data["archive"]["codeFileCount"],400)
        self.assertEqual(data["htmlEntrypoints"]["teacher.html"]["script_count"],137)
        self.assertEqual(data["htmlEntrypoints"]["student.html"]["script_count"],128)
        p=subprocess.run(["python3",str(ROOT/"tools/verify_legacy_reference.py")],capture_output=True,text=True)
        self.assertEqual(p.returncode,0,p.stdout+p.stderr)
    def test_bootstrap_is_isolated_and_checks_hash(self):
        s=(ROOT/"tools/bootstrap_flutter_and_run_f0.sh").read_text()
        self.assertNotIn(">> ~/.zprofile",s); self.assertNotIn(">> ~/.zshrc",s); self.assertNotIn(">> ~/.bashrc",s); self.assertIn(".toolchain",s); self.assertIn("SHA-256 mismatch",s)

    def test_gate_resolves_packages_before_format(self):
        s=(ROOT/"tools/run_f0_gate.sh").read_text()
        pub=s.index('run_step "flutter-pub-get" flutter pub get')
        fmt=s.index('run_step "dart-format" dart format --output=none --set-exit-if-changed lib test')
        self.assertLess(pub,fmt)

    def test_format_gate_is_scoped_to_authored_dart(self):
        s=(ROOT/"tools/run_f0_gate.sh").read_text()
        self.assertIn('dart format --output=none --set-exit-if-changed lib test',s)
        self.assertNotIn('dart format --output=none --set-exit-if-changed .',s)

    def test_no_f1_domain_source(self):
        domain=ROOT/"packages/electrosim_domain"
        self.assertEqual([p for p in domain.rglob('*') if p.is_file() and p.name!='README.md'],[])

if __name__=="__main__": unittest.main(verbosity=2)
