import 'package:electrosim/runtime/pneumatic_feature_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('R1-G01: production defaults to electrical-only workshop', () {
    const PneumaticFeatureGate gate = PneumaticFeatureGate();
    expect(kElectroSimPneumaticExperimental, isFalse);
    expect(gate.enabled, isFalse);
    expect(gate.permits(ElectroSimWorkshopFamily.electrical), isTrue);
    expect(gate.permits(ElectroSimWorkshopFamily.pneumatic), isFalse);
    expect(gate.permits(ElectroSimWorkshopFamily.electropneumatic), isFalse);
  });

  test('R1-G02: enablement does not reclassify electrical modes', () {
    const PneumaticFeatureGate enabled = PneumaticFeatureGate(enabled: true);
    for (final ElectroSimWorkshopFamily family
        in ElectroSimWorkshopFamily.values) {
      expect(enabled.permits(family), isTrue);
    }
  });

  test('R1-G03: disabling the feature must not authorize lossy legacy export', () {
    for (final bool enabled in <bool>[false, true]) {
      final PneumaticFeatureGate gate = PneumaticFeatureGate(enabled: enabled);
      expect(gate.permitsLegacySave(containsMultiphysicsRecords: true), isFalse);
      expect(gate.permitsLegacySave(containsMultiphysicsRecords: false), isTrue);
    }
  });
}
