#!/usr/bin/env python3
from __future__ import annotations
import json, subprocess, unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]

class F8R7ToolingTests(unittest.TestCase):
    def test_deep_audit_passes_and_keeps_f9_closed(self):
        proc=subprocess.run(['python3',str(ROOT/'tools/f8_deep_static_audit.py')],capture_output=True,text=True)
        self.assertEqual(proc.returncode,0,msg=proc.stderr+proc.stdout)
        payload=json.loads(proc.stdout)
        self.assertEqual(payload['status'],'PASS')
        self.assertFalse(payload['f9ImplementationOpened'])
        for check_id in ('F8-A01','F8-A02','F8-A03','F8-A04'):
            self.assertIn(check_id,{item['id'] for item in payload['checks']})

    def test_f9_folder_contains_specs_only(self):
        f9=ROOT/'docs/f9'
        self.assertTrue(f9.is_dir())
        names={p.name for p in f9.iterdir() if p.is_file()}
        required={
            'F9_PREPARATION_STATUS.md','F9_DESIGN_SYSTEM_SPEC.md','F9_RESPONSIVE_LAYOUT_SPEC.md',
            'F9_COMPONENT_VISUAL_LANGUAGE.md','F9_ACCESSIBILITY_AND_INPUT_SPEC.md',
            'F9_GOLDEN_AND_ACCEPTANCE_PLAN.md','F9_IMPLEMENTATION_PLAN.md',
        }
        self.assertTrue(required.issubset(names))
        ui_kit=ROOT/'packages/electrosim_ui_kit'
        self.assertFalse((ui_kit/'pubspec.yaml').exists())
        self.assertFalse((ui_kit/'lib').exists())

    def test_r7_interaction_contracts_are_present(self):
        canvas=(ROOT/'packages/electrosim_canvas/lib/src/simulator_canvas.dart').read_text(encoding='utf-8')
        hit=(ROOT/'packages/electrosim_canvas/lib/src/hit_test_engine.dart').read_text(encoding='utf-8')
        painter=(ROOT/'packages/electrosim_canvas/lib/src/circuit_scene_painter.dart').read_text(encoding='utf-8')
        geometry=(ROOT/'packages/electrosim_canvas/lib/src/canvas_geometry.dart').read_text(encoding='utf-8')
        self.assertIn('viewportScale: _viewport.scale',canvas)
        self.assertIn('terminalWorldRadius',hit)
        self.assertIn('_pointerWorldPosition = null;',canvas)
        self.assertIn('selected ? selectionColor',painter)
        self.assertIn('globally unique visual IDs across sources, components, and connections',geometry)

if __name__=='__main__':
    unittest.main(verbosity=2)
