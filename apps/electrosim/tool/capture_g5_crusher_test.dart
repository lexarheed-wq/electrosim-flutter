import 'dart:io';
import 'dart:convert';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'dart:ui' as ui;
import 'package:electrosim/f18_workspace_page.dart';
import 'package:electrosim/f18_crusher_3d_assets.dart';
import 'package:electrosim/f18_crusher_visual.dart';
import 'package:electrosim/f18_industrial_physical_plate.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test/g5_crusher_integration_test.dart' as fixture;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    expect(await F18Crusher3dAssets.preload(), isTrue);
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
  testWidgets('actual asynchronous motor star and delta bridge proofs', (
    t,
  ) async {
    t.view.physicalSize = const Size(1600, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    for (final delta in [false, true]) {
      final data =
          jsonDecode(jsonEncode(fixture.crusherFixture().toJson()))
              as Map<String, dynamic>;
      final component =
          (data['components'] as List).single as Map<String, dynamic>;
      component['modelType'] = 'motor_3p_6t';
      component['terminals'] = (component['terminals'] as List)
          .take(6)
          .toList();
      final parameters = component['parameters'] as Map<String, dynamic>;
      parameters['_visualModelType'] = 'motor_3p_6t';
      parameters.remove('_visualVariant');
      final wires = (data['connections'] as List);
      wires.removeWhere(
        (w) => w['id'] == 'pe' || w['id'] == 'star1' || w['id'] == 'star2',
      );
      Connection link(String id, String a, String b) => Connection(
        id: ConnectionId(id),
        fromTerminalId: TerminalId(a),
        toTerminalId: TerminalId(b),
      );
      wires.addAll(
        (delta
                ? [
                    link('bridge1', 'U1', 'W2'),
                    link('bridge2', 'V1', 'U2'),
                    link('bridge3', 'W1', 'V2'),
                  ]
                : [link('bridge1', 'U2', 'V2'), link('bridge2', 'V2', 'W2')])
            .map((w) => w.toJson()),
      );
      final c = CircuitState.fromJson(data);
      final layout = fixture.crusherRouter.routeAll(
        circuit: c,
        layout: CircuitVisualLayout(
          elementPositions: {
            'grid': const Offset(160, 150),
            'crusher': const Offset(650, 420),
          },
          elementSizes: {
            'grid': const Size(140, 160),
            'crusher': const Size(750, 430),
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
              key: ValueKey('motor-$delta'),
              initialCircuit: c,
              initialVisualLayout: layout,
              initialSelectedElementId: 'crusher',
            ),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 800));
      await t.pump();
      await t.enterText(
        find.byKey(const Key('palette-search-field')),
        'Moteur',
      );
      await t.pump(const Duration(milliseconds: 400));
      await t.pump();
      expect(t.takeException(), isNull);
      await t.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 1.5);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final f = File(
          'build/g5-crusher-proof/motor-${delta ? 'delta' : 'star'}.png',
        );
        await f.parent.create(recursive: true);
        await f.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
  testWidgets('actual palette and board front, closed and maintenance', (
    t,
  ) async {
    t.view.physicalSize = const Size(1600, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final c = fixture.crusherFixture();
    final layout = fixture.crusherRouter.routeAll(
      circuit: c,
      layout: fixture.crusherLayout(),
    );
    for (final selected in [false, true]) {
      final key = GlobalKey();
      await t.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: key,
            child: F18WorkspacePage(
              key: ValueKey(selected),
              initialCircuit: c,
              initialVisualLayout: layout,
              initialSelectedElementId: selected ? 'crusher' : null,
            ),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 800));
      await t.pump();
      await t.enterText(
        find.byKey(const Key('palette-search-field')),
        'Broyeur',
      );
      await t.pump(const Duration(milliseconds: 400));
      await t.pump();
      expect(t.takeException(), isNull);
      expect(find.byType(F18CrusherVisual), findsWidgets);
      final images = find
          .byType(RawImage)
          .evaluate()
          .map((e) => e.widget as RawImage);
      expect(
        images.any((w) => identical(w.image, F18Crusher3dAssets.palette)),
        isTrue,
      );
      expect(
        images.any(
          (w) => identical(
            w.image,
            selected ? F18Crusher3dAssets.service : F18Crusher3dAssets.front,
          ),
        ),
        isTrue,
      );
      final canvas = t.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
      expect(canvas.circuit.components.single.terminals.length, 7);
      expect(canvas.circuit.connections.length, 6);
      await t.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 1.5);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final f = File(
          'build/g5-crusher-proof/${selected ? 'maintenance' : 'closed'}.png',
        );
        await f.parent.create(recursive: true);
        await f.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
      if (selected) {
        await t.tap(
          find.byKey(const Key('palette-quick-add-external-crusher')),
        );
        await t.pump(const Duration(milliseconds: 400));
        final updated = t.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
        final added = updated.circuit.components.singleWhere(
          (c) => c.id.value != 'crusher',
        );
        expect(added.terminals.length, 7);
        expect(updated.layout.sizeOf(added.id.value), const Size(480, 440));
        expect(t.takeException(), isNull);
      }
    }
  });
}
