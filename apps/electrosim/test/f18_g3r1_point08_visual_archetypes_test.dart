import 'dart:io';

import 'package:electrosim/f18_component_archetypes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('F18 classifier covers the eight electrical archetypes', () {
    expect(
      F18ElectricalArchetype.values,
      containsAll(<F18ElectricalArchetype>[
        F18ElectricalArchetype.source,
        F18ElectricalArchetype.protection,
        F18ElectricalArchetype.control,
        F18ElectricalArchetype.load,
        F18ElectricalArchetype.rotatingMachine,
        F18ElectricalArchetype.measurement,
        F18ElectricalArchetype.conversion,
        F18ElectricalArchetype.pvEnergy,
      ]),
    );
  });

  test('current production models map to specific F18 archetypes', () {
    expect(
      F18ElectricalArchetypeClassifier.forModel('dc_voltage_source'),
      F18ElectricalArchetype.source,
    );
    expect(
      F18ElectricalArchetypeClassifier.forModel('breaker'),
      F18ElectricalArchetype.protection,
    );
    expect(
      F18ElectricalArchetypeClassifier.forModel('switch'),
      F18ElectricalArchetype.control,
    );
    expect(
      F18ElectricalArchetypeClassifier.forModel('lamp'),
      F18ElectricalArchetype.load,
    );
    expect(
      F18ElectricalArchetypeClassifier.forModel('motor_dc'),
      F18ElectricalArchetype.rotatingMachine,
    );
    expect(
      F18ElectricalArchetypeClassifier.forModel('voltmeter'),
      F18ElectricalArchetype.measurement,
    );
    expect(
      F18ElectricalArchetypeClassifier.forModel('inverter'),
      F18ElectricalArchetype.conversion,
    );
    expect(
      F18ElectricalArchetypeClassifier.forModel('pv_panel'),
      F18ElectricalArchetype.pvEnergy,
    );
  });

  test('palette and canvas no longer use legacy F9 glyph painter', () {
    final String palette =
        File('lib/f9_component_palette.dart').readAsStringSync();
    final String visuals =
        File('lib/f9_component_visuals.dart').readAsStringSync();

    expect(palette, contains('F18ComponentArchetypeGlyph'));
    expect(visuals, contains('paintF18ElectricalArchetype'));
    expect(palette, isNot(contains('F9ComponentGlyph(')));
    expect(visuals, isNot(contains('paintF9Glyph(')));
  });
}
