import 'dart:io';
import 'dart:ui' as ui;

import 'package:electrosim/main.dart';
import 'package:electrosim/f18_physical_instrument_readouts.dart';
import 'package:electrosim/f18_voltmeter_3d_assets.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('genuine Flutter workspace: Cycles voltmeter board and palette', (
    WidgetTester t,
  ) async {
    t.view.physicalSize = const Size(1380, 880);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    expect(await F18Voltmeter3dAssets.preload(), isTrue);
    const meterId = 'voltmeter-3d-001';
    final circuit = CircuitState(
      circuitId: CircuitId('g5-voltmeter-3d-proof'),
      revision: 0,
      mode: ElectricalMode.dc,
      instruments: [
        InstrumentInstance(
          id: InstrumentId(meterId),
          kind: InstrumentKind.voltmeter,
          mode: InstrumentMode.voltageDc,
        ),
      ],
    );
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: F9WorkspaceDemoPage(
            initialCircuit: circuit,
            initialSelectedElementId: meterId,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final scenes = t
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((p) => p.painter)
        .whereType<CircuitScenePainter>();
    expect(
      scenes.any((p) => p.customInstrumentCaseIds.contains(meterId)),
      isTrue,
    );
    final overlays = t
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((p) => p.painter)
        .whereType<F18PhysicalInstrumentReadouts>();
    expect(overlays.any((p) =>
        p.voltmeter3dIds.contains(meterId) &&
        identical(p.voltmeterFront, F18Voltmeter3dAssets.front)), isTrue);
    expect(t.takeException(), isNull);

    final out = Directory('build/g5-voltmeter-real-flutter-proof');
    await out.create(recursive: true);
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await t.runAsync(() async {
      final img = await boundary.toImage(pixelRatio: 1.5);
      try {
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        await File('${out.path}/workspace.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
      } finally {
        img.dispose();
      }
    });
    await t.pumpWidget(const SizedBox());
  });
}
