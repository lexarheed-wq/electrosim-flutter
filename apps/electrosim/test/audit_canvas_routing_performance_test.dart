import 'dart:io';

import 'package:electrosim/runtime/electrosim_connection_router.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/regression_fixture.dart';

String _workspaceSource() =>
    File('lib/f18_workspace_page.dart').readAsStringSync();

void main() {
  test(
    'insertion and pointer-up never invoke global routing synchronously',
    () {
      final String source = _workspaceSource();
      final int moveStart = source.indexOf('void _commitElementMoveIfSafe(');
      final int moveEnd = source.indexOf(
        'void _cancelCanvasInteraction(',
        moveStart,
      );
      final String movePath = source.substring(moveStart, moveEnd);
      expect(movePath, isNot(contains('_routeWithG2A(')));
      expect(movePath, contains('routeChangedElement('));

      final int insertStart = source.indexOf(
        'final CircuitState nextCircuit = CircuitState(',
        source.indexOf('void _add'),
      );
      expect(insertStart, greaterThan(0));
      final int insertEnd = source.indexOf(
        'List<Terminal> _buildPaletteTerminals(',
        insertStart,
      );
      final String insertPath = source.substring(insertStart, insertEnd);
      expect(insertPath, isNot(contains('_routeWithG2A(')));
      expect(insertPath, contains('_finishElementRoute('));
    },
  );

  testWidgets(
    'worker reroutes moved terminal endpoints without changing the circuit',
    (tester) async {
      final circuit = buildRegressionFixtureCircuit();
      const engine = CircuitWireLayoutEngine(
        router: OrthogonalWireRouter(
          grid: 24,
          obstacleClearance: 24,
          envelopePadding: 120,
        ),
      );
      final base = engine.routeAll(
        circuit: circuit,
        layout: CircuitVisualLayout(
          elementPositions: const <String, Offset>{
            'source-24v': Offset(120, 120),
            'switch-1': Offset(360, 120),
            'lamp-1': Offset(600, 120),
          },
        ),
      );
      final moved = base.moveElement('lamp-1', const Offset(600, 312));
      final worker = ElectroSimConnectionRouter();
      addTearDown(worker.dispose);
      final CircuitVisualLayout? result = await tester
          .runAsync<CircuitVisualLayout?>(
            () => worker.routeChangedElement(
              circuit: circuit,
              layout: moved,
              elementId: 'lamp-1',
            ),
          );
      expect(result, isNotNull);
      expect(result!.positionOf('lamp-1'), const Offset(600, 312));
      for (final connection in circuit.connections) {
        final route = result.routeFor(connection.id.value);
        for (var i = 1; i < route.length; i++) {
          expect(
            route[i - 1].dx == route[i].dx || route[i - 1].dy == route[i].dy,
            isTrue,
            reason: connection.id.value,
          );
        }
      }
    },
  );
}
