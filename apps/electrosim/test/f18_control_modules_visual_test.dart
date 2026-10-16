import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:electrosim/f18_component_asset_visual.dart';
import 'package:electrosim/f18_industrial_dual_view.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<Uint8List> render(
    WidgetTester tester,
    String type, {
    bool perspective = false,
    Map<String, Object?> controlState = const <String, Object?>{},
  }) async {
    final Size size = F18ReferenceComponentMetrics.boardSizeFor(type);
    Widget view = F18ComponentAssetVisual(
      modelType: type,
      size: size,
      controlState: controlState,
    );
    if (perspective) {
      view = F18IndustrialDualView(
        modelType: type,
        size: size,
        presentation: F18IndustrialPresentation.palettePerspective,
        child: view,
      );
    }
    final GlobalKey boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(key: boundaryKey, child: view),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    return (await tester.runAsync(() async {
      final RenderRepaintBoundary boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage();
      try {
        return (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    }))!;
  }

  test('timer and PLC are registered as dedicated physical visuals', () {
    for (final type in ['timer_star_delta', 'plc_ac3', 'plc_dc']) {
      expect(
        F18ReferenceComponentVisuals.supports(type),
        isTrue,
        reason: '$type needs its own rendered physical component',
      );
    }
  });

  test(
    'control modules expose real terminal layouts at their physical scale',
    () {
      final timerSize = F18ReferenceComponentMetrics.boardSizeFor(
        'timer_star_delta',
      );
      final plcSize = F18ReferenceComponentMetrics.boardSizeFor('plc_ac3');
      expect(timerSize, const Size(180, 260));
      expect(plcSize, const Size(300, 220));
      expect(
        F18ReferenceComponentMetrics.boardSizeFor('plc_dc'),
        const Size(300, 220),
      );
      final Size plcPaletteSize = F18ReferenceComponentMetrics.paletteSizeFor(
        'plc_dc',
      );
      expect(plcPaletteSize.width, 82);
      expect(plcPaletteSize.height, closeTo(50.46, .01));

      final timerPorts = List.generate(
        5,
        (index) => TerminalVisualProfile.terminalOffset(
          modelType: 'timer_star_delta',
          size: timerSize,
          index: index,
          count: 5,
        ),
      );
      final plcPorts = List.generate(
        10,
        (index) => TerminalVisualProfile.terminalOffset(
          modelType: 'plc_ac3',
          size: plcSize,
          index: index,
          count: 10,
        ),
      );
      expect(timerPorts.toSet(), hasLength(5));
      expect(plcPorts.toSet(), hasLength(10));
      expect(timerPorts.take(2).every((point) => point.dy < 0), isTrue);
      expect(timerPorts.skip(2).every((point) => point.dy > 0), isTrue);
      expect(plcPorts.take(6).every((point) => point.dy < 0), isTrue);
      expect(plcPorts.skip(6).every((point) => point.dy > 0), isTrue);
    },
  );

  testWidgets('timer face follows the star-to-delta runtime state', (
    tester,
  ) async {
    final idle = await render(tester, 'timer_star_delta');
    final star = await render(
      tester,
      'timer_star_delta',
      controlState: const <String, Object?>{
        'timerActuated': true,
        'timerNcClosed': true,
        'timerNoClosed': false,
        'elapsedSeconds': 2.0,
      },
    );
    final delta = await render(
      tester,
      'timer_star_delta',
      controlState: const <String, Object?>{
        'timerActuated': true,
        'timerNcClosed': false,
        'timerNoClosed': true,
        'elapsedSeconds': 5.2,
      },
    );
    expect(star, isNot(equals(idle)));
    expect(delta, isNot(equals(star)));
  });

  testWidgets('PLC face follows live input and output bits', (tester) async {
    final idle = await render(tester, 'plc_ac3');
    final active = await render(
      tester,
      'plc_ac3',
      controlState: const <String, Object?>{
        'supplyValid': true,
        'programError': false,
        'I0': true,
        'I1': false,
        'I2': true,
        'I3': false,
        'Q0': false,
        'Q1': true,
        'Q2': false,
        'Q3': false,
      },
    );
    expect(active, isNot(equals(idle)));
  });

  testWidgets(
    'palette modules use a 3/4 camera while board modules stay frontal',
    (tester) async {
      for (final type in ['timer_star_delta', 'plc_ac3', 'plc_dc']) {
        final front = await render(tester, type);
        final palette = await render(tester, type, perspective: true);
        expect(palette, isNot(equals(front)), reason: type);
      }
    },
  );
}
