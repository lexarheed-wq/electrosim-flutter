import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:electrosim/pneumatics/pneumatic_device_glyph.dart';
import 'package:electrosim/pneumatics/pneumatic_workshop_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'r6_moving_piston_workshop_test.dart' as fixture;

/// Unretouched PNG evidence from the actual authored Flutter workshop.
/// The piston is advanced by the real gas/cylinder solver via the UI.
Future<void> captureWorkshop(WidgetTester tester, String fileName) async {
  final RenderRepaintBoundary boundary = tester.renderObject(
    find.byKey(const Key('r6l-live-evidence-boundary')),
  );
  // The render/PNG encoding future and disk operations require real async
  // time, not the WidgetTester fake-clock zone. Never block the test clock.
  debugPrint('R6L_CAPTURE_BEGIN $fileName');
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 1);
    try {
      final ByteData? bytes = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (bytes == null) {
        throw StateError('Flutter failed to encode the actual workshop PNG');
      }
      final File file = File('build/pneumatics-r6l-evidence/$fileName');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes.buffer.asUint8List(), flush: true);
    } finally {
      image.dispose();
    }
  });
  debugPrint('R6L_CAPTURE_DONE $fileName');
}

void main() {
  testWidgets('R6/L real authored piston: before, after, and matching views', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Widget tests use the Ahem font by default; its block glyphs are
    // unsuitable as human visual evidence. Load an installed real system
    // typeface without adding font files or changing production assets.
    await tester.runAsync(() async {
      // Use an installed OS font; never attach or redistribute font assets.
      final List<String> fontPaths = <String>[
        '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
        '/System/Library/Fonts/Supplemental/Arial.ttf',
        '/System/Library/Fonts/Supplemental/Helvetica.ttf',
      ];
      File? systemFont;
      for (final String path in fontPaths) {
        final File candidate = File(path);
        if (candidate.existsSync()) {
          systemFont = candidate;
          break;
        }
      }
      if (systemFont == null) {
        if (Platform.isLinux) {
          throw StateError('Readable Linux font required for PNG evidence');
        }
        return;
      }
      final Uint8List fontBytes = await systemFont.readAsBytes();
      final FontLoader loader = FontLoader('EvidenceFont')
        ..addFont(Future<ByteData>.value(ByteData.sublistView(fontBytes)));
      await loader.load();
      final String? flutterRoot = Platform.environment['FLUTTER_ROOT'];
      if (flutterRoot != null) {
        final File iconFont = File(
          '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        );
        if (iconFont.existsSync()) {
          final Uint8List icons = await iconFont.readAsBytes();
          final FontLoader iconLoader = FontLoader('MaterialIcons')
            ..addFont(Future<ByteData>.value(ByteData.sublistView(icons)));
          await iconLoader.load();
        }
      }
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'EvidenceFont'),
        home: RepaintBoundary(
          key: const Key('r6l-live-evidence-boundary'),
          child: PneumaticWorkshopPage(initialProject: fixture.actualProject()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    debugPrint('R6L_EVIDENCE_WORKSHOP_READY');

    await tester.tap(find.byKey(const Key('device-cyl')));
    await tester.pumpAndSettle();
    final Finder initialGlyphFinder = find.descendant(
      of: find.byKey(const Key('device-cyl')),
      matching: find.byType(PneumaticDeviceGlyph),
    );
    final PneumaticDeviceGlyph initialGlyph = tester
        .widget<PneumaticDeviceGlyph>(initialGlyphFinder);
    expect(initialGlyph.pistonFraction, closeTo(.005 / .06, 1e-9));
    await captureWorkshop(tester, '01_platine_initiale.png');

    await tester.tap(find.byKey(const Key('air-advance')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, '0.8');
    await tester.tap(find.byKey(const Key('air-cd-apply')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('air-measured-position')), findsOneWidget);

    final Finder physicalGlyph = find.descendant(
      of: find.byKey(const Key('device-cyl')),
      matching: find.byType(PneumaticDeviceGlyph),
    );
    final PneumaticDeviceGlyph beforeSwitch = tester
        .widget<PneumaticDeviceGlyph>(physicalGlyph);
    expect(beforeSwitch.pistonFraction, isNotNull);
    expect(beforeSwitch.pistonFraction!, inInclusiveRange(0, 1));
    expect(beforeSwitch.pistonFraction!, greaterThan(.005 / .06 + .001));
    await captureWorkshop(tester, '02_platine_mesuree.png');

    await tester.tap(find.text('Schéma'));
    await tester.pumpAndSettle();
    final PneumaticDeviceGlyph schematic = tester.widget<PneumaticDeviceGlyph>(
      physicalGlyph,
    );
    expect(schematic.pistonFraction, beforeSwitch.pistonFraction);
    expect(find.byKey(const Key('air-measured-position')), findsOneWidget);
    await captureWorkshop(tester, '03_schema_meme_etat.png');
  });
}
