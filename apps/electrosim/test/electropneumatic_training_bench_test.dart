import 'package:electrosim/pneumatics/electropneumatic_training_bench_page.dart';
import 'package:electrosim/pneumatics/pneumatic_workshop_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('workshop opens the authored electro-pneumatic bench', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PneumaticWorkshopPage()),
    );

    await tester.tap(find.byKey(const Key('open-electropneumatic-training-bench')));
    await tester.pumpAndSettle();

    expect(find.byType(ElectropneumaticTrainingBenchPage), findsOneWidget);
    expect(find.byKey(const Key('ep-start-s1')), findsOneWidget);
    expect(find.text('0.00 V'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ep-start-s1')));
    await tester.pumpAndSettle();
    expect(find.text('24.00 V'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ep-step')));
    await tester.pumpAndSettle();
    expect(find.text('0.005 s'), findsOneWidget);
    expect(find.byKey(const Key('ep-error')), findsNothing);
  });
}
