import 'dart:io';
import 'dart:ui' as ui;
import 'package:electrosim/f18_workspace_page.dart';
import 'package:electrosim/f18_power_socket_visual.dart';
import 'package:electrosim/f18_appliance_power_cords.dart';
import 'package:electrosim/f18_industrial_physical_plate.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test/appliance_earth_behavior_test.dart' as fixture;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await F18PhysicalPlateAssets.preload();
    final fonts =
        '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
    for (final e in {
      'Roboto': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(
            Future.value(
              ByteData.sublistView(
                await File('$fonts/${e.value}').readAsBytes(),
              ),
            ),
          ))
          .load();
    }
  });
  testWidgets('real workspace: independent socket, PE cord and unplug', (
    t,
  ) async {
    t.view.physicalSize = const Size(1600, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final c = fixture.earthCircuit();
    final layout =
        const CircuitWireLayoutEngine(
          router: OrthogonalWireRouter(
            grid: 24,
            obstacleClearance: 24,
            envelopePadding: 120,
          ),
        ).routeAll(
          circuit: c,
          layout: CircuitVisualLayout(
            elementPositions: {
              's': const Offset(170, 150),
              'rcd': const Offset(400, 150),
              'socket': const Offset(520, 400),
              'load': const Offset(270, 390),
            },
            elementSizes: {
              's': const Size(140, 140),
              'rcd': const Size(144, 300),
              'socket': const Size(120, 120),
              'load': const Size(180, 190),
            },
          ),
        );
    final key = GlobalKey();
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          child: F18WorkspacePage(
            initialCircuit: c,
            initialVisualLayout: layout,
            initialSelectedElementId: 'load',
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 800));
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.byType(F18PowerSocketVisual), findsWidgets);
    final painters = find
        .byType(CustomPaint)
        .evaluate()
        .map((e) => (e.widget as CustomPaint).painter)
        .whereType<F18AppliancePowerCords>()
        .toList();
    expect(painters, isNotEmpty);
    expect(
      painters.first.circuit.connections
          .where((w) => w.metadata['appliancePowerCable'] == 'load')
          .length,
      3,
    );
    Future<void> capture(String name) async {
      await t.pump();
      await t.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 1.5);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final f = File('build/g5-power-proof/$name.png');
        await f.parent.create(recursive: true);
        await f.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('connected-pe');
    await t.tap(find.byKey(const ValueKey('power-socket-load-socket')));
    await t.pump(const Duration(milliseconds: 350));
    await t.tap(find.text('Fiche débranchée').last);
    await t.pump(const Duration(milliseconds: 350));
    expect(t.takeException(), isNull);
    final canvas = t.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    expect(
      canvas.circuit.connections.where(
        (w) => w.metadata['appliancePowerCable'] == 'load',
      ),
      isEmpty,
    );
    await capture('unplugged');
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
}
