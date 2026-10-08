import 'package:electrosim/f9_component_palette.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_measurements/electrosim_measurements.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PV-LOAD02 exposes canonical 230 V lamp in PV palette', () {
    final F9PaletteDefinition lamp = f9PaletteCatalog.singleWhere(
      (F9PaletteDefinition item) => item.keyName == 'lamp-ac1-230v',
    );
    expect(lamp.supportsMode(ElectricalMode.pv), isTrue);
    expect(lamp.modelType, 'lamp');
    expect(lamp.defaultParameters[ReceiverNominalRating.voltageKey], 230.0);
  });

  test('PV-LOAD02 runtime state for canonical PV-side AC receiver is not model-name gated', () {
    final ComponentInstance lamp = ComponentInstance(
      id: ComponentId('lamp'),
      modelType: 'lamp',
      terminals: <Terminal>[
        Terminal(id: TerminalId('a'), name: 'A'),
        Terminal(id: TerminalId('b'), name: 'B'),
      ],
      parameters: const <String, Object?>{
        'resistanceOhm': 529.0,
        'receiverNominalVoltageV': 230.0,
        'receiverNominalCurrentA': 0.43478260869565216,
        'receiverNominalPowerW': 100.0,
      },
    );
    final PvSolveResult result = PvSolveResult(
      circuitId: CircuitId('c'),
      circuitRevision: 0,
      engineVersion: 'test',
      status: PvSolveStatus.solved,
      irradianceWm2: 1000,
      cellTemperatureC: 25,
      pvOperatingVoltageV: 360,
      pvAvailableCurrentA: 10,
      pvAvailablePowerW: 3600,
      pvDrawnCurrentA: 1,
      pvDrawnPowerW: 105,
      curtailedPowerW: 3495,
      inverterState: PvInverterState.running,
      inverterEfficiency: 0.96,
      inverterOutputVoltageRmsV: 230,
      inverterOutputCurrentRmsA: 100 / 230,
      inverterOutputPowerW: 100,
      inverterConversionLossW: 5,
      controllerPresent: false,
      controllerEfficiency: 1,
      controllerConversionLossW: 0,
      batteryPresent: false,
      batteryVoltageV: 0,
      batterySoc: 0,
      batteryStoredEnergyWh: 0,
      batteryPowerW: 0,
      batteryConversionLossW: 0,
      loadResults: <PvLoadResult>[
        PvLoadResult(
          componentId: lamp.id,
          voltageRmsV: 230,
          currentRmsA: 100 / 230,
          activePowerW: 100,
        ),
      ],
      diagnostics: const <PvSolverDiagnostic>[],
    );
    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('c'),
      revision: 0,
      mode: ElectricalMode.pv,
      components: <ComponentInstance>[lamp],
    );
    final ComponentOperatingState state = const DeviceStateEngine().evaluatePv(
      component: lamp,
      circuit: circuit,
      simulation: result,
    );
    expect(state.code, ComponentOperatingCode.energized);
    expect(state.voltageV, closeTo(230, 1e-9));
    expect(state.currentA, closeTo(100 / 230, 1e-9));
    expect(state.powerW, closeTo(100, 1e-9));
  });
}
