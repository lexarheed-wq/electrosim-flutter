import 'dart:io';
import 'dart:ui' as ui;

import 'package:electrosim/f18_workspace_page.dart';
import 'package:electrosim/f18_industrial_physical_plate.dart';
import 'package:electrosim/f18_physical_instrument_readouts.dart';
import 'package:electrosim/f18_frequency_3d_assets.dart';
import 'package:electrosim/f9_component_palette.dart';
import 'package:electrosim/runtime/electrosim_instrument_projection.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:electrosim/f18_frequency_controls.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    expect(await F18PhysicalPlateAssets.preload(), isTrue);
    expect(await F18Frequency3dAssets.preload(), isTrue);
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

  for (final hz in [50.0, 60.0]) {
    testWidgets(
      'actual frequency meter ${hz.toInt()} Hz and physical controls',
      (WidgetTester t) async {
        t.view.physicalSize = const Size(1500, 960);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);

        const meterId = 'meter-f';
        final meter = InstrumentInstance(
          id: InstrumentId(meterId),
          kind: InstrumentKind.frequencyMeter,
          mode: InstrumentMode.frequency,
          inputImpedanceOhm: 10000000,
        );
        final base = CircuitState(
          circuitId: CircuitId('frequency-live'),
          revision: 0,
          mode: ElectricalMode.ac1,
          settings: {'frequencyHz': hz},
          sources: [
            SourceInstance(
              id: SourceId('source-ac'),
              modelType: 'ac_voltage_source',
              terminals: [
                Terminal(id: TerminalId('line'), name: 'L', phase: PhaseTag.l1),
                Terminal(
                  id: TerminalId('neutral'),
                  name: 'N',
                  phase: PhaseTag.neutral,
                ),
              ],
              parameters: const {'voltageRmsV': 230.0, 'phaseDegrees': 0.0},
            ),
          ],
          components: [
            ComponentInstance(
              id: ComponentId('lamp-1'),
              modelType: 'resistor',
              terminals: [
                Terminal(id: TerminalId('lamp-in'), name: '1'),
                Terminal(id: TerminalId('lamp-out'), name: '2'),
              ],
              parameters: const {'resistanceOhm': 529.0},
            ),
          ],
          connections: [
            Connection(
              id: ConnectionId('feed'),
              phase: PhaseTag.l1,
              fromTerminalId: TerminalId('line'),
              toTerminalId: TerminalId('lamp-in'),
            ),
            Connection(
              id: ConnectionId('return'),
              phase: PhaseTag.neutral,
              fromTerminalId: TerminalId('lamp-out'),
              toTerminalId: TerminalId('neutral'),
            ),
          ],
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
        expect(reading.result!.reading!.value, closeTo(hz, 1e-6));
        expect(circuit.connections, hasLength(2));
        expect(circuit.probes, hasLength(2));

        var layout = CircuitVisualLayout(
          elementPositions: const {
            'source-ac': Offset(205, 285),
            'switch-1': Offset(415, 285),
            'lamp-1': Offset(635, 285),
            meterId: Offset(440, 520),
          },
          elementSizes: const {
            'source-ac': Size(140, 160),
            'switch-1': Size(90, 140),
            'lamp-1': Size(280, 110),
            meterId: Size(112, 152),
          },
        );
        // Use the production wire router so power cables leave the physical
        // sockets before travelling around housings. Probes remain flexible.
        const router = CircuitWireLayoutEngine(
          router: OrthogonalWireRouter(
            grid: 24,
            obstacleClearance: 24,
            envelopePadding: 120,
          ),
        );
        for (final wire in circuit.connections) {
          layout = router.routeConnection(
            circuit: circuit,
            layout: layout,
            connectionId: wire.id,
          );
        }
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
                p.circuit.connections.length == 2 &&
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
                p.frequency3dIds.contains(meterId) &&
                identical(p.frequencyFront, F18Frequency3dAssets.front) &&
                p.circuit?.probes.length == 2 &&
                p.readouts[meterId] != null &&
                p.readouts[meterId]!.contains('${hz.toStringAsFixed(2)} Hz'),
          ),
          isTrue,
        );
        await t.enterText(
          find.byKey(const Key('palette-search-field')),
          'fréquencemètre',
        );
        await t.pump();
        // Verify the exact same preview is mounted inside the real full workspace
        // palette without requiring the user to search.
        const paletteItem = Key('palette-item-instrument-frequency');
        expect(find.byKey(paletteItem), findsOneWidget);
        final paletteImages = t.widgetList<RawImage>(
          find.descendant(
            of: find.byKey(paletteItem),
            matching: find.byType(RawImage),
          ),
        );
        expect(
          paletteImages.any(
            (image) => identical(image.image, F18Frequency3dAssets.palette),
          ),
          isTrue,
          reason:
              'Workspace palette must show the Cycles perspective, not front',
        );
        expect(
          find.byKey(const Key('palette-quick-add-instrument-frequency')),
          findsOneWidget,
        );
        expect(t.takeException(), isNull);
        final out = Directory('build/g5-sequential-proof/instrument-frequency');
        out.createSync(recursive: true);
        final boundary =
            captureKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await t.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1.5);
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '${out.path}/workspace-${hz.toInt()}hz.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
        File('${out.path}/fixture.json').writeAsStringSync(
          '{"mode":"ac1","source":"230Vrms","frequencyHz":$hz,"connections":2,'
          '"probes":{"V":"lamp-in","COM":"lamp-out"},'
          '"meter":"$meterId","data_source":"ElectroSimRuntimeEngine"}',
        );
        final overlay = t
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((p) => p.painter)
            .whereType<F18PhysicalInstrumentReadouts>()
            .first;
        final body = overlay.screenRect(meterId)!;
        final origin = t.getTopLeft(find.byType(SimulatorCanvas));
        Future<void> press(double x) async {
          await t.tapAt(
            origin +
                body.topLeft +
                Offset(body.width * x / 112, body.height * 78 / 152),
          );
          await t.pump();
        }

        await press(35);
        var state = t
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((p) => p.painter)
            .whereType<CircuitScenePainter>()
            .first
            .circuit;
        expect(F18FrequencyControls.held(state.instruments.single), isTrue);
        expect(state.probes, circuit.probes);
        expect(state.connections, circuit.connections);
        await press(77);
        state = t
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((p) => p.painter)
            .whereType<CircuitScenePainter>()
            .first
            .circuit;
        expect(F18FrequencyControls.lit(state.instruments.single), isTrue);
        await press(56);
        state = t
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((p) => p.painter)
            .whereType<CircuitScenePainter>()
            .first
            .circuit;
        expect(state.instruments.single.poweredOn, isFalse);
        expect(state.instruments.single.mode, InstrumentMode.frequency);
        await press(56);
        state = t
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((p) => p.painter)
            .whereType<CircuitScenePainter>()
            .first
            .circuit;
        expect(state.instruments.single.poweredOn, isTrue);
        expect(F18FrequencyControls.held(state.instruments.single), isFalse);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
}
