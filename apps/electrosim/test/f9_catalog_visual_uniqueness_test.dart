import 'package:electrosim/f9_component_palette.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('palette keys and titles are unique', () {
    expect(
      f9PaletteCatalog.map((F9PaletteDefinition item) => item.keyName).toSet(),
      hasLength(f9PaletteCatalog.length),
    );
    expect(
      f9PaletteCatalog.map((F9PaletteDefinition item) => item.title).toSet(),
      hasLength(f9PaletteCatalog.length),
    );
  });

  for (final ElectricalMode mode in ElectricalMode.values) {
    test('visual identities are not duplicated accidentally in ${mode.name}', () {
      final Map<String, List<String>> identities = <String, List<String>>{};
      for (final F9PaletteDefinition item in f9PaletteCatalog) {
        if (!item.supportsMode(mode)) {
          continue;
        }
        final String identity =
            '${item.renderedModelType}|${item.visualVariant ?? 'default'}';
        identities.putIfAbsent(identity, () => <String>[]).add(item.keyName);
      }

      final Map<String, List<String>> duplicates =
          Map<String, List<String>>.fromEntries(
            identities.entries.where((MapEntry<String, List<String>> entry) {
              return entry.value.length > 1;
            }),
          );
      expect(
        duplicates,
        isEmpty,
        reason:
            'Two visible entries in the same electrical mode must not collapse to the same visual identity.',
      );
    });
  }
}
