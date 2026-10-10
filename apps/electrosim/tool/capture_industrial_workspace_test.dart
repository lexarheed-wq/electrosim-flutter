// Run from apps/electrosim:
// ELECTROSIM_UI_CAPTURE_DIR=/path/to/output flutter test tool/capture_industrial_workspace_test.dart
// ELECTROSIM_FONT_DIR may override the Flutter material font directory.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:electrosim/main.dart';
import 'package:electrosim/f18_industrial_physical_plate.dart';
import 'package:electrosim/reference_components/disjoncteur_3d.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test/support/industrial_fixture.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';

void main() {
  final output = Directory(
    Platform.environment['ELECTROSIM_UI_CAPTURE_DIR'] ??
        'build/industrial-workspace-proof',
  );
  setUpAll(() async {
    await output.create(recursive: true);
    expect(await Disjoncteur3D.prechargerTextures(), isTrue);
    expect(await F18PhysicalPlateAssets.preload(), isTrue);
    for (final type in [
      'motor_3p_6t',
      'contactor_3p',
      'push_button_no',
      'push_button_nc',
    ]) {
      expect(
        F18PhysicalPlateAssets.ready(type),
        isTrue,
        reason: 'Capture must use current G5 assets for $type',
      );
    }
    final fonts =
        Platform.environment['ELECTROSIM_FONT_DIR'] ??
        '${Platform.environment['FLUTTER_ROOT'] ?? '/workspace/toolchains/flutter'}/bin/cache/artifacts/material_fonts';
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
  for (final scene in [
    ('plate', const Size(1440, 900), 1.0),
    ('schematic', const Size(1440, 900), 1.0),
    ('preview-3d', const Size(1440, 900), 1.0),
    ('phone-schematic', const Size(390, 844), 1.0),
  ]) {
    testWidgets('capture ${scene.$1}', (t) async {
      t.view.physicalSize = scene.$2;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final oldShadows = debugDisableShadows;
      debugDisableShadows = false;
      final semantics = t.ensureSemantics();
      final key = GlobalKey();
      try {
        await t.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ElectroSimTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scene.$3)),
                child: child!,
              ),
              home: F9WorkspaceDemoPage(
                initialCircuit: buildIndustrialSelfHoldCircuit(
                  startPressed: true,
                  stopPressed: false,
                ),
                initialSelectedElementId: 'k1',
                initialCabinetLayout: CabinetLayout([
                  CabinetFixture(
                    id: 'R1',
                    kind: CabinetFixtureKind.dinRail,
                    bounds: const Rect.fromLTWH(100, 900, 1000, 36),
                  ),
                  CabinetFixture(
                    id: 'D1',
                    kind: CabinetFixtureKind.wireDuct,
                    bounds: const Rect.fromLTWH(24, 1300, 1700, 40),
                  ),
                  CabinetFixture(
                    id: 'D2',
                    kind: CabinetFixtureKind.wireDuct,
                    bounds: const Rect.fromLTWH(1684, 24, 40, 1276),
                  ),
                ]),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        Future<void> menu(String key) async {
          await t.tap(find.byKey(const Key('workspace-more-actions')));
          await t.pumpAndSettle();
          await t.tap(find.byKey(Key(key)));
          await t.pumpAndSettle();
        }

        await menu('workspace-configure-cabinet');
        await t.enterText(
          find.byKey(const Key('workspace-cabinet-width')),
          '2400',
        );
        await t.enterText(
          find.byKey(const Key('workspace-cabinet-height')),
          '2000',
        );
        await t.tap(find.byKey(const Key('workspace-cabinet-apply')));
        await t.pumpAndSettle();
        if (scene.$1.contains('schematic')) {
          await t.tap(find.byKey(const Key('workspace-view-schematic')));
          await t.pumpAndSettle();
        }
        if (scene.$1.contains('schematic')) {
          final simulator = t.widget<SimulatorCanvas>(
            find.byType(SimulatorCanvas),
          );
          final viewport = simulator.viewportController!;
          final visible = Offset.zero & t.getSize(find.byType(SimulatorCanvas));
          final geometry = CircuitGeometryIndex.build(
            simulator.circuit,
            simulator.layout,
          );
          for (final point in geometry.terminalPositions.values) {
            expect(
              visible.contains(viewport.worldToScreen(point)),
              isTrue,
              reason: 'Every projected terminal must fit ${scene.$1}',
            );
          }
        }
        if (scene.$1 == 'preview-3d') await menu('workspace-preview-3d');
        final targetResult = await androidTapTargetGuideline.evaluate(t);
        final labelResult = await labeledTapTargetGuideline.evaluate(t);
        expect(t.takeException(), isNull);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await t.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '${output.path}/${scene.$1}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
          await File('${output.path}/${scene.$1}.json').writeAsString(
            jsonEncode({
              'scene': scene.$1,
              'tapTargetsPassed': targetResult.passed,
              'tapTargetsReason': targetResult.reason,
              'labelsPassed': labelResult.passed,
              'labelsReason': labelResult.reason,
              'sourceSha': Platform.environment['GITHUB_SHA'] ?? 'local',
            }),
          );
        });
        await t.pumpWidget(const SizedBox());
      } finally {
        semantics.dispose();
        debugDisableShadows = oldShadows;
      }
    });
  }
}
