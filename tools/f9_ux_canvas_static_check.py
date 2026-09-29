#!/usr/bin/env python3
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
main = (root / 'apps/electrosim/lib/main.dart').read_text(encoding='utf-8')
interaction = (root / 'apps/electrosim/lib/f9_canvas_interaction.dart').read_text(encoding='utf-8')
gate = (root / 'tools/run_f9_final_gate.sh').read_text(encoding='utf-8')
visual = (root / 'run_visual.sh').read_text(encoding='utf-8')
test = (root / 'apps/electrosim/test/f9_canvas_interaction_test.dart').read_text(encoding='utf-8')

checks = {
    'canvas ClipRect': 'return ClipRect(' in main,
    'trackpad pan/zoom start handler': 'onPointerPanZoomStart: _onCanvasPointerPanZoomStart' in main,
    'trackpad pan/zoom update handler': 'onPointerPanZoomUpdate: _onCanvasPointerPanZoomUpdate' in main,
    'trackpad pan/zoom end handler': 'onPointerPanZoomEnd: _onCanvasPointerPanZoomEnd' in main,
    'pinch uses cumulative event scale': 'final double cumulativeScale = event.scale;' in main,
    'trackpad pan uses local delta': 'event.localPanDelta' in main,
    'pinch zoom anchored at gesture location': '_viewport.zoomAt(event.localPosition, factor);' in main,
    'two-finger scroll pans canvas': '_viewport.translation - event.scrollDelta' in main,
    'viewport is clamped after zoom': '_clampCurrentViewport();' in main,
    'orthogonal router clearance': 'static const double clearance = 24;' in interaction,
    'router bend penalty': '_bendPenalty' in interaction,
    'router crossing penalty': '_wireCrossPenalty' in interaction,
    'router obstacle channels': 'for (final Rect rect in obstacles) rect.left - 8' in interaction,
    'UX canvas tests included in gate': 'test/f9_canvas_interaction_test.dart' in gate,
    'router clearance regression test': 'keeps configured clearance from an intermediate component' in test,
    'router short path regression test': 'prefers the shortest one-bend path when unobstructed' in test,
    'max zoom viewport recovery regression test': 'remain recoverable at maximum zoom in every direction' in test,
    'pre-gate visual validation mode': '--pre-gate' in visual and 'F9 visual pre-validation mode' in visual,
}
failed = [name for name, ok in checks.items() if not ok]
if failed:
    print('F9_UX_CANVAS_STATIC_FAIL')
    for item in failed:
        print(f'- {item}')
    sys.exit(1)
print(f'F9_UX_CANVAS_STATIC_PASS ({len(checks)}/{len(checks)})')
