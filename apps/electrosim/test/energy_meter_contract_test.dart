import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final e in {'energy_meter_ac1': 4, 'energy_meter_ac3': 8}.entries) {
    test('${e.key} exposes independent feed-through poles', () {
      final c = CoreComponentModelContracts.registry.resolve(e.key);
      expect(c, isNotNull);
      expect(c!.terminalCount, e.value);
      expect(c.branches.length, e.value ~/ 2);
      expect(
        CoreComponentPhysicsContracts.resolve(e.key)!.electricalLaw,
        ComponentElectricalLaw.feedThrough,
      );
      for (var i = 0; i < c.branches.length; i++) {
        expect(c.branches[i].fromTerminalIndex, i);
        expect(c.branches[i].toTerminalIndex, i + c.branches.length);
      }
    });
  }
}
