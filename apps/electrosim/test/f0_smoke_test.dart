import 'package:electrosim/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ElectroSim app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const app.ElectroSimApp());
    expect(find.text('ElectroSim'), findsOneWidget);
  });
}
