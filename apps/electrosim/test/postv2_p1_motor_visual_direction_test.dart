import 'package:electrosim/f18_component_asset_visual.dart';
import 'package:electrosim/f18_industrial_physical_devices.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<double> motorRotorAngle(WidgetTester tester, double currentA) async {
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: F18ComponentAssetVisual(
          modelType: 'motor_dc',
          size: const Size(230, 190),
          energized: true,
          currentA: currentA,
          voltageV: currentA < 0 ? -24 : 24,
          animationValue: .25,
        ),
      ),
    ));
    final view = tester.widget<IndustrialPhysicalView>(
      find.byType(IndustrialPhysicalView),
    );
    expect(view.device, IndustrialDevice.motor);
    expect(view.currentA, currentA);
    return IndustrialPhysicalView.signedMotorPhaseAngle(
      view.animationValue, view.currentA, energized: view.energized,
    );
  }

  testWidgets('P1.4 motor animated shaft preserves solver current direction',
      (tester) async {
    final forward = await motorRotorAngle(tester, 1.0);
    final reverse = await motorRotorAngle(tester, -1.0);
    expect(forward, greaterThan(0));
    expect(reverse, lessThan(0));
    expect(forward.abs(), closeTo(reverse.abs(), 1e-12));
    expect(
      IndustrialPhysicalView.signedMotorPhaseAngle(
        .25, 1, energized: false),
      0,
    );
  });
}
