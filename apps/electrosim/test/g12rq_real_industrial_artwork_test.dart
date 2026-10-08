import 'package:electrosim/f18_component_asset_visual.dart';
import 'package:electrosim/f18_industrial_physical_devices.dart';
import 'package:electrosim/reference_components/reference_widgets.dart';
import 'package:electrosim/reference_components/reference_widgets_extended.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('actual industrial artwork replaces eight legacy models', () {
    const expected = <String, IndustrialDevice>{
      'dc_voltage_source': IndustrialDevice.supply,
      'breaker_dc': IndustrialDevice.breaker,
      'switch_spst': IndustrialDevice.toggle,
      'push_button_no': IndustrialDevice.button,
      'lamp': IndustrialDevice.lamp,
      'fan_dc': IndustrialDevice.fan,
      'motor_dc': IndustrialDevice.motor,
      'relay_coil': IndustrialDevice.coil,
    };
    for (final entry in expected.entries) {
      expect(
        IndustrialDeviceContract.resolve(entry.key),
        entry.value,
        reason: entry.key,
      );
    }
    expect(
      IndustrialDeviceContract.resolve('breaker_3p'),
      isNull,
      reason: 'Do not show a 2-terminal 1P housing for 6-terminal protection',
    );
  });

  test(
    'all eight anchors remain bit-for-bit aligned to old board contracts',
    () {
      const short = <IndustrialDevice, ReferenceDevice>{
        IndustrialDevice.supply: ReferenceDevice.supply,
        IndustrialDevice.breaker: ReferenceDevice.breaker,
        IndustrialDevice.toggle: ReferenceDevice.toggle,
        IndustrialDevice.button: ReferenceDevice.button,
        IndustrialDevice.lamp: ReferenceDevice.lamp,
      };
      for (final entry in short.entries) {
        expect(
          IndustrialDeviceContract.designSize(entry.key),
          ReferenceComponentGeometry.forDevice(entry.value).designSize,
        );
        expect(
          IndustrialDeviceContract.anchors(entry.key),
          ReferenceComponentGeometry.forDevice(entry.value).terminals,
        );
      }
      const extended = <IndustrialDevice, ExtendedReferenceDevice>{
        IndustrialDevice.fan: ExtendedReferenceDevice.fan,
        IndustrialDevice.motor: ExtendedReferenceDevice.motor,
        IndustrialDevice.coil: ExtendedReferenceDevice.relayCoil,
      };
      for (final entry in extended.entries) {
        expect(
          IndustrialDeviceContract.designSize(entry.key),
          ExtendedReferenceGeometry.designSizeFor(entry.value),
        );
        expect(
          IndustrialDeviceContract.anchors(entry.key),
          ExtendedReferenceGeometry.terminalOffsetsFor(entry.value),
        );
      }
    },
  );

  for (final model in <String>[
    'dc_voltage_source',
    'breaker_dc',
    'switch_spst',
    'push_button_no',
    'lamp',
    'fan_dc',
    'motor_dc',
    'relay_coil',
  ]) {
    testWidgets('$model mounts the REAL replacement painter on a board', (
      tester,
    ) async {
      final device = IndustrialDeviceContract.resolve(model)!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: F18ComponentAssetVisual(
                modelType: model,
                size: IndustrialDeviceContract.designSize(device),
                energized: true,
                voltageV: 24,
                currentA: 1.5,
                ratedCurrentA: 16,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(IndustrialPhysicalView), findsOneWidget);
      expect(find.byKey(Key('new-industrial-${device.name}')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('trip and opening are projections of the runtime state only', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: F18ComponentAssetVisual(
            modelType: 'breaker_dc',
            size: Size(72, 160),
            closed: false,
            tripped: true,
          ),
        ),
      ),
    );
    final view = tester.widget<IndustrialPhysicalView>(
      find.byType(IndustrialPhysicalView),
    );
    expect(view.closed, isFalse);
    expect(view.tripped, isTrue);
    expect(view.showTerminals, isTrue);
  });
}
