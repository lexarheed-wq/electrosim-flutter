import 'package:electrosim/f9_component_palette.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M3B palette uses canonical DC protection model types', () {
    final F9PaletteDefinition breaker = f9PaletteCatalog.singleWhere(
      (F9PaletteDefinition item) => item.keyName == 'breaker',
    );
    final F9PaletteDefinition fuse = f9PaletteCatalog.singleWhere(
      (F9PaletteDefinition item) => item.keyName == 'fuse',
    );

    expect(breaker.modelType, 'breaker_dc');
    expect(fuse.modelType, 'fuse_dc');
  });

  test('M3B DC palette retains canonical engine-supported receiver types', () {
    final Set<String> types = f9PaletteCatalog
        .map((F9PaletteDefinition item) => item.modelType)
        .toSet();

    expect(
      types,
      containsAll(<String>[
        'push_button_no',
        'buzzer',
        'fan_dc',
        'motor_dc',
        'relay_coil',
      ]),
    );
  });
}
