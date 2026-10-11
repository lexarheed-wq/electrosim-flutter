import 'dart:io';
import 'dart:ui' as ui;

import 'package:electrosim/f18_workspace_page.dart';
import 'package:electrosim/f18_industrial_physical_plate.dart';
import 'package:electrosim/f18_physical_instrument_readouts.dart';
import 'package:electrosim/f18_ammeter_3d_assets.dart';
import 'package:electrosim/f9_component_palette.dart';
import 'package:electrosim/runtime/electrosim_instrument_projection.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/regression_fixture.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    expect(await F18PhysicalPlateAssets.preload(), isTrue);
    expect(await F18Ammeter3dAssets.preload(), isTrue);
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

  for (final scenario in [
    (name: 'series', rating: 10.0, powered: true),
    (name: 'fuse-overload', rating: .5, powered: true),
    (name: 'off-input-overload', rating: .5, powered: false),
  ]) {
    testWidgets(
      'actual fused ammeter ${scenario.name}',
      (WidgetTester t) async {
        t.view.physicalSize = const Size(1500, 960);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);

        const meterId = 'meter-a';
        final meter = InstrumentInstance(
          id: InstrumentId(meterId),
          kind: InstrumentKind.ammeter,
          mode: InstrumentMode.currentDc,
          burdenResistanceOhm: .01,
          fuseRatingA: scenario.rating,
          poweredOn: scenario.powered,
          cutConnectionId: ConnectionId('wire-2'),
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
              port: InstrumentPort.amp,
              terminalId: TerminalId('switch-out'),
            ),
            ProbeConnection(
              id: ProbeId('lead-com'),
              instrumentId: meter.id,
              port: InstrumentPort.common,
              terminalId: TerminalId('lamp-in'),
            ),
          ],
        );
        final solved = const ElectroSimRuntimeEngine().evaluate(circuit);
        final reading = const ElectroSimInstrumentProjection().read(
          snapshot: solved,
          instrument: meter,
        );
        expect(solved.solved, isTrue);
        expect(
          reading.status,
          !scenario.powered
              ? PhysicalInstrumentStatus.off
              : scenario.rating < 1
              ? PhysicalInstrumentStatus.blownFuse
              : PhysicalInstrumentStatus.valid,
        );
        expect(
          const ElectroSimInstrumentProjection().dcSeriesCurrent(solved, meter),
          closeTo(24 / 24.01, 1e-6),
        );
        if (scenario.rating > 1)
          expect(reading.result!.reading!.value, closeTo(24 / 24.01, 1e-6));
        expect(circuit.connections, hasLength(3));
        expect(circuit.probes, hasLength(2));
        expect(SeriesMeterWiring.openConnectionIds(circuit), {
          ConnectionId('wire-2'),
        });

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
                p.circuit.connections.length == 3 &&
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
                p.ammeter3dIds.contains(meterId) &&
                identical(p.ammeterFront, F18Ammeter3dAssets.front) &&
                p.circuit?.probes.length == 2 &&
                p.readouts[meterId] != null &&
                p.readouts[meterId]!.contains(
                  scenario.rating < 1 ? 'FUSE' : '1.00',
                ),
          ),
          isTrue,
        );
        expect(
          scenes.first.circuit.instruments.single.fuseBlown,
          scenario.rating < 1,
        );
        await t.enterText(
          find.byKey(const Key('palette-search-field')),
          'ampèremètre',
        );
        await t.pump();
        // Verify the exact same preview is mounted inside the real full workspace
        // palette without requiring the user to search.
        const paletteItem = Key('palette-item-instrument-ammeter');
        expect(find.byKey(paletteItem), findsOneWidget);
        final paletteImages = t.widgetList<RawImage>(
          find.descendant(
            of: find.byKey(paletteItem),
            matching: find.byType(RawImage),
          ),
        );
        expect(
          paletteImages.any(
            (image) => identical(image.image, F18Ammeter3dAssets.palette),
          ),
          isTrue,
          reason:
              'Workspace palette must show the Cycles perspective, not front',
        );
        expect(
          find.byKey(const Key('palette-quick-add-instrument-ammeter')),
          findsOneWidget,
        );
        expect(t.takeException(), isNull);
        final out = Directory('build/g5-sequential-proof/instrument-ammeter');
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
              '${out.path}/workspace-${scenario.name}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
        File('${out.path}/fixture.json').writeAsStringSync(
          '{"mode":"dc","source":"24V","connections":3,'
          '"probes":{"A":"switch-out","COM":"lamp-in"},'
          '"meter":"$meterId","data_source":"ElectroSimRuntimeEngine"}',
        );
        await t.pumpWidget(const SizedBox());
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
}
