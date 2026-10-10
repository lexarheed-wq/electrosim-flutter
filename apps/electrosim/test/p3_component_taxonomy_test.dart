import 'package:electrosim/f18_component_archetypes.dart';
import 'package:electrosim/f18_industrial_dual_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P3 electrical archetypes and physical family share model taxonomy',
      () {
    const examples = <String, (F18ElectricalArchetype, F18IndustrialFamily)>{
      'breaker_ac1': (
        F18ElectricalArchetype.protection,
        F18IndustrialFamily.modularProtection
      ),
      'contactor_3p': (
        F18ElectricalArchetype.control,
        F18IndustrialFamily.switching
      ),
      'motor_3p_6t': (
        F18ElectricalArchetype.rotatingMachine,
        F18IndustrialFamily.drive
      ),
      'pv_battery': (
        F18ElectricalArchetype.pvEnergy,
        F18IndustrialFamily.solar
      ),
      'physical_voltmeter': (
        F18ElectricalArchetype.measurement,
        F18IndustrialFamily.instrument
      ),
      'resistor': (
        F18ElectricalArchetype.load,
        F18IndustrialFamily.passive
      ),
    };
    for (final entry in examples.entries) {
      expect(
        F18ElectricalArchetypeClassifier.forModel(entry.key),
        entry.value.$1,
        reason: entry.key,
      );
      expect(
        F18IndustrialIdentity.familyOf(entry.key),
        entry.value.$2,
        reason: entry.key,
      );
    }
  });
}
