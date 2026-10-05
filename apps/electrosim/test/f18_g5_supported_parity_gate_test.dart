import 'package:electrosim/f9_component_palette.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const Set<String> supportedSourceModels = <String>{
    'dc_voltage_source',
    'dc_current_source',
    'ac_voltage_source',
    'ac_current_source',
    'ac3_voltage_source',
    'pv_array',
  };

  test('G5 exposes no decorative or unregistered electrical component', () {
    for (final F9PaletteDefinition item in f9PaletteCatalog) {
      if (item.kind == F9PaletteElementKind.source) {
        expect(
          supportedSourceModels,
          contains(item.modelType),
          reason: item.keyName,
        );
        continue;
      }

      final ComponentModelContract? contract =
          CoreComponentModelContracts.registry.resolve(item.modelType);
      expect(contract, isNotNull, reason: item.keyName);
      expect(
        item.modelType.startsWith('catalog_'),
        isFalse,
        reason:
            '${item.keyName}: catalog_* identities are visual-only and must never be electrical models',
      );
    }
  });

  test('palette mode restrictions may narrow but never broaden core contracts', () {
    for (final F9PaletteDefinition item in f9PaletteCatalog) {
      final List<ElectricalMode> visibleModes = ElectricalMode.values
          .where(item.supportsMode)
          .toList(growable: false);
      expect(visibleModes, isNotEmpty, reason: item.keyName);

      if (item.kind == F9PaletteElementKind.source) {
        continue;
      }
      final ComponentModelContract contract =
          CoreComponentModelContracts.registry.resolve(item.modelType)!;
      for (final ElectricalMode mode in visibleModes) {
        expect(
          contract.supportsMode(mode),
          isTrue,
          reason: '${item.keyName} illegally broadens ${item.modelType} to ${mode.name}',
        );
      }
    }
  });

  test('visual identity is separated from the canonical electrical model', () {
    final List<F9PaletteDefinition> decorated = f9PaletteCatalog
        .where((F9PaletteDefinition item) => item.visualModelType != null)
        .toList(growable: false);
    expect(decorated, isNotEmpty);

    for (final F9PaletteDefinition item in decorated) {
      expect(
        item.modelType.startsWith('catalog_'),
        isFalse,
        reason: item.keyName,
      );
      if (item.visualModelType == item.modelType) {
        expect(
          item.visualVariant,
          isNotNull,
          reason:
              '${item.keyName}: same electrical/visual model must still carry a physical variant',
        );
      }
    }
  });

  test('G5 mode-specific distribution identities remain physically coherent', () {
    final F9PaletteDefinition dcTerminal = f9PaletteCatalog.singleWhere(
      (F9PaletteDefinition item) => item.keyName == 'terminal-block-dc-5',
    );
    final F9PaletteDefinition ac3Terminal = f9PaletteCatalog.singleWhere(
      (F9PaletteDefinition item) => item.keyName == 'terminal-block-5',
    );

    expect(dcTerminal.modelType, ac3Terminal.modelType);
    expect(dcTerminal.visualVariant, 'dc');
    expect(ac3Terminal.visualVariant, 'ac3');
    expect(dcTerminal.supportsMode(ElectricalMode.dc), isTrue);
    expect(dcTerminal.supportsMode(ElectricalMode.ac3), isFalse);
    expect(ac3Terminal.supportsMode(ElectricalMode.ac3), isTrue);
    expect(ac3Terminal.supportsMode(ElectricalMode.dc), isFalse);
  });

  test('G5 catalog is substantial and searchable by qualified category', () {
    expect(f9PaletteCatalog.length, greaterThanOrEqualTo(60));
    final Set<String> categories = f9PaletteCatalog
        .map((F9PaletteDefinition item) => item.category)
        .toSet();
    expect(categories.length, greaterThanOrEqualTo(12));
    expect(categories, contains('Distribution CC'));
    expect(categories, contains('Distribution 3φ'));
    expect(categories, contains('Photovoltaïque'));
  });
}
