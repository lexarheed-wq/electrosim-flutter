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
Future<void> captureWorkshop(
  WidgetTester tester,
  String fileName,
) async {
  final RenderRepaintBoundary boundary = tester.renderObject(
    find.byKey(const Key('r6l-live-evidence-boundary')),
  );
  final ui.Image image = await boundary.toImage(pixelRatio: 1);
  try {
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (bytes == null) {
      throw StateError('Flutter failed to encode the actual workshop PNG');
    }
    final File file = File('build/pneumatics-r6l-evidence/$fileName');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
  } finally {
    image.dispose();
  }
}

void main() {
  testWidgets('R6/L real authored piston: before, after, and matching views', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: const Key('r6l-live-evidence-boundary'),
          child: PneumaticWorkshopPage(initialProject: fixture.actualProject()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('device-cyl')));
    await tester.pumpAndSettle();
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
    final PneumaticDeviceGlyph beforeSwitch =
        tester.widget<PneumaticDeviceGlyph>(physicalGlyph);
    expect(beforeSwitch.pistonFraction, isNotNull);
    expect(beforeSwitch.pistonFraction!, inInclusiveRange(0, 1));
    expect(beforeSwitch.pistonFraction!, greaterThan(.005 / .06 + .001));
    await captureWorkshop(tester, '02_platine_mesuree.png');

    await tester.tap(find.text('Schéma'));
    await tester.pumpAndSettle();
    final PneumaticDeviceGlyph schematic =
        tester.widget<PneumaticDeviceGlyph>(physicalGlyph);
    expect(schematic.pistonFraction, beforeSwitch.pistonFraction);
    expect(find.byKey(const Key('air-measured-position')), findsOneWidget);
    await captureWorkshop(tester, '03_schema_meme_etat.png');
  });
}
