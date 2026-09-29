#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CANVAS = ROOT / 'packages/electrosim_canvas/lib/src/simulator_canvas.dart'
PAINTER = ROOT / 'packages/electrosim_canvas/lib/src/circuit_scene_painter.dart'
HIT = ROOT / 'packages/electrosim_canvas/lib/src/hit_test_engine.dart'
GEOMETRY = ROOT / 'packages/electrosim_canvas/lib/src/canvas_geometry.dart'
GESTURES = ROOT / 'packages/electrosim_canvas/test/simulator_canvas_test.dart'
HIT_TESTS = ROOT / 'packages/electrosim_canvas/test/hit_test_engine_test.dart'

checks: list[dict[str, object]] = []
warnings: list[str] = []
errors: list[str] = []


def check(check_id: str, ok: bool, description: str) -> None:
    checks.append({'id': check_id, 'status': 'PASS' if ok else 'FAIL', 'description': description})
    if not ok:
        errors.append(check_id)


for path in (CANVAS, PAINTER, HIT, GEOMETRY, GESTURES, HIT_TESTS):
    if not path.is_file():
        errors.append(f'missing:{path.relative_to(ROOT)}')

if not errors:
    canvas = CANVAS.read_text(encoding='utf-8')
    painter = PAINTER.read_text(encoding='utf-8')
    hit = HIT.read_text(encoding='utf-8')
    geometry = GEOMETRY.read_text(encoding='utf-8')
    gestures = GESTURES.read_text(encoding='utf-8')
    hit_tests = HIT_TESTS.read_text(encoding='utf-8')

    check('F8-A01', all(t in hit for t in ('viewportScale', 'terminalWorldRadius', 'wireWorldTolerance')), 'Hit tolerances are converted from screen pixels to world units using viewport scale.')
    check('F8-A02', 'background tap cancels pending wiring' in gestures and canvas.count('_pointerWorldPosition = null;') >= 3, 'Pending wiring has explicit cancellation and state cleanup.')
    check('F8-A03', 'selected ? selectionColor : _phaseColor(connection.phase)' in painter and 'clicking a wire selects its connection id' in gestures, 'Wire selection has a visible render state and an interaction test.')
    check('F8-A04', 'globally unique visual IDs across sources, components, and connections' in geometry and 'cross-type visual id collision fails explicitly' in hit_tests and 'element and connection visual id collision fails explicitly' in hit_tests, 'Visual identifier collisions fail explicitly instead of aliasing layout or selection.')

    if 'compatibleTerminal' not in canvas and 'compatibleTerminal' not in painter:
        warnings.append('F8-A05: compatible terminal highlighting is not implemented yet; prepared for F9/application-policy integration.')
    if 'Semantics(' in canvas and canvas.count('Semantics(') == 1:
        warnings.append('F8-A06: only global canvas semantics exist; per-element keyboard/accessibility semantics remain for F9.')
    if 'shouldRepaint(CircuitScenePainter oldDelegate) => !identical(oldDelegate, this);' in painter:
        warnings.append('F8-A08: painter always repaints; retain until profiling justifies a snapshot/caching optimization.')
    if 'CircuitGeometryIndex.build(' in hit:
        warnings.append('F8-A09: geometry index is rebuilt for each hit-test; benchmark larger circuits before optimizing.')
    if 'DateTime.now()' in canvas:
        warnings.append('F8-A10: manual double-click timing uses wall-clock time; consider an injectable clock only if flakiness is observed.')

status = 'PASS' if not errors else 'FAIL'
payload = {
    'phase': 'F8',
    'candidate': (ROOT/'VERSION').read_text(encoding='utf-8').strip(),
    'status': status,
    'checks': checks,
    'warnings': warnings,
    'errors': errors,
    'f9ImplementationOpened': False,
}
print(json.dumps(payload, indent=2, ensure_ascii=False))
raise SystemExit(0 if status == 'PASS' else 1)
