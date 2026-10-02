import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fixture.dart';

void main() {
  test('two-terminal Canvas placement follows electrical terminal roles', () {
    final circuit = buildTestCircuit();
    final layout = buildTestLayout();
    final geometry = CircuitGeometryIndex.build(circuit, layout);

    final source = circuit.sources.single;
    final sourcePositive = source.terminals.first.id;
    final sourceNegative = source.terminals.last.id;

    expect(
      geometry.terminalPositions[sourcePositive]!.dx,
      greaterThan(layout.positionOf('source')!.dx),
    );
    expect(
      geometry.terminalPositions[sourceNegative]!.dx,
      lessThan(layout.positionOf('source')!.dx),
    );

    final component = circuit.components.single;
    expect(
      geometry.terminalPositions[component.terminals.first.id]!.dx,
      lessThan(layout.positionOf('resistor')!.dx),
    );
    expect(
      geometry.terminalPositions[component.terminals.last.id]!.dx,
      greaterThan(layout.positionOf('resistor')!.dx),
    );
  });
}
