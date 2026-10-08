import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/regression_fixture.dart';

void main() {
  test('unchanged snapshot reuses wire evidence across animation frames', () {
    final circuit = buildRegressionFixtureCircuit();
    final snapshot = const ElectroSimRuntimeEngine().evaluate(circuit);
    expect(snapshot.solved, isTrue);
    final connection = circuit.connections.first;
    final first = snapshot.connectionCurrentEvidence(connection);
    final second = snapshot.connectionCurrentEvidence(connection);
    expect(first.magnitudeA, greaterThan(0));
    expect(second, same(first));
  });

  test('new snapshot and reversed connection do not reuse stale evidence', () {
    final circuit = buildRegressionFixtureCircuit();
    final snapshot = const ElectroSimRuntimeEngine().evaluate(circuit);
    final connection = circuit.connections.first;
    final forward = snapshot.connectionCurrentEvidence(connection);
    final reverse = snapshot.connectionCurrentEvidence(
      Connection(
        id: connection.id,
        fromTerminalId: connection.toTerminalId,
        toTerminalId: connection.fromTerminalId,
      ),
    );
    expect(reverse.signedCurrentA, closeTo(-forward.signedCurrentA, 1e-9));
    final next = const ElectroSimRuntimeEngine().evaluate(circuit);
    expect(next.connectionCurrentEvidence(connection), isNot(same(forward)));
  });
}
