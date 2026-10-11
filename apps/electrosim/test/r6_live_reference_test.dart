import 'package:electrosim/pneumatics/pneumatic_reference_cycle_page.dart';
import 'package:electrosim/pneumatics/pneumatic_workshop_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('R6/C UI reads physical common-clock measurements, step, reset', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: PneumaticReferenceCyclePage()),
    );
    expect(find.byKey(const Key('r6-live-reference-cycle')), findsOneWidget);
    expect(find.text('0.000 s'), findsOneWidget);
    expect(find.text('0.00 V'), findsOneWidget);
    expect(find.byKey(const Key('r6-physical-rod')), findsOneWidget);

    await tester.tap(find.byKey(const Key('r6-start-s1')));
    await tester.pump();
    expect(find.text('24.00 V'), findsOneWidget);
    await tester.tap(find.byKey(const Key('r6-step')));
    await tester.pump();
    expect(find.text('0.005 s'), findsOneWidget);
    expect(find.byKey(const Key('r6-mass-residual')), findsOneWidget);

    await tester.tap(find.byKey(const Key('r6-reset')));
    await tester.pump();
    expect(find.text('0.000 s'), findsOneWidget);
    expect(find.text('0.00 V'), findsOneWidget);
    expect(find.byKey(const Key('r6-diagnostic')), findsNothing);
  });

  testWidgets(
    'R6/C demo remains isolated from freely edited pneumatic project',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1500, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: PneumaticWorkshopPage()));
      await tester.tap(find.byKey(const Key('r6-open-reference')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('r6-live-reference-cycle')), findsOneWidget);
      expect(
        find.textContaining('ne simule pas le câblage libre'),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pneumatic-r4-workshop')), findsOneWidget);
    },
  );
}
