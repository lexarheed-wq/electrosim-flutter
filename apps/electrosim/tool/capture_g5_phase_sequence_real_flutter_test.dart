import 'dart:io';
import 'dart:ui' as ui;
import 'package:electrosim/f18_workspace_page.dart';
import 'package:electrosim/f18_phase_sequence_3d_assets.dart';
import 'package:electrosim/f18_industrial_physical_plate.dart';
import 'package:electrosim/f18_physical_instrument_readouts.dart';
import 'package:electrosim/runtime/electrosim_instrument_projection.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test/physical_families_instruments_dynamics_qualification_test.dart'
    as fixture;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    expect(await F18PhysicalPlateAssets.preload(), isTrue);
    expect(await F18PhaseSequence3dAssets.preload(), isTrue);
    final fonts =
        '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
    for (final entry in {
      'Roboto': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(entry.key)..addFont(
            Future.value(
              ByteData.sublistView(
                await File('$fonts/${entry.value}').readAsBytes(),
              ),
            ),
          ))
          .load();
    }
  });
  for (final reversed in [false, true]) {
    testWidgets(
      'phase order ${reversed ? 'reversed' : 'forward'} in actual workspace',
      (t) async {
        t.view.physicalSize = const Size(1500, 960);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final meter = InstrumentInstance(
          id: InstrumentId('phase-meter'),
          kind: InstrumentKind.phaseSequenceTester,
          mode: InstrumentMode.phaseSequence,
        );
        final picks = reversed ? ['l1', 'l3', 'l2'] : ['l1', 'l2', 'l3'];
        final circuit = fixture.withInstrument(
          fixture.acCircuit(mode: ElectricalMode.ac3),
          meter,
          [
            for (var i = 0; i < 3; i++)
              fixture.probe(
                'lead-$i',
                meter,
                [
                  InstrumentPort.phase1,
                  InstrumentPort.phase2,
                  InstrumentPort.phase3,
                ][i],
                picks[i],
              ),
          ],
        );
        final expected = reversed ? 'L1 → L3 → L2' : 'L1 → L2 → L3';
        final reading = fixture.projector.read(
          snapshot: fixture.engine.evaluate(circuit),
          instrument: meter,
        );
        expect(reading.status, PhysicalInstrumentStatus.valid);
        expect(reading.result?.displayText, expected);
        var layout = CircuitVisualLayout(
          elementPositions: const {
            'grid': Offset(225, 210),
            'r1': Offset(475, 160),
            'r2': Offset(475, 300),
            'r3': Offset(475, 440),
            'phase-meter': Offset(215, 540),
          },
          elementSizes: const {
            'grid': Size(140, 160),
            'r1': Size(240, 80),
            'r2': Size(240, 80),
            'r3': Size(240, 80),
            'phase-meter': Size(112, 152),
          },
        );
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
        final key = GlobalKey();
        await t.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              home: F18WorkspacePage(
                initialCircuit: circuit,
                initialVisualLayout: layout,
              ),
            ),
          ),
        );
        await t.pump(const Duration(milliseconds: 250));
        await t.pump(const Duration(milliseconds: 300));
        await t.enterText(
          find.byKey(const Key('palette-search-field')),
          'ordre des phases',
        );
        await t.pump();
        final item = find.byKey(
          const Key('palette-item-instrument-phase-sequence'),
        );
        expect(item, findsOneWidget);
        expect(
          find.descendant(of: item, matching: find.byType(RawImage)),
          findsOneWidget,
          reason: 'Dedicated original perspective must replace flat preview',
        );
        final image = t.widget<RawImage>(
          find.descendant(of: item, matching: find.byType(RawImage)),
        );
        expect(
          identical(image.image, F18PhaseSequence3dAssets.palette),
          isTrue,
        );
        final paints = t
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((p) => p.painter);
        expect(
          paints.whereType<CircuitScenePainter>().any(
            (p) => p.customInstrumentCaseIds.contains('phase-meter'),
          ),
          isTrue,
        );
        expect(
          paints.whereType<F18PhysicalInstrumentReadouts>().any(
            (p) =>
                p.phaseSequence3dIds.contains('phase-meter') &&
                identical(
                  p.phaseSequenceFront,
                  F18PhaseSequence3dAssets.front,
                ) &&
                p.readouts['phase-meter'] == expected &&
                p.circuit?.probes.length == 3,
          ),
          isTrue,
        );
        expect(t.takeException(), isNull);
        await t.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1.4);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory(
            'build/g5-sequential-proof/instrument-phase-sequence',
          )..createSync(recursive: true);
          File(
            '${dir.path}/workspace-${reversed ? 'reversed' : 'forward'}.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
          image.dispose();
        });
        await t.pumpWidget(const SizedBox());
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
}
