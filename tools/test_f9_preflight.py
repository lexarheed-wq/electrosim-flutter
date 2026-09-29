#!/usr/bin/env python3
from __future__ import annotations
import csv, shutil, subprocess, tempfile, unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
class TestF9Preflight(unittest.TestCase):
    def test_live_candidate_passes(self):
        r=subprocess.run(['python3',str(ROOT/'tools/f9_preflight_check.py')],cwd=ROOT,text=True,capture_output=True)
        self.assertEqual(r.returncode,0,r.stdout+r.stderr)
        self.assertIn('"status": "PASS"',r.stdout)
    def test_no_dart_ui_kit_sources_yet(self):
        self.assertEqual(list((ROOT/'packages/electrosim_ui_kit').rglob('*.dart')),[])
    def test_legacy_taxonomy_is_reference_only(self):
        with (ROOT/'docs/f9/F9_LEGACY_VISUAL_TAXONOMY.csv').open(encoding='utf-8') as f:
            rows=list(csv.DictReader(f))
        self.assertTrue(rows)
        self.assertTrue(all(r['automatic_import']=='NO' for r in rows))
if __name__=='__main__': unittest.main()
