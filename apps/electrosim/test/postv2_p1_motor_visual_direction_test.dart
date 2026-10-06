import 'package:electrosim/f18_component_asset_visual.dart';
import 'package:electrosim/reference_components/reference_widgets_extended.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<double> motorRpm(WidgetTester tester, double currentA) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: F18ComponentAssetVisual(
            modelType: 'motor_dc',
            size: const Size(230, 190),
            energized: true,
            currentA: currentA,
            voltageV: currentA.isNegative ? -24 : 24,
            animationValue: 0.25,
          ),
        ),
      ),
    );
    final ExtendedReferenceComponentView view =
        tester.widget<ExtendedReferenceComponentView>(
          find.byType(ExtendedReferenceComponentView),
        );
    expect(view.device, ExtendedReferenceDevice.motor);
    return view.state.speedRpm;
  }

  testWidgets('P1.4 motor animation direction follows signed solver current', (
    WidgetTester tester,
  ) async {
    final double forward = await motorRpm(tester, 1.0);
    final double reverse = await motorRpm(tester, -1.0);

    expect(forward, greaterThan(0.0));
    expect(reverse, lessThan(0.0));
    expect(forward.abs(), closeTo(reverse.abs(), 1e-12));
  });
}
