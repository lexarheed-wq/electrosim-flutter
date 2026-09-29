#!/usr/bin/env python3
from __future__ import annotations
import json, subprocess, tempfile, unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

class F8R6ToolingTests(unittest.TestCase):
    def test_gate_requires_golden_review_before_pass(self):
        text=(ROOT/'tools/run_f8_gate.sh').read_text(encoding='utf-8')
        self.assertIn('F8_GATE_GOLDEN_REVIEW_REQUIRED', text)
        self.assertIn('GOLDEN_REVIEW_REQUIRED', text)
        self.assertIn('verify_f8_golden_baseline.py', text)
        self.assertIn('exit 42', text)

    def test_approval_requires_explicit_flag(self):
        proc=subprocess.run(
            ['python3', str(ROOT/'tools/approve_f8_goldens.py')],
            capture_output=True, text=True,
        )
        self.assertEqual(proc.returncode, 2)
        self.assertIn('--approve', proc.stderr)

    def test_baseline_verifier_fails_without_approval(self):
        baseline=ROOT/'docs/f8/F8_GOLDEN_BASELINE.json'
        backup=baseline.read_bytes() if baseline.exists() else None
        try:
            if baseline.exists(): baseline.unlink()
            proc=subprocess.run(
                ['python3', str(ROOT/'tools/verify_f8_golden_baseline.py')],
                capture_output=True, text=True,
            )
            self.assertNotEqual(proc.returncode, 0)
            payload=json.loads(proc.stdout)
            self.assertIn('baseline-not-approved', payload['errors'])
        finally:
            if backup is not None: baseline.write_bytes(backup)

    def test_visual_runner_uses_disposable_copy(self):
        text=(ROOT/'run_visual.sh').read_text(encoding='utf-8')
        self.assertIn('mktemp -d', text)
        self.assertIn('cp -R "$ROOT/apps/electrosim"', text)
        self.assertIn('Source candidate remains untouched', text)
        self.assertNotIn('flutter create --platforms=macos .\n', text)

    def test_review_helper_mentions_all_three_goldens(self):
        text=(ROOT/'review_f8_goldens.sh').read_text(encoding='utf-8')
        for name in ('canvas_compact.png','canvas_medium.png','canvas_expanded.png'):
            self.assertIn(name,text)
        self.assertIn('approve_f8_goldens.py --approve',text)

    def test_quick_check_is_explicitly_non_gate(self):
        text=(ROOT/'validate_f8_quick.sh').read_text(encoding='utf-8')
        self.assertIn('not an official phase gate', text)

    def test_shell_scripts_parse(self):
        for name in ('validate.sh','validate_f8_quick.sh','run_visual.sh','review_f8_goldens.sh','tools/run_f8_gate.sh','tools/bootstrap_flutter_and_run_f8.sh','tools/bootstrap_flutter_f8_fallback.sh'):
            proc=subprocess.run(['bash','-n',str(ROOT/name)],capture_output=True,text=True)
            self.assertEqual(proc.returncode,0,msg=f'{name}: {proc.stderr}')

if __name__ == '__main__':
    unittest.main(verbosity=2)
