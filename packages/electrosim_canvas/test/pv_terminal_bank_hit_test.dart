import 'dart:ui' show Size;
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'compact PV bank chooses the nearest terminal when zoomed hit areas overlap',
    () {
      final ids = List.generate(4, (i) => TerminalId('MPPT-$i'));
      final circuit = CircuitState(
        circuitId: CircuitId('compact-pv'),
        revision: 0,
        mode: ElectricalMode.pv,
        components: [
          ComponentInstance(
            id: ComponentId('MPPT'),
            modelType: 'pv_controller',
            terminals: List.generate(
              4,
              (i) => Terminal(id: ids[i], name: '$i'),
            ),
          ),
        ],
      );
      final layout = CircuitVisualLayout(
        elementPositions: const {'MPPT': Offset(200, 200)},
        elementSizes: const {'MPPT': Size(200, 200)},
      );
      final engine = const HitTestEngine();
      final session = engine.prepare(circuit: circuit, layout: layout);
      // Centre 1 is 28 world units from centre 0. At 50% zoom each hit radius
      // is 22 units: this pointer is 8 from terminal 1, but 20 from terminal 0.
      final target =
          session.geometry.terminalPositions[ids[1]]! + const Offset(-8, 0);
      final hit = engine.hitTestTerminalPrepared(
        worldPoint: target,
        session: session,
        viewportScale: .5,
      );
      expect(hit.terminalId, ids[1]);
      expect(
        engine
            .hitTest(
              worldPoint: target,
              circuit: circuit,
              layout: layout,
              viewportScale: .5,
            )
            .terminalId,
        ids[1],
      );
    },
  );
}
