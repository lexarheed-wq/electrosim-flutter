import 'dart:io';
import 'dart:ui' as ui;

import 'package:electrosim/main.dart';
import 'package:electrosim/f18_physical_instrument_readouts.dart';
import 'package:electrosim/f18_voltmeter_3d_assets.dart';
import 'package:electrosim/runtime/electrosim_instrument_projection.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/regression_fixture.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    expect(await F18Voltmeter3dAssets.preload(), isTrue);
  });

  testWidgets('actual ElectroSim board, energized 24V circuit and connected probes',
      (WidgetTester t) async {
    t.view.physicalSize = const Size(1500, 960);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    const meterId = 'meter-v';
    final meter = InstrumentInstance(
      id: InstrumentId(meterId),
      kind: InstrumentKind.voltmeter,
      mode: InstrumentMode.voltageDc,
      inputImpedanceOhm: 10000000,
    );
    final base = buildRegressionFixtureCircuit();
    final circuit = CircuitState(
      circuitId: base.circuitId,
      revision: base.revision,
      mode: base.mode,
      components: base.components,
      sources: base.sources,
      connections: base.connections,
      settings: base.settings,
      metadata: base.metadata,
      instruments: <InstrumentInstance>[meter],
      probes: <ProbeConnection>[
        ProbeConnection(
          id: ProbeId('lead-v'),
          instrumentId: meter.id,
          port: InstrumentPort.voltOhm,
          terminalId: TerminalId('lamp-in'),
        ),
        ProbeConnection(
          id: ProbeId('lead-com'),
          instrumentId: meter.id,
          port: InstrumentPort.common,
          terminalId: TerminalId('lamp-out'),
        ),
      ],
    );
    final solved = const ElectroSimRuntimeEngine().evaluate(circuit);
    final reading = const ElectroSimInstrumentProjection().read(
      snapshot: solved,
      instrument: meter,
    );
    expect(solved.solved, isTrue);
    expect(reading.status, PhysicalInstrumentStatus.valid);
    expect(reading.result!.reading!.value, closeTo(24, .03));
    expect(circuit.connections, hasLength(3));
    expect(circuit.probes, hasLength(2));

    final layout = CircuitVisualLayout(
      elementPositions: const {
        'source-24v': Offset(205, 285),
        'switch-1': Offset(415, 285),
        'lamp-1': Offset(635, 285),
        meterId: Offset(440, 520),
      },
      elementSizes: const {
        'source-24v': Size(140, 160),
        'switch-1': Size(90, 140),
        'lamp-1': Size(130, 260),
        meterId: Size(112, 152),
      },
    );
    final captureKey = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: F9WorkspaceDemoPage(
            initialCircuit: circuit,
            initialVisualLayout: layout,
            initialSelectedElementId: meterId,
          ),
        ),
      ),
    );
    // The full app has animated panel and paint loops. Do not pumpAndSettle:
    // that can hang indefinitely and cannot establish visual qualification.
    await t.pump(const Duration(milliseconds: 250));
    await t.pump(const Duration(milliseconds: 300));

    final scenes = t
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((p) => p.painter)
        .whereType<CircuitScenePainter>();
    expect(scenes.any((p) =>
        p.customInstrumentCaseIds.contains(meterId) &&
        p.circuit.connections.length == 3 &&
        p.circuit.probes.length == 2), isTrue);

    final overlays = t
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((p) => p.painter)
        .whereType<F18PhysicalInstrumentReadouts>();
    expect(overlays.any((p) =>
        p.voltmeter3dIds.contains(meterId) &&
        identical(p.voltmeterFront, F18Voltmeter3dAssets.front) &&
        p.circuit?.probes.length == 2 &&
        p.readouts[meterId] != null &&
        p.readouts[meterId]!.contains('24')), isTrue);
    expect(t.takeException(), isNull);
    final out = Directory('build/g5-voltmeter-real-flutter-proof');
    await out.create(recursive: true);
    final boundary =
        captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await t.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.5);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('${out.path}/workspace-24v-connected.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
    await File('${out.path}/fixture.json').writeAsString(
      '{"mode":"dc","source":"24V","connections":3,'
      '"probes":{"V":"lamp-in","COM":"lamp-out"},'
      '"meter":"$meterId","data_source":"ElectroSimRuntimeEngine"}',
    );
    await t.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(minutes: 3)));
}
