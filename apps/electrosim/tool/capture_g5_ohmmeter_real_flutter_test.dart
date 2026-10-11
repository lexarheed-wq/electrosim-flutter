import 'dart:io';
import 'dart:ui' as ui;

import 'package:electrosim/f18_workspace_page.dart';
import 'package:electrosim/f18_physical_instrument_readouts.dart';
import 'package:electrosim/f18_voltmeter_3d_assets.dart';
import 'package:electrosim/f9_component_palette.dart';
import 'package:electrosim/runtime/electrosim_instrument_projection.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    expect(await F18Voltmeter3dAssets.preload(), isTrue);
    final fonts =
        '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
    final loader = FontLoader('Roboto');
    for (final name in [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
    ]) {
      loader.addFont(
        Future.value(
          ByteData.sublistView(await File('$fonts/$name').readAsBytes()),
        ),
      );
    }
    await loader.load();
    await (FontLoader('MaterialIcons')..addFont(
          Future.value(
            ByteData.sublistView(
              await File('$fonts/MaterialIcons-Regular.otf').readAsBytes(),
            ),
          ),
        ))
        .load();
  });

  testWidgets(
    'actual ElectroSim board reads 120 ohms on a disconnected passive circuit',
    (WidgetTester t) async {
      t.view.physicalSize = const Size(1500, 960);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);

      const meterId = 'meter-v';
      final meter = InstrumentInstance(
        id: InstrumentId(meterId),
        kind: InstrumentKind.voltmeter,
        mode: InstrumentMode.resistance,
        inputImpedanceOhm: 10000000,
      );
      final circuit = CircuitState(
        circuitId: CircuitId('g5-ohmmeter-real-proof'),
        revision: 0,
        mode: ElectricalMode.dc,
        components: [
          ComponentInstance(
            id: ComponentId('lamp-1'),
            modelType: 'resistor',
            terminals: [
              Terminal(id: TerminalId('lamp-in'), name: 'A'),
              Terminal(id: TerminalId('lamp-out'), name: 'B'),
            ],
            parameters: const {'resistanceOhm': 120.0},
          ),
        ],
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
      final solved = const ElectroSimRuntimeEngine().evaluate(circuit);
      final reading = const ElectroSimInstrumentProjection().read(
        snapshot: solved,
        instrument: meter,
      );

      expect(reading.status, PhysicalInstrumentStatus.valid);
      expect(reading.result!.reading!.value, closeTo(120, .01));
      expect(circuit.connections, hasLength(0));
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
          'lamp-1': Size(160, 100),
          meterId: Size(112, 152),
        },
      );
      final captureKey = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: F18WorkspacePage(
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
      expect(
        scenes.any(
          (p) =>
              p.customInstrumentCaseIds.contains(meterId) &&
              p.circuit.connections.isEmpty &&
              p.circuit.probes.length == 2,
        ),
        isTrue,
      );

      final overlays = t
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((p) => p.painter)
          .whereType<F18PhysicalInstrumentReadouts>();
      expect(
        overlays.any(
          (p) =>
              p.voltmeter3dIds.contains(meterId) &&
              identical(p.voltmeterFront, F18Voltmeter3dAssets.front) &&
              p.circuit?.probes.length == 2 &&
              p.readouts[meterId] != null &&
              p.readouts[meterId]!.contains('120'),
        ),
        isTrue,
      );
      // Verify the exact same preview is mounted inside the real full workspace
      // palette without requiring the user to search.
      const paletteItem = Key('palette-item-instrument-voltmeter');
      expect(find.byKey(paletteItem), findsOneWidget);
      final paletteImages = t.widgetList<RawImage>(
        find.descendant(
          of: find.byKey(paletteItem),
          matching: find.byType(RawImage),
        ),
      );
      expect(
        paletteImages.any(
          (image) => identical(image.image, F18Voltmeter3dAssets.palette),
        ),
        isTrue,
        reason: 'Workspace palette must show the Cycles perspective, not front',
      );
      expect(
        find.byKey(const Key('palette-quick-add-instrument-voltmeter')),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
      final out = Directory('build/g5-sequential-proof/instrument-voltmeter');
      out.createSync(recursive: true);
      final boundary =
          captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await t.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.5);
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '${out.path}/workspace-120-ohm.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
      File('${out.path}/fixture.json').writeAsStringSync(
        '{"mode":"dc","source":"none","connections":0,'
        '"probes":{"V":"lamp-in","COM":"lamp-out"},'
        '"meter":"$meterId","data_source":"ElectroSimRuntimeEngine"}',
      );
      await t.pumpWidget(const SizedBox());
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
