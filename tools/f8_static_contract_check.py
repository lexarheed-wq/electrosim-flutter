#!/usr/bin/env python3
from __future__ import annotations
import json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
files={
 'canvas':ROOT/'packages/electrosim_canvas/lib/src/simulator_canvas.dart',
 'painter':ROOT/'packages/electrosim_canvas/lib/src/circuit_scene_painter.dart',
 'viewport':ROOT/'packages/electrosim_canvas/lib/src/viewport_controller.dart',
 'hit':ROOT/'packages/electrosim_canvas/lib/src/hit_test_engine.dart',
 'layout':ROOT/'packages/electrosim_canvas/lib/src/circuit_visual_layout.dart',
 'gesture_tests':ROOT/'packages/electrosim_canvas/test/simulator_canvas_test.dart',
 'golden_tests':ROOT/'packages/electrosim_canvas/test/simulator_canvas_golden_test.dart',
 'perf_tests':ROOT/'packages/electrosim_canvas/test/canvas_performance_test.dart',
 'contract':ROOT/'docs/f8/F8_CONTRACT.md',
 'gate':ROOT/'tools/run_f8_gate.sh',
 'visual':ROOT/'run_visual.sh',
 'quick':ROOT/'validate_f8_quick.sh',
 'review':ROOT/'review_f8_goldens.sh',
 'golden_approve':ROOT/'tools/approve_f8_goldens.py',
 'golden_verify':ROOT/'tools/verify_f8_golden_baseline.py',
 'deep_audit':ROOT/'docs/f8/F8_DEEP_AUDIT_R7.md',
 'physical_checklist':ROOT/'docs/f8/F8_PHYSICAL_VALIDATION_CHECKLIST.md',
 'f9_prep':ROOT/'docs/f9/F9_PREPARATION_STATUS.md',
}
errors=[]
for name,path in files.items():
    if not path.is_file() or path.stat().st_size==0: errors.append(f'missing:{name}')
if not errors:
    canvas=files['canvas'].read_text(encoding='utf-8')
    painter=files['painter'].read_text(encoding='utf-8')
    viewport=files['viewport'].read_text(encoding='utf-8')
    hit=files['hit'].read_text(encoding='utf-8')
    layout=files['layout'].read_text(encoding='utf-8')
    gestures=files['gesture_tests'].read_text(encoding='utf-8')
    goldens=files['golden_tests'].read_text(encoding='utf-8')
    perf=files['perf_tests'].read_text(encoding='utf-8')
    gate=files['gate'].read_text(encoding='utf-8')
    visual=files['visual'].read_text(encoding='utf-8')
    quick=files['quick'].read_text(encoding='utf-8')
    review=files['review'].read_text(encoding='utf-8')
    approve=files['golden_approve'].read_text(encoding='utf-8')
    verify=files['golden_verify'].read_text(encoding='utf-8')
    for token in ['final class SimulatorCanvas','onTapUp','onLongPressStart','onLongPressMoveUpdate','onScaleUpdate','_maybeEmitContextDoubleTap','PointerScrollEvent','onConnectionRequested']:
        if token not in canvas: errors.append(f'canvas-contract-missing:{token}')
    if "import 'package:flutter/gestures.dart';" not in canvas:
        errors.append('canvas-missing-explicit-gestures-import')
    if "import 'package:flutter/gestures.dart';" not in gestures:
        errors.append('gesture-test-missing-explicit-gestures-import')
    # R5: do not use GestureDetector's built-in double-tap recognizer. On the
    # pinned Flutter 3.38 toolchain it delays single-click selection and leaves
    # a recognition timer alive during short widget tests. Context double-click
    # detection is implemented explicitly after the normal tap action.
    if 'onDoubleTap:' in canvas or 'onDoubleTapDown:' in canvas:
        errors.append('canvas-built-in-double-tap-recognizer-forbidden-r5')
    for token in ['_contextDoubleTapWindow','_contextDoubleTapDistance','_resetContextTapTracking']:
        if token not in canvas: errors.append(f'canvas-r5-double-tap-contract-missing:{token}')
    if gestures.count('await tester.pumpAndSettle();') < 3:
        errors.append('gesture-tests-must-settle-after-single-tap-drag-and-double-tap')
    # Flutter 3.38.10 / Dart 3.10.9: PointerScrollEvent does not expose a
    # named `pointer` constructor argument. Keep the Monterey fixture on the
    # public constructor contract used by the pinned toolchain.
    if 'pointer: 1,' in gestures:
        errors.append('gesture-test-uses-unsupported-pointer-scroll-pointer-argument')
    api_file=(ROOT/'packages/electrosim_canvas/lib/electrosim_canvas.dart').read_text(encoding='utf-8')
    if api_file.lstrip().startswith('library '):
        errors.append('public-api-unnecessary-library-directive')
    for rel in ['hit_test_engine_test.dart','viewport_controller_test.dart']:
        test_text=(ROOT/'packages/electrosim_canvas/test'/rel).read_text(encoding='utf-8')
        if "import 'dart:ui';" in test_text:
            errors.append(f'unnecessary-dart-ui-import:{rel}')
    for token in ['final class CircuitScenePainter','CircuitGeometryIndex.build','_paintWires','_paintTerminals']:
        if token not in painter: errors.append(f'painter-contract-missing:{token}')
    for token in ['final class ViewportController','worldToScreen','screenToWorld','zoomAt','panBy']:
        if token not in viewport: errors.append(f'viewport-contract-missing:{token}')
    for token in ['final class HitTestEngine','CanvasHitKind.terminal','CanvasHitKind.wire','_distanceToSegment','viewportScale','terminalWorldRadius','wireWorldTolerance']:
        if token not in hit: errors.append(f'hit-contract-missing:{token}')
    for token in ['final class CircuitVisualLayout','elementPositions','wireRoutes','moveElement']:
        if token not in layout: errors.append(f'layout-contract-missing:{token}')
    for token in ['click selects component without moving it','long press plus drag requests a graphical move','two terminal taps request a connection and do not mutate CircuitState','background drag pans viewport','double tap on a component emits contextual action','background tap cancels pending wiring','clicking a wire selects its connection id','wheel zoom changes viewport']:
        if token not in gestures: errors.append(f'gesture-test-missing:{token}')
    for token in ['canvas_compact.png','canvas_medium.png','canvas_expanded.png','matchesGoldenFile']:
        if token not in goldens: errors.append(f'golden-test-missing:{token}')
    for token in ['60 fps frame budget','16667','F8_PERF_JSON']:
        if token not in perf: errors.append(f'performance-test-missing:{token}')
    for token in ['--update-goldens','F8_GATE_PASS','F8_GATE_GOLDEN_REVIEW_REQUIRED','f8-golden-verify','f8-performance','legacy-reference-analysis','analyze_legacy_reference.py','legacy-reference','verify_f8_golden_baseline.py']:
        if token not in gate: errors.append(f'gate-contract-missing:{token}')
    for token in ['GOLDEN_REVIEW_REQUIRED','automatedChecksPassed','python3 tools/approve_f8_goldens.py --approve']:
        if token not in gate: errors.append(f'gate-review-contract-missing:{token}')
    if 'flutter create --platforms=macos --project-name electrosim .' not in visual:
        errors.append('visual-runner-missing-disposable-macos-scaffold')
    for token in ['mktemp -d','GOLDEN_REVIEW_REQUIRED','Source candidate remains untouched','flutter run -d macos']:
        if token not in visual: errors.append(f'visual-runner-contract-missing:{token}')
    if 'F8_QUICK_CHECK_PASS (not an official phase gate)' not in quick:
        errors.append('quick-check-must-declare-non-official-status')
    for token in ['canvas_compact.png','canvas_medium.png','canvas_expanded.png','approve_f8_goldens.py --approve']:
        if token not in review: errors.append(f'golden-review-helper-missing:{token}')
    if '--approve' not in approve or 'APPROVED' not in approve:
        errors.append('golden-approval-must-require-explicit-approval')
    for token in ['golden-hash-mismatch','baseline-not-approved','canvas_compact.png','canvas_medium.png','canvas_expanded.png']:
        if token not in verify: errors.append(f'golden-baseline-verifier-missing:{token}')

    geometry=(ROOT/'packages/electrosim_canvas/lib/src/canvas_geometry.dart').read_text(encoding='utf-8')
    if 'globally unique visual IDs across sources, components, and connections' not in geometry:
        errors.append('canvas-visual-id-collision-guard-missing')
    if 'selected ? selectionColor : _phaseColor(connection.phase)' not in painter:
        errors.append('selected-wire-feedback-missing')
    if '_pendingTerminalId = null;' not in canvas or '_pointerWorldPosition = null;' not in canvas:
        errors.append('wiring-cancel-cleanup-missing')
    hit_tests=(ROOT/'packages/electrosim_canvas/test/hit_test_engine_test.dart').read_text(encoding='utf-8')
    for token in ['screen-stable across zoom','cross-type visual id collision fails explicitly','element and connection visual id collision fails explicitly']:
        if token not in hit_tests: errors.append(f'r7-hit-test-missing:{token}')
    for doc in ('docs/f8/F8_DEEP_AUDIT_R7.md','docs/f8/F8_PHYSICAL_VALIDATION_CHECKLIST.md','docs/f9/F9_PREPARATION_STATUS.md','docs/f9/F9_DESIGN_SYSTEM_SPEC.md','docs/f9/F9_RESPONSIVE_LAYOUT_SPEC.md','docs/f9/F9_COMPONENT_VISUAL_LANGUAGE.md','docs/f9/F9_ACCESSIBILITY_AND_INPUT_SPEC.md','docs/f9/F9_GOLDEN_AND_ACCEPTANCE_PLAN.md','docs/f9/F9_IMPLEMENTATION_PLAN.md'):
        path=ROOT/doc
        if not path.is_file() or path.stat().st_size == 0: errors.append(f'r7-preparation-doc-missing:{doc}')
    analysis_pos = gate.find('legacy-reference-analysis')
    verify_pos = gate.find('run_step "legacy-reference"')
    if analysis_pos < 0 or verify_pos < 0 or analysis_pos > verify_pos:
        errors.append('legacy-analysis-must-run-before-verification')
result={'phase':'F8','status':'PASS' if not errors else 'FAIL','errors':errors}
print(json.dumps(result,indent=2,ensure_ascii=False)); sys.exit(0 if not errors else 1)
