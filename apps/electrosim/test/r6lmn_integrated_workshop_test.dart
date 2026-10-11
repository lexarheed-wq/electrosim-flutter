import 'package:electrosim/pneumatics/pneumatic_device_glyph.dart';
import 'package:electrosim/pneumatics/pneumatic_workshop_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'r6_moving_piston_workshop_test.dart' as fixture;

/// Cross-lot regression: R6/L physical snapshots and R6/M editor history
/// must share the same workshop, not two incompatible representations.
void main() {
  testWidgets(
    'R6/L+M physical piston survives layout undo across two views',
    (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: PneumaticWorkshopPage(initialProject: fixture.actualProject()),
      ),
    );
    await tester.tap(find.byKey(const Key('device-cyl')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('air-advance')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, '0.8');
    await tester.tap(find.byKey(const Key('air-cd-apply')));
    await tester.pumpAndSettle();

    final Finder cylinder = find.byKey(const Key('device-cyl'));
    final Finder cylinderGlyph = find.descendant(
      of: cylinder,
      matching: find.byType(PneumaticDeviceGlyph),
    );
    final PneumaticDeviceGlyph initialGlyph = tester.widget<PneumaticDeviceGlyph>(
      cylinderGlyph,
    );
    final double measured = initialGlyph.pistonFraction!;
    expect(measured, inInclusiveRange(0, 1));

    await tester.tap(find.text('Schéma'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<PneumaticDeviceGlyph>(cylinderGlyph).pistonFraction,
      measured,
    );
    final Offset before = tester.getTopLeft(cylinder);
    await tester.drag(cylinder, const Offset(64, 32));
    await tester.pumpAndSettle();
    final Offset dragged = tester.getTopLeft(cylinder);
    expect(dragged.dx - before.dx, closeTo(64, 3));
    expect(dragged.dy - before.dy, closeTo(32, 3));
    expect(
      tester.widget<PneumaticDeviceGlyph>(cylinderGlyph).pistonFraction,
      measured,
    );

    await tester.tap(find.byKey(const Key('air-undo')));
    await tester.pumpAndSettle();
    final Offset restored = tester.getTopLeft(cylinder);
    expect(restored.dx, closeTo(before.dx, 3));
    expect(restored.dy, closeTo(before.dy, 3));
    expect(
      tester.widget<PneumaticDeviceGlyph>(cylinderGlyph).pistonFraction,
      measured,
    );
    expect(find.byKey(const Key('air-measured-position')), findsOneWidget);
    },
  );
}
