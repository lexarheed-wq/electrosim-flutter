import 'package:electrosim/runtime/pneumatic_feature_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('R1-G01: electrical is the production default', () {
    const gate = PneumaticFeatureGate();
    expect(kElectroSimPneumaticExperimental, isFalse);
    expect(gate.enabled, isFalse);
    expect(gate.permits(ElectroSimWorkshopFamily.electrical), isTrue);
    expect(gate.permits(ElectroSimWorkshopFamily.pneumatic), isFalse);
    final mixed = gate.permits(ElectroSimWorkshopFamily.electropneumatic);
    expect(mixed, isFalse);
  });

  test('R1-G02: opt-in exposes all workshop families', () {
    const gate = PneumaticFeatureGate(enabled: true);
    for (final family in ElectroSimWorkshopFamily.values) {
      expect(gate.permits(family), isTrue);
    }
  });

  test('R1-G03: flag never permits lossy legacy exports', () {
    for (final enabled in <bool>[false, true]) {
      final gate = PneumaticFeatureGate(enabled: enabled);
      final keepMixed = gate.permitsLegacySave(
        containsMultiphysicsRecords: true,
      );
      final keepElectrical = gate.permitsLegacySave(
        containsMultiphysicsRecords: false,
      );
      expect(keepMixed, isFalse);
      expect(keepElectrical, isTrue);
    }
  });
}
