import 'package:electrosim/f18_industrial_physical_plate.dart';
import 'package:electrosim/f9_component_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('real palette forwards the displayed 100 ohm resistor rating', (
    t,
  ) async {
      expect(await t.runAsync(F18PhysicalPlateAssets.preload), isTrue);
    final definition = f9PaletteCatalog.firstWhere(
      (d) => d.keyName == 'resistor',
    );
    await t.pumpWidget(
      MaterialApp(home: F9ComponentPreview(definition: definition)),
    );
    await t.pumpAndSettle();
    expect(
      t
          .widget<F18IndustrialPhysicalPlate>(
            find.byType(F18IndustrialPhysicalPlate),
          )
          .resistanceOhm,
      100,
    );
  });
  test('resistor marking follows the simulated value rather than a photo', () {
    expect(physicalResistorBands(100), [
      const Color(0xFF633C25),
      Colors.black,
      const Color(0xFF633C25),
    ]);
    expect(physicalResistorBands(47000), [
      const Color(0xFFF2CB22),
      const Color(0xFF793FA1),
      const Color(0xFFE87917),
    ]);
    expect(physicalResistorBands(.1), [
      const Color(0xFF633C25),
      Colors.black,
      const Color(0xFFBFC5C9),
    ]);
  });
  test('unrepresentable or invalid resistance never receives a false code', () {
    for (final value in [0.0, -1.0, double.nan, double.infinity, 100.5]) {
      expect(physicalResistorBands(value), isEmpty);
    }
  });
}
