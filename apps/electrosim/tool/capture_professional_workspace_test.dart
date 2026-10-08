// Run from apps/electrosim:
// ELECTROSIM_UI_CAPTURE_DIR=/path/to/output flutter test tool/capture_professional_workspace_test.dart
// ELECTROSIM_FONT_DIR may override the Flutter material font directory.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:electrosim/main.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test/support/regression_fixture.dart';

void main() {
  final output = Directory(
    Platform.environment['ELECTROSIM_UI_CAPTURE_DIR'] ??
        'build/professional-workspace-captures',
  );
  setUpAll(() async {
    await output.create(recursive: true);
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
    ('desktop', const Size(1440, 900), 1.0),
    ('desktop-measures', const Size(1440, 900), 1.0),
    ('desktop-focus', const Size(1440, 900), 1.0),
    ('phone', const Size(390, 844), 1.0),
    ('phone-properties', const Size(390, 844), 1.0),
    ('tablet-text200', const Size(1024, 768), 2.0),
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
                initialCircuit: buildRegressionFixtureCircuit(),
                initialSelectedElementId: 'lamp-1',
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final layout = t
            .widget<ElectroSimWorkspaceShell>(
              find.byType(ElectroSimWorkspaceShell),
            )
            .layoutController!;
        if (scene.$1 == 'desktop-focus') {
          layout.setPanelVisible(ElectroSimWorkspacePanel.palette, false);
          layout.setPanelVisible(ElectroSimWorkspacePanel.context, false);
          await t.pumpAndSettle();
        }
        if (scene.$1 == 'phone-properties' || scene.$1 == 'tablet-text200') {
          await t.tap(find.byKey(electroSimContextEdgeKey));
          await t.pumpAndSettle();
        }
        final tab = find.descendant(
          of: find.byType(TabBar),
          matching: find.text('Mesures'),
        );
        if (scene.$1 == 'desktop-measures') {
          await t.tap(tab);
          await t.pumpAndSettle();
        }
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
              'measureTabHittable': tab.hitTestable().evaluate().length,
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
