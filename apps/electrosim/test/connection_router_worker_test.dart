import 'package:electrosim/runtime/electrosim_connection_router.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/regression_fixture.dart';

void main() {
  testWidgets(
    'native worker returns usable geometry and discards superseded jobs',
    (tester) async {
      final circuit = buildRegressionFixtureCircuit();
      final layout = CircuitVisualLayout(
        elementPositions: const {
          'source-24v': Offset(120, 120),
          'switch-1': Offset(360, 120),
          'lamp-1': Offset(600, 120),
        },
      );
      final worker = ElectroSimConnectionRouter();
      addTearDown(worker.dispose);
      await tester.runAsync(() async {
        final first = worker.route(
          circuit: circuit,
          layout: layout,
          connectionId: circuit.connections.first.id,
        );
        final second = worker.route(
          circuit: circuit,
          layout: layout,
          connectionId: circuit.connections[1].id,
        );
        final third = worker.route(
          circuit: circuit,
          layout: layout,
          connectionId: circuit.connections.last.id,
        );
        expect(await second, isNull);
        expect(await first, isNull);
        final result = await third;
        expect(result, isNotNull);
        expect(
          result!.wireRoutes.keys,
          containsAll(circuit.connections.map((item) => item.id.value)),
        );
        worker.dispose();
        expect(
          await worker.route(
            circuit: circuit,
            layout: layout,
            connectionId: circuit.connections.first.id,
          ),
          isNull,
        );
      });
    },
  );
}
