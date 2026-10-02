import 'dart:ui' as ui;

import 'package:electrosim/f18_magicpath_parity.dart';
import 'package:electrosim/main.dart' as app;
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MagicPath qualified references remain immutable and traceable', () {
    expect(F18MagicPathReferences.projectId, '456415562449448960');
    expect(F18MagicPathReferences.homeDesktop.size, const Size(1440, 900));
    expect(
      F18MagicPathReferences.workspaceDesktop.componentId,
      '456417407095963648',
    );
    expect(
      F18MagicPathReferences.workspaceDesktop.revisionId,
      '456417407095963649',
    );
    expect(
      F18MagicPathReferences.workspaceCompact.size,
      const Size(390, 844),
    );
    expect(
      F18MagicPathReferences.troubleshootingStudent.size,
      const Size(820, 1180),
    );
    expect(
      F18MagicPathReferences.wireArchitecture.revisionId,
      '456432394111688705',
    );
  });

  testWidgets(
    'desktop workspace initially fits the complete routed scene without clipping',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: ElectroSimTheme.light(),
          home: const app.F18WorkspacePage(),
        ),
      );
      await tester.pumpAndSettle();

      final SimulatorCanvas canvas =
          tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
      final ViewportController viewport = canvas.viewportController!;
      final Rect worldBounds = F18MagicPathViewportFitter.contentBounds(
        circuit: canvas.circuit,
        layout: canvas.layout,
      );
      final Rect screenBounds = Rect.fromLTRB(
        worldBounds.left * viewport.scale + viewport.translation.dx,
        worldBounds.top * viewport.scale + viewport.translation.dy,
        worldBounds.right * viewport.scale + viewport.translation.dx,
        worldBounds.bottom * viewport.scale + viewport.translation.dy,
      );
      final Finder canvasPaint = find.descendant(
        of: find.byType(SimulatorCanvas),
        matching: find.byType(CustomPaint),
      ).first;
      final Size canvasSize = tester.getSize(canvasPaint);

      const double magicPathSafetyInset = 24;
      expect(
        screenBounds.left,
        greaterThanOrEqualTo(magicPathSafetyInset),
      );
      expect(
        screenBounds.top,
        greaterThanOrEqualTo(magicPathSafetyInset),
      );
      expect(
        screenBounds.right,
        lessThanOrEqualTo(canvasSize.width - magicPathSafetyInset),
      );
      expect(
        screenBounds.bottom,
        lessThanOrEqualTo(canvasSize.height - magicPathSafetyInset),
      );
      expect(canvas.elementVisualPainter, isNotNull);
      expect(canvas.showElementLabels, isFalse);
    },
  );

  testWidgets('compact workspace uses the same F18 renderer without overflow',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: ElectroSimTheme.light(),
        home: const app.F18WorkspacePage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final SimulatorCanvas canvas =
        tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    expect(canvas.elementVisualPainter, isNotNull);
    expect(canvas.showElementLabels, isFalse);
  });

  test('canvas product labels never expose raw technical model identifiers', () {
    expect(f18DisplayNameForModel('dc_voltage_source'), 'Source CC');
    expect(f18DisplayNameForModel('switch'), 'Interrupteur');
    expect(f18DisplayNameForModel('lamp'), 'Lampe');
    expect(f18DisplayNameForModel('motor_dc'), 'Moteur');
    expect(f18DisplayNameForModel('voltmeter'), 'Voltmètre');
    expect(f18DisplayNameForModel('inverter'), 'Onduleur');
    expect(f18DisplayNameForModel('pv_panel'), 'Module PV');
  });

  test(
    'all eight F18 visual archetypes can paint through the production renderer',
    () {
      const List<String> models = <String>[
        'dc_voltage_source',
        'breaker',
        'switch',
        'lamp',
        'motor_dc',
        'voltmeter',
        'inverter',
        'pv_panel',
      ];
      for (final String model in models) {
        final ui.PictureRecorder recorder = ui.PictureRecorder();
        final ui.Canvas canvas = ui.Canvas(recorder);
        paintF18MagicPathCanvasElement(
          canvas,
          const Rect.fromLTWH(0, 0, 104, 64),
          'element',
          model,
          model.contains('source'),
          false,
          1,
        );
        expect(recorder.endRecording(), isA<ui.Picture>());
      }
    },
  );
}
