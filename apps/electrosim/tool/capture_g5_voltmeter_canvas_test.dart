import 'dart:io';
import 'dart:ui' as ui;

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

  testWidgets('actual Flutter electrical board renderer, solved voltage and probe leads',
      (WidgetTester t) async {
    t.view.physicalSize = const Size(1280, 760);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    print('G5PROOF: fixture start');
    final base = buildRegressionFixtureCircuit();
    final meter = InstrumentInstance(
      id: InstrumentId('meter-v'),
      kind: InstrumentKind.voltmeter,
      mode: InstrumentMode.voltageDc,
      inputImpedanceOhm: 10000000,
    );
    final circuit = CircuitState(
      circuitId: base.circuitId,
      revision: base.revision,
      mode: base.mode,
      components: base.components,
      sources: base.sources,
      connections: base.connections,
      settings: base.settings,
      metadata: base.metadata,
      instruments: [meter],
      probes: [
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
    const engine = ElectroSimRuntimeEngine();
    const projection = ElectroSimInstrumentProjection();
    print('G5PROOF: solver start');
    final snapshot = engine.evaluate(circuit);
    print('G5PROOF: solver done');
    final read = projection.read(snapshot: snapshot, instrument: meter);
    expect(snapshot.solved, isTrue);
    expect(read.status, PhysicalInstrumentStatus.valid);
    expect(read.result!.reading!.value, closeTo(24.0, 0.03));
    final String readout = read.result!.displayText ??
        '${read.result!.reading!.value.toStringAsFixed(2)} V';
    expect(readout, contains('24'));

    final layout = CircuitVisualLayout(
      elementPositions: const {
        'source-24v': Offset(230, 260),
        'switch-1': Offset(470, 255),
        'lamp-1': Offset(780, 255),
        'meter-v': Offset(545, 508),
      },
      elementSizes: const {
        'source-24v': Size(140, 160),
        'switch-1': Size(90, 140),
        'lamp-1': Size(130, 260),
        'meter-v': Size(112, 152),
      },
    );
    final viewport = ViewportController(
      scale: 1.0,
      translation: const Offset(10, 0),
    );
    addTearDown(viewport.dispose);
    final captureKey = GlobalKey();

    print('G5PROOF: pumpWidget start');
    await t.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: RepaintBoundary(
          key: captureKey,
          child: Column(
            children: [
              const SizedBox(
                height: 56,
                child: ColoredBox(
                  color: Color(0xFF25354B),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 26),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('ElectroSim — Platine CC 24 V • Mesure V/COM',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SimulatorCanvas(
                      circuit: circuit,
                      layout: layout,
                      viewportController: viewport,
                      selectedElementId: meter.id.value,
                      enableInteraction: false,
                      customInstrumentCaseIds: const {'meter-v'},
                    ),
                    IgnorePointer(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: F18PhysicalInstrumentReadouts(
                          layout: layout,
                          viewport: viewport,
                          circuit: circuit,
                          voltmeterFront: F18Voltmeter3dAssets.front,
                          voltmeter3dIds: const {'meter-v'},
                          selectedElementId: meter.id.value,
                          readouts: {'meter-v': readout},
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ));
    print('G5PROOF: pumpWidget done');
    await t.pump(const Duration(milliseconds: 16));
    print('G5PROOF: extra pump done');
    expect(t.takeException(), isNull);
    expect(find.byType(SimulatorCanvas), findsOneWidget);
    // The actual overlay is validated by inspecting all registered painters.
    final painters = t
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((w) => w.painter)
      .whereType<F18PhysicalInstrumentReadouts>();
    expect(painters.any((p) => p.readouts['meter-v'] == readout &&
        p.circuit?.probes.length == 2 &&
        p.voltmeter3dIds.contains('meter-v')), isTrue);
    final out = Directory('build/g5-voltmeter-real-flutter-proof');
    out.createSync(recursive: true);
    final boundary =
        captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    print('G5PROOF: capture runAsync start');
    await t.runAsync(() async {
      print('G5PROOF: toImage start');
      final image = await boundary.toImage(pixelRatio: 1.3);
      print('G5PROOF: toImage done');
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        print('G5PROOF: image bytes done');
        await File('${out.path}/renderer-24v-connected.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
    print('G5PROOF: screenshot written');
    File('${out.path}/renderer-fixture.txt').writeAsStringSync(
      'Real Flutter SimulatorCanvas + F18PhysicalInstrumentReadouts. '
      'Three actual power wires; two actual probes to lamp-in and lamp-out. '
      'Runtime solved voltage: ${read.result!.reading!.value} V. '
      'Not a screenshot of the full workspace chrome.\n',
    );
    await t.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(seconds: 40)));
}
