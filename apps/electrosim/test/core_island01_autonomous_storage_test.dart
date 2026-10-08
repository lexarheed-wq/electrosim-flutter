import 'package:electrosim/f9_component_palette.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim/runtime/electrosim_simulation_controller.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_measurements/electrosim_measurements.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'CORE-ISLAND01 PV workspace resolves standalone battery + 48 V lamp as DC',
    () async {
      final Terminal bp = Terminal(
        id: TerminalId('bat-pos'),
        name: '+',
        role: TerminalRole.positive,
        phase: PhaseTag.dcPositive,
      );
      final Terminal bn = Terminal(
        id: TerminalId('bat-neg'),
        name: '-',
        role: TerminalRole.negative,
        phase: PhaseTag.dcNegative,
      );
      final Terminal la = Terminal(id: TerminalId('lamp-a'), name: 'A');
      final Terminal lb = Terminal(id: TerminalId('lamp-b'), name: 'B');

      final F9PaletteDefinition battery = f9PaletteCatalog.singleWhere(
        (F9PaletteDefinition item) => item.keyName == 'pv-battery',
      );
      final F9PaletteDefinition lamp = f9PaletteCatalog.singleWhere(
        (F9PaletteDefinition item) => item.keyName == 'lamp-dc-48v',
      );
      expect(battery.supportsMode(ElectricalMode.dc), isTrue);
      expect(battery.supportsMode(ElectricalMode.pv), isTrue);
      expect(lamp.supportsMode(ElectricalMode.pv), isTrue);

      final CircuitState circuit = CircuitState(
        circuitId: CircuitId('pv-workspace-autonomous-battery'),
        revision: 0,
        mode: ElectricalMode.pv,
        components: <ComponentInstance>[
          ComponentInstance(
            id: ComponentId('battery'),
            modelType: battery.modelType,
            terminals: <Terminal>[bp, bn],
            parameters: battery.defaultParameters,
          ),
          ComponentInstance(
            id: ComponentId('lamp'),
            modelType: lamp.modelType,
            terminals: <Terminal>[la, lb],
            parameters: lamp.defaultParameters,
          ),
        ],
        connections: <Connection>[
          Connection(
            id: ConnectionId('w1'),
            fromTerminalId: bp.id,
            toTerminalId: la.id,
            phase: PhaseTag.dcPositive,
          ),
          Connection(
            id: ConnectionId('w2'),
            fromTerminalId: lb.id,
            toTerminalId: bn.id,
            phase: PhaseTag.dcNegative,
          ),
        ],
      );

      final ElectroSimRuntimeSnapshot snapshot = const ElectroSimRuntimeEngine()
          .evaluate(circuit);

      expect(snapshot.solverKind, ElectroSimRuntimeSolverKind.dc);
      expect(snapshot.solved, isTrue);
      expect(snapshot.effectiveCircuit.mode, ElectricalMode.dc);
      final ComponentOperatingState state = snapshot.componentOperatingState(
        ComponentId('lamp'),
      )!;
      expect(state.voltageV, closeTo(47.92, 0.05));
      expect(state.currentA, closeTo(0.998, 0.01));

      // The PV palette battery is solved through DC. Its SOC must be visible,
      // evolve with energy consumed, and stop supplying below minSOC.
      final ElectroSimSimulationController controller =
          ElectroSimSimulationController(circuit: circuit);
      addTearDown(controller.dispose);
      final ComponentId batteryId = ComponentId('battery');
      final double initial = controller.snapshot.dcBatterySocs[batteryId]!;
      expect(initial, closeTo(0.60, 1e-8));
      controller.advance(const Duration(hours: 1));
      final double discharged = controller.snapshot.dcBatterySocs[batteryId]!;
      expect(discharged, lessThan(initial));
      expect(discharged, greaterThanOrEqualTo(0.10));
      controller.advance(const Duration(hours: 100));
      expect(controller.snapshot.dcBatterySocs[batteryId], closeTo(0.10, 1e-8));
      controller.advance(const Duration(seconds: 1));
      final ComponentOperatingState afterCutoff = controller.snapshot
          .componentOperatingState(ComponentId('lamp'))!;
      expect(afterCutoff.currentA ?? 0.0, closeTo(0.0, 1e-6));

      // G12-RQ: an accelerated minute and hour advance physical energy,
      // protection and battery SOC, not only the displayed clock.
      controller.resetDynamics();
      expect(controller.simulatedTime, Duration.zero);
      await controller.advanceBy(const Duration(minutes: 1));
      expect(controller.simulatedTime, const Duration(minutes: 1));
      final double socAfterMinute =
          controller.snapshot.dcBatterySocs[batteryId]!;
      expect(socAfterMinute, lessThan(initial));
      expect(socAfterMinute, greaterThan(0.10));
      await controller.advanceBy(const Duration(hours: 1));
      expect(controller.simulatedTime, const Duration(minutes: 61));
      final double afterHour = controller.snapshot.dcBatterySocs[batteryId]!;
      // The default battery is 100 Ah, not the 1 Ah scientific audit example.
      // One hour cannot consume its entire reserve.
      expect(afterHour, lessThan(socAfterMinute));
      expect(afterHour, greaterThan(0.10));
      await controller.advanceBy(const Duration(hours: 24));
      expect(controller.simulatedTime, const Duration(minutes: 1501));
      final double afterDay = controller.snapshot.dcBatterySocs[batteryId]!;
      expect(afterDay, lessThan(afterHour));
      controller.advance(const Duration(hours: 100));
      controller.advance(const Duration(seconds: 1));
      expect(controller.snapshot.dcBatterySocs[batteryId], closeTo(0.10, 1e-7));
      final ComponentOperatingState depleted = controller.snapshot
          .componentOperatingState(ComponentId('lamp'))!;
      expect(depleted.currentA ?? 0.0, closeTo(0.0, 1e-6));
      controller.resetDynamics();
      expect(controller.simulatedTime, Duration.zero);
      expect(
        controller.snapshot.dcBatterySocs[batteryId],
        closeTo(initial, 1e-8),
      );
    },
  );
}
