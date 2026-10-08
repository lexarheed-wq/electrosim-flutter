import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_pv/electrosim_pv.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  const SolverPV solver = SolverPV();
  const TopologyEngine topologyEngine = TopologyEngine();

  PvSolveResult solve(CircuitState circuit) =>
      solver.solve(circuit, topologyEngine.compile(circuit));

  group('SolverPV', () {
    test(
      'PV-002 nominal PV/inverter/load power flow is physically balanced',
      () {
        final PvSolveResult result = solve(_pvCircuit(loadPowerAt230W: 2000.0));
        expect(result.status, PvSolveStatus.solved);
        expect(result.engineVersion, SolverPV.engineVersion);
        expect(result.pvOperatingVoltageV, closeTo(400.0, 1e-9));
        expect(result.pvAvailableCurrentA, closeTo(10.0, 1e-9));
        expect(result.pvAvailablePowerW, closeTo(4000.0, 1e-9));
        expect(result.inverterState, PvInverterState.running);
        expect(result.inverterOutputVoltageRmsV, closeTo(230.0, 1e-9));
        expect(result.inverterOutputPowerW, closeTo(2000.0, 1e-7));
        expect(result.pvDrawnPowerW, closeTo(2000.0 / 0.95, 1e-7));
        expect(
          result.inverterConversionLossW,
          closeTo((2000.0 / 0.95) - 2000.0, 1e-7),
        );
        expect(
          result.pvDrawnPowerW,
          closeTo(
            result.inverterOutputPowerW + result.inverterConversionLossW,
            1e-8,
          ),
        );
        expect(result.curtailedPowerW, greaterThan(1800.0));
        expect(
          result.load(ComponentId('load')).activePowerW,
          closeTo(2000.0, 1e-7),
        );
      },
    );

    test(
      'PV-002 low irradiance reduces available power and causes real output droop',
      () {
        final PvSolveResult result = solve(
          _pvCircuit(loadPowerAt230W: 3000.0, irradianceWm2: 500.0),
        );
        expect(result.status, PvSolveStatus.solved);
        expect(result.pvAvailablePowerW, closeTo(2000.0, 1e-7));
        expect(result.inverterState, PvInverterState.powerLimited);
        expect(result.inverterOutputPowerW, closeTo(1900.0, 1e-6));
        expect(result.inverterOutputVoltageRmsV, lessThan(230.0));
        expect(result.inverterOutputVoltageRmsV, greaterThan(0.0));
      },
    );

    test(
      'M8 shading reduces effective irradiance without changing raw setting semantics',
      () {
        final PvSolveResult result = solve(
          _pvCircuit(
            loadPowerAt230W: 3000.0,
            irradianceWm2: 800.0,
            shadingPct: 25.0,
          ),
        );
        expect(result.status, PvSolveStatus.solved);
        expect(result.irradianceWm2, closeTo(600.0, 1e-9));
        expect(result.pvAvailablePowerW, closeTo(2400.0, 1e-7));
      },
    );

    test('M8 invalid shading fails explicitly', () {
      final PvSolveResult result = solve(
        _pvCircuit(invalidShadingSetting: true),
      );
      expect(result.status, PvSolveStatus.invalid);
      expect(
        result.diagnostics.map((PvSolverDiagnostic item) => item.code),
        contains(PvDiagnosticCode.invalidPvParameter),
      );
    });

    test('PV-003 temperature coefficients are applied explicitly', () {
      final PvSolveResult result = solve(
        _pvCircuit(
          loadPowerAt230W: 1000.0,
          cellTemperatureC: 50.0,
          powerTemperatureCoefficientPerC: -0.004,
          voltageTemperatureCoefficientPerC: -0.002,
        ),
      );
      expect(result.status, PvSolveStatus.solved);
      expect(result.pvAvailablePowerW, closeTo(3600.0, 1e-7));
      expect(result.pvOperatingVoltageV, closeTo(380.0, 1e-7));
    });

    test(
      'PV-001 inverter fault conditions stop downstream output physically',
      () {
        for (final ComponentCondition condition in <ComponentCondition>[
          ComponentCondition.disabled,
          ComponentCondition.openCircuit,
          ComponentCondition.shortCircuit,
        ]) {
          final PvSolveResult result = solve(
            _pvCircuit(loadPowerAt230W: 1200.0, inverterCondition: condition),
          );
          expect(result.status, PvSolveStatus.solved);
          expect(result.inverterState, PvInverterState.faulted);
          expect(result.inverterOutputVoltageRmsV, 0.0);
          expect(result.inverterOutputCurrentRmsA, 0.0);
          expect(result.inverterOutputPowerW, 0.0);
          expect(result.pvDrawnPowerW, 0.0);
          expect(result.load(ComponentId('load')).activePowerW, 0.0);
          expect(
            result.diagnostics.map((PvSolverDiagnostic item) => item.code),
            contains(PvDiagnosticCode.inverterFaulted),
          );
        }
      },
    );

    test('PV-005 inverter DC limits prevent fictitious AC output', () {
      final PvSolveResult result = solve(
        _pvCircuit(loadPowerAt230W: 1200.0, minDcVoltageV: 450.0),
      );
      expect(result.status, PvSolveStatus.solved);
      expect(result.inverterState, PvInverterState.inputOutOfRange);
      expect(result.inverterOutputPowerW, 0.0);
      expect(result.inverterOutputVoltageRmsV, 0.0);
      expect(
        result.diagnostics.map((PvSolverDiagnostic item) => item.code),
        contains(PvDiagnosticCode.inputVoltageOutOfRange),
      );
    });

    test('degraded inverter uses only its explicit deratingFactor', () {
      final PvSolveResult result = solve(
        _pvCircuit(
          loadPowerAt230W: 3000.0,
          inverterCondition: ComponentCondition.degraded,
          deratingFactor: 0.5,
        ),
      );
      expect(result.status, PvSolveStatus.solved);
      expect(result.inverterState, PvInverterState.powerLimited);
      expect(result.inverterOutputPowerW, closeTo(1750.0, 1e-6));
      expect(
        result.diagnostics.map((PvSolverDiagnostic item) => item.code),
        contains(PvDiagnosticCode.inverterDerated),
      );
    });

    test(
      'idle inverter regulates nominal voltage without inventing load power',
      () {
        final PvSolveResult result = solve(_pvCircuit(includeLoad: false));
        expect(result.status, PvSolveStatus.solved);
        expect(result.inverterState, PvInverterState.idle);
        expect(result.inverterOutputVoltageRmsV, closeTo(230.0, 1e-9));
        expect(result.inverterOutputCurrentRmsA, 0.0);
        expect(result.inverterOutputPowerW, 0.0);
        expect(result.pvDrawnPowerW, 0.0);
        expect(result.inverterConversionLossW, 0.0);
      },
    );

    test('disconnected DC input is an explicit invalid topology', () {
      final CircuitState circuit = _pvCircuit(disconnectDcPositive: true);
      final PvSolveResult result = solve(circuit);
      expect(result.status, PvSolveStatus.invalid);
      expect(
        result.diagnostics.map((PvSolverDiagnostic item) => item.code),
        contains(PvDiagnosticCode.dcInputDisconnected),
      );
    });

    test('disconnected AC load is an explicit invalid topology', () {
      final PvSolveResult result = solve(_pvCircuit(disconnectLoadLine: true));
      expect(result.status, PvSolveStatus.invalid);
      expect(
        result.diagnostics.map((PvSolverDiagnostic item) => item.code),
        contains(PvDiagnosticCode.acOutputDisconnected),
      );
    });

    test('wrong mode and topology revision mismatch fail explicitly', () {
      final CircuitState wrongMode = CircuitState(
        circuitId: CircuitId('wrong-mode'),
        revision: 0,
        mode: ElectricalMode.dc,
      );
      expect(solve(wrongMode).status, PvSolveStatus.invalid);

      final CircuitState circuit = _pvCircuit();
      final TopologyGraph topology = topologyEngine.compile(circuit);
      final CircuitState changed = CircuitState(
        circuitId: circuit.circuitId,
        revision: 1,
        mode: circuit.mode,
        components: circuit.components,
        connections: circuit.connections,
        sources: circuit.sources,
        settings: circuit.settings,
      );
      final PvSolveResult mismatch = solver.solve(changed, topology);
      expect(mismatch.status, PvSolveStatus.invalid);
      expect(
        mismatch.diagnostics.map((PvSolverDiagnostic item) => item.code),
        contains(PvDiagnosticCode.topologyIdentityMismatch),
      );
    });

    test('PV cardinality failures are explicit and deterministic', () {
      final CircuitState missingArray = CircuitState(
        circuitId: CircuitId('pv-missing-array'),
        revision: 0,
        mode: ElectricalMode.pv,
        components: <ComponentInstance>[_detachedInverter('inv')],
      );
      final PvSolveResult missingArrayResult = solve(missingArray);
      expect(missingArrayResult.status, PvSolveStatus.invalid);
      expect(
        missingArrayResult.diagnostics.map((PvSolverDiagnostic item) => item.code),
        contains(PvDiagnosticCode.missingPvArray),
      );

      final CircuitState multipleArrays = CircuitState(
        circuitId: CircuitId('pv-multiple-arrays'),
        revision: 0,
        mode: ElectricalMode.pv,
        sources: <SourceInstance>[
          _detachedPvArray('pv-a'),
          _detachedPvArray('pv-b'),
        ],
      );
      final PvSolveResult multipleArraysResult = solve(multipleArrays);
      expect(multipleArraysResult.status, PvSolveStatus.invalid);
      expect(
        multipleArraysResult.diagnostics.map(
          (PvSolverDiagnostic item) => item.code,
        ),
        contains(PvDiagnosticCode.multiplePvArrays),
      );

      final CircuitState missingInverter = CircuitState(
        circuitId: CircuitId('pv-missing-inverter'),
        revision: 0,
        mode: ElectricalMode.pv,
        sources: <SourceInstance>[_detachedPvArray('pv')],
      );
      final PvSolveResult missingInverterResult = solve(missingInverter);
      expect(missingInverterResult.status, PvSolveStatus.invalid);
      expect(
        missingInverterResult.diagnostics.map(
          (PvSolverDiagnostic item) => item.code,
        ),
        contains(PvDiagnosticCode.missingInverter),
      );

      final CircuitState multipleInverters = CircuitState(
        circuitId: CircuitId('pv-multiple-inverters'),
        revision: 0,
        mode: ElectricalMode.pv,
        components: <ComponentInstance>[
          _detachedInverter('inv-a'),
          _detachedInverter('inv-b'),
        ],
        sources: <SourceInstance>[_detachedPvArray('pv')],
      );
      final PvSolveResult multipleInvertersResult = solve(multipleInverters);
      expect(multipleInvertersResult.status, PvSolveStatus.invalid);
      expect(
        multipleInvertersResult.diagnostics.map(
          (PvSolverDiagnostic item) => item.code,
        ),
        contains(PvDiagnosticCode.multipleInverters),
      );
    });

    test(
      'invalid PV/inverter/load parameters do not fall back to magic values',
      () {
        for (final CircuitState circuit in <CircuitState>[
          _pvCircuit(mppVoltageV: 0.0),
          _pvCircuit(efficiency: 1.2),
          _pvCircuit(loadResistanceOverride: -1.0),
          _pvCircuit(
            inverterCondition: ComponentCondition.degraded,
            deratingFactor: 1.2,
          ),
        ]) {
          expect(solve(circuit).status, PvSolveStatus.invalid);
        }
      },
    );

    test('missing environmental settings use documented solver defaults', () {
      final PvSolveResult result = solve(
        _pvCircuit(omitEnvironmentalSettings: true),
      );
      expect(result.status, PvSolveStatus.solved);
      expect(result.isSolved, isTrue);
      expect(result.irradianceWm2, closeTo(1000.0, 1e-9));
      expect(result.cellTemperatureC, closeTo(25.0, 1e-9));
    });

    test('invalid environmental settings fail explicitly', () {
      final PvSolveResult invalidIrradiance = solve(
        _pvCircuit(invalidIrradianceSetting: true),
      );
      expect(invalidIrradiance.status, PvSolveStatus.invalid);
      expect(invalidIrradiance.isSolved, isFalse);
      expect(
        invalidIrradiance.diagnostics.map(
          (PvSolverDiagnostic item) => item.code,
        ),
        contains(PvDiagnosticCode.invalidPvParameter),
      );

      final PvSolveResult invalidTemperature = solve(
        _pvCircuit(invalidTemperatureSetting: true),
      );
      expect(invalidTemperature.status, PvSolveStatus.invalid);
      expect(
        invalidTemperature.diagnostics.map(
          (PvSolverDiagnostic item) => item.code,
        ),
        contains(PvDiagnosticCode.invalidPvParameter),
      );
    });

    test('degraded inverter still enforces its DC input window', () {
      final PvSolveResult result = solve(
        _pvCircuit(
          inverterCondition: ComponentCondition.degraded,
          deratingFactor: 0.8,
          minDcVoltageV: 450.0,
        ),
      );
      expect(result.status, PvSolveStatus.solved);
      expect(result.inverterState, PvInverterState.inputOutOfRange);
      expect(result.inverterOutputPowerW, 0.0);
      expect(
        result.diagnostics.map((PvSolverDiagnostic item) => item.code),
        containsAll(<PvDiagnosticCode>[
          PvDiagnosticCode.inverterDerated,
          PvDiagnosticCode.inputVoltageOutOfRange,
        ]),
      );
    });

    test(
      'zero PV operating voltage cannot invent available current or AC output',
      () {
        final PvSolveResult result = solve(
          _pvCircuit(
            cellTemperatureC: 125.0,
            voltageTemperatureCoefficientPerC: -0.01,
          ),
        );
        expect(result.status, PvSolveStatus.solved);
        expect(result.pvOperatingVoltageV, 0.0);
        expect(result.pvAvailableCurrentA, 0.0);
        expect(result.pvDrawnCurrentA, 0.0);
        expect(result.inverterState, PvInverterState.inputOutOfRange);
        expect(result.inverterOutputPowerW, 0.0);
      },
    );

    test(
      'zero reference irradiance is handled deterministically without division by zero',
      () {
        const SolverPV zeroReferenceSolver = SolverPV(
          options: PvSolverOptions(referenceIrradianceWm2: 0.0),
        );
        final CircuitState circuit = _pvCircuit(loadPowerAt230W: 1000.0);
        final PvSolveResult result = zeroReferenceSolver.solve(
          circuit,
          topologyEngine.compile(circuit),
        );
        expect(result.status, PvSolveStatus.solved);
        expect(result.pvAvailablePowerW, 0.0);
        expect(result.pvAvailableCurrentA, 0.0);
        expect(result.inverterOutputPowerW, 0.0);
        expect(result.inverterOutputVoltageRmsV, 0.0);
        expect(result.inverterState, PvInverterState.powerLimited);
      },
    );

    test(
      'C25 storage charges battery and SOC advances only with explicit simulation time',
      () {
        final CircuitState circuit = _pvStorageCircuit(
          loadPowerAt230W: 1000.0,
          initialSoc: 0.50,
        );
        final TopologyGraph topology = topologyEngine.compile(circuit);
        final PvSolveResult zeroTime = solver.solve(
          circuit,
          topology,
          previousBatterySoc: 0.50,
          elapsed: Duration.zero,
        );
        expect(zeroTime.status, PvSolveStatus.solved);
        expect(zeroTime.controllerPresent, isTrue);
        expect(zeroTime.batteryPresent, isTrue);
        expect(zeroTime.batteryPowerW, lessThan(0.0));
        expect(zeroTime.batterySoc, closeTo(0.50, 1e-12));

        final PvSolveResult afterHour = solver.solve(
          circuit,
          topology,
          previousBatterySoc: zeroTime.batterySoc,
          elapsed: const Duration(hours: 1),
        );
        expect(afterHour.status, PvSolveStatus.solved);
        expect(afterHour.batteryPowerW, lessThan(0.0));
        expect(afterHour.batterySoc, greaterThan(0.50));
        expect(afterHour.batterySoc, lessThanOrEqualTo(0.95));
      },
    );

    test(
      'C25 battery discharges at low irradiance and sustains the AC load',
      () {
        final CircuitState circuit = _pvStorageCircuit(
          irradianceWm2: 100.0,
          loadPowerAt230W: 2000.0,
          initialSoc: 0.60,
        );
        final PvSolveResult result = solver.solve(
          circuit,
          topologyEngine.compile(circuit),
          previousBatterySoc: 0.60,
          elapsed: const Duration(hours: 1),
        );
        expect(result.status, PvSolveStatus.solved);
        expect(result.batteryPowerW, greaterThan(0.0));
        expect(result.batterySoc, lessThan(0.60));
        expect(result.inverterOutputPowerW, closeTo(2000.0, 1e-6));
        expect(result.inverterState, PvInverterState.running);
      },
    );

    test('C25 SOC is bounded by configured minimum and maximum', () {
      final CircuitState charging = _pvStorageCircuit(
        loadPowerAt230W: 100.0,
        initialSoc: 0.94,
        maxSoc: 0.95,
      );
      final PvSolveResult charged = solver.solve(
        charging,
        topologyEngine.compile(charging),
        previousBatterySoc: 0.94,
        elapsed: const Duration(hours: 1),
      );
      expect(charged.status, PvSolveStatus.solved);
      expect(charged.batterySoc, closeTo(0.95, 1e-12));

      final CircuitState discharging = _pvStorageCircuit(
        irradianceWm2: 0.0,
        loadPowerAt230W: 3000.0,
        initialSoc: 0.11,
        minSoc: 0.10,
      );
      final PvSolveResult discharged = solver.solve(
        discharging,
        topologyEngine.compile(discharging),
        previousBatterySoc: 0.11,
        elapsed: const Duration(hours: 1),
      );
      expect(discharged.status, PvSolveStatus.solved);
      expect(discharged.batterySoc, closeTo(0.10, 1e-12));
      expect(discharged.inverterState, PvInverterState.powerLimited);
    });

    test('C25 controller output voltage must match battery voltage', () {
      final CircuitState circuit = _pvStorageCircuit(
        controllerOutputVoltageV: 24.0,
      );
      final PvSolveResult result = solver.solve(
        circuit,
        topologyEngine.compile(circuit),
      );
      expect(result.status, PvSolveStatus.invalid);
      expect(
        result.diagnostics.map((PvSolverDiagnostic item) => item.code),
        contains(PvDiagnosticCode.invalidControllerParameter),
      );
    });

    test('C25 empty battery reports minimum SOC exhaustion explicitly', () {
      final CircuitState circuit = _pvStorageCircuit(
        irradianceWm2: 0.0,
        loadPowerAt230W: 3000.0,
        initialSoc: 0.10,
        minSoc: 0.10,
      );
      final PvSolveResult result = solver.solve(
        circuit,
        topologyEngine.compile(circuit),
        previousBatterySoc: 0.10,
        elapsed: const Duration(hours: 1),
      );
      expect(result.status, PvSolveStatus.solved);
      expect(result.batterySoc, closeTo(0.10, 1e-12));
      expect(
        result.diagnostics.map((PvSolverDiagnostic item) => item.code),
        contains(PvDiagnosticCode.batteryEmpty),
      );
    });

    test('C25 full battery reports charge saturation explicitly', () {
      final CircuitState circuit = _pvStorageCircuit(
        loadPowerAt230W: 100.0,
        initialSoc: 0.95,
        maxSoc: 0.95,
      );
      final PvSolveResult result = solver.solve(
        circuit,
        topologyEngine.compile(circuit),
        previousBatterySoc: 0.95,
        elapsed: const Duration(hours: 1),
      );
      expect(result.status, PvSolveStatus.solved);
      expect(result.batterySoc, closeTo(0.95, 1e-12));
      expect(
        result.diagnostics.map((PvSolverDiagnostic item) => item.code),
        contains(PvDiagnosticCode.batteryFull),
      );
    });

    test(
      'C25 controller and battery cannot be silently used independently',
      () {
        for (final CircuitState circuit in <CircuitState>[
          _pvStorageCircuit(includeBattery: false),
          _pvStorageCircuit(includeController: false),
        ]) {
          final PvSolveResult result = solver.solve(
            circuit,
            topologyEngine.compile(circuit),
          );
          expect(result.status, PvSolveStatus.invalid);
          expect(
            result.diagnostics.map((PvSolverDiagnostic item) => item.code),
            contains(PvDiagnosticCode.storageTopologyInvalid),
          );
        }
      },
    );

    test('SIM-R3 PV-only DC bus powers 48V/48W lamp while charging surplus', () {
      final CircuitState circuit = _pvStorageCircuit(
        includeInverter: false,
        includeDcLamp: true,
        initialSoc: 0.50,
      );
      final PvSolveResult result = solver.solve(
        circuit,
        topologyEngine.compile(circuit),
        previousBatterySoc: 0.50,
        elapsed: const Duration(hours: 1),
      );
      expect(result.status, PvSolveStatus.solved);
      expect(result.load(ComponentId('storage-dc-lamp')).voltageRmsV,
          closeTo(48.0, 1e-6));
      expect(result.load(ComponentId('storage-dc-lamp')).currentRmsA,
          closeTo(1.0, 1e-6));
      expect(result.load(ComponentId('storage-dc-lamp')).activePowerW,
          closeTo(48.0, 1e-6));
      expect(result.batterySoc, greaterThan(0.50));
      expect(result.batteryPowerW, lessThan(0.0));
      expect(result.inverterOutputPowerW, 0.0);
      final double pvBusW =
          result.pvDrawnPowerW - result.controllerConversionLossW;
      expect(pvBusW, closeTo(
          result.load(ComponentId('storage-dc-lamp')).activePowerW -
          result.batteryPowerW, 1e-5));
    });

    test('SIM-R3 no sunshine makes battery feed DC lamp and SOC decreases', () {
      final CircuitState circuit = _pvStorageCircuit(
        includeInverter: false,
        includeDcLamp: true,
        irradianceWm2: 0.0,
        initialSoc: 0.50,
      );
      final PvSolveResult result = solver.solve(
        circuit,
        topologyEngine.compile(circuit),
        previousBatterySoc: 0.50,
        elapsed: const Duration(hours: 1),
      );
      expect(result.status, PvSolveStatus.solved);
      expect(result.load(ComponentId('storage-dc-lamp')).activePowerW,
          closeTo(48.0, 1e-6));
      expect(result.batteryPowerW, closeTo(48.0, 1e-6));
      expect(result.batterySoc, lessThan(0.50));
      expect(result.pvDrawnPowerW, 0.0);
    });

    test('SIM-R3 exhausted storage cuts DC lamp under no sunshine', () {
      final CircuitState circuit = _pvStorageCircuit(
        includeInverter: false,
        includeDcLamp: true,
        irradianceWm2: 0.0,
        initialSoc: 0.10,
      );
      final PvSolveResult result = solver.solve(
        circuit,
        topologyEngine.compile(circuit),
        previousBatterySoc: 0.10,
        elapsed: const Duration(hours: 1),
      );
      expect(result.status, PvSolveStatus.solved);
      expect(result.load(ComponentId('storage-dc-lamp')).activePowerW, 0.0);
      expect(result.batteryPowerW, 0.0);
      expect(result.batterySoc, closeTo(0.10, 1e-9));
      expect(result.diagnostics.map((item) => item.code),
          contains(PvDiagnosticCode.batteryEmpty));
    });

    test(
      'PV-RUNTIME01 storage keeps charging when inverter is removed',
      () {
        final CircuitState circuit = _pvStorageCircuit(
          includeInverter: false,
          initialSoc: 0.50,
        );
        final PvSolveResult result = solver.solve(
          circuit,
          topologyEngine.compile(circuit),
          previousBatterySoc: 0.50,
          elapsed: const Duration(hours: 1),
        );
        expect(result.status, PvSolveStatus.solved);
        expect(result.controllerPresent, isTrue);
        expect(result.batteryPresent, isTrue);
        expect(result.pvDrawnPowerW, greaterThan(0.0));
        expect(result.batteryPowerW, lessThan(0.0));
        expect(result.batterySoc, greaterThan(0.50));
        expect(result.inverterOutputPowerW, 0.0);
      },
    );

    test(
      'PV-RUNTIME01 disconnecting inverter DC does not stop battery charging',
      () {
        final CircuitState circuit = _pvStorageCircuit(
          disconnectInverterDc: true,
          initialSoc: 0.50,
        );
        final PvSolveResult result = solver.solve(
          circuit,
          topologyEngine.compile(circuit),
          previousBatterySoc: 0.50,
          elapsed: const Duration(hours: 1),
        );
        expect(result.status, PvSolveStatus.solved);
        expect(result.pvDrawnPowerW, greaterThan(0.0));
        expect(result.batteryPowerW, lessThan(0.0));
        expect(result.batterySoc, greaterThan(0.50));
        expect(result.inverterOutputPowerW, 0.0);
        expect(
          result.diagnostics.map((PvSolverDiagnostic item) => item.code),
          contains(PvDiagnosticCode.dcInputDisconnected),
        );
      },
    );

    test('PV-RUNTIME01 PWM rejects a 360 V string on a 48 V controller', () {
      final CircuitState circuit = _pvStorageCircuit(
        controllerType: 'pwm',
        controllerMaxPvInputVoltageV: 60.0,
      );
      final PvSolveResult result = solver.solve(
        circuit,
        topologyEngine.compile(circuit),
      );
      expect(result.status, PvSolveStatus.invalid);
      expect(
        result.diagnostics.map((PvSolverDiagnostic item) => item.code),
        contains(PvDiagnosticCode.controllerInputVoltageOutOfRange),
      );
    });

    test('PV-LOAD02 canonical 230 V lamp is powered by inverter output', () {
      final CircuitState base = _pvCircuit(includeLoad: false);
      final ComponentInstance lamp = ComponentInstance(
        id: ComponentId('lamp230'),
        modelType: 'lamp',
        terminals: <Terminal>[
          Terminal(id: TerminalId('lamp-a'), name: 'A'),
          Terminal(id: TerminalId('lamp-b'), name: 'B'),
        ],
        parameters: const <String, Object?>{
          'resistanceOhm': 529.0,
          'receiverNominalVoltageV': 230.0,
          'receiverNominalCurrentA': 0.43478260869565216,
          'receiverNominalPowerW': 100.0,
        },
      );
      final CircuitState circuit = CircuitState(
        circuitId: CircuitId('pv-canonical-lamp'),
        revision: 0,
        mode: ElectricalMode.pv,
        components: <ComponentInstance>[...base.components, lamp],
        connections: <Connection>[
          ...base.connections,
          _wire('lamp-l', 'inv-l', 'lamp-a', PhaseTag.l1),
          _wire('lamp-n', 'inv-n', 'lamp-b', PhaseTag.neutral),
        ],
        sources: base.sources,
        settings: base.settings,
      );

      final PvSolveResult result = solve(circuit);
      expect(result.status, PvSolveStatus.solved);
      expect(result.inverterState, PvInverterState.running);
      final PvLoadResult load = result.load(ComponentId('lamp230'));
      expect(load.voltageRmsV, closeTo(230.0, 1e-9));
      expect(load.currentRmsA, closeTo(100.0 / 230.0, 1e-9));
      expect(load.activePowerW, closeTo(100.0, 1e-7));
    });

    test('same PV input is deterministic', () {
      final CircuitState circuit = _pvCircuit(
        loadPowerAt230W: 2750.0,
        irradianceWm2: 725.0,
        cellTemperatureC: 42.0,
      );
      final PvSolveResult a = solve(circuit);
      final PvSolveResult b = solve(circuit);
      expect(a.status, b.status);
      expect(a.pvAvailablePowerW, b.pvAvailablePowerW);
      expect(a.pvDrawnPowerW, b.pvDrawnPowerW);
      expect(a.inverterOutputVoltageRmsV, b.inverterOutputVoltageRmsV);
      expect(a.inverterOutputPowerW, b.inverterOutputPowerW);
      expect(a.inverterConversionLossW, b.inverterConversionLossW);
    });
  });
}

CircuitState _pvCircuit({
  double loadPowerAt230W = 1000.0,
  bool includeLoad = true,
  bool disconnectDcPositive = false,
  bool disconnectLoadLine = false,
  double irradianceWm2 = 1000.0,
  double cellTemperatureC = 25.0,
  double mppVoltageV = 400.0,
  double mppCurrentA = 10.0,
  double powerTemperatureCoefficientPerC = 0.0,
  double voltageTemperatureCoefficientPerC = 0.0,
  double minDcVoltageV = 300.0,
  double maxDcVoltageV = 500.0,
  double efficiency = 0.95,
  ComponentCondition inverterCondition = ComponentCondition.normal,
  double deratingFactor = 0.5,
  double? loadResistanceOverride,
  bool omitEnvironmentalSettings = false,
  bool invalidIrradianceSetting = false,
  bool invalidTemperatureSetting = false,
  double shadingPct = 0.0,
  bool invalidShadingSetting = false,
}) {
  final double resistance =
      loadResistanceOverride ?? (230.0 * 230.0 / loadPowerAt230W);
  final ComponentInstance inverter = ComponentInstance(
    id: ComponentId('inv'),
    modelType: 'pv_inverter',
    terminals: <Terminal>[
      Terminal(
        id: TerminalId('inv-dc-pos'),
        name: 'DC+',
        role: TerminalRole.positive,
        phase: PhaseTag.dcPositive,
      ),
      Terminal(
        id: TerminalId('inv-dc-'),
        name: 'DC-',
        role: TerminalRole.negative,
        phase: PhaseTag.dcNegative,
      ),
      Terminal(
        id: TerminalId('inv-l'),
        name: 'L',
        role: TerminalRole.line,
        phase: PhaseTag.l1,
      ),
      Terminal(
        id: TerminalId('inv-n'),
        name: 'N',
        role: TerminalRole.neutral,
        phase: PhaseTag.neutral,
      ),
    ],
    parameters: <String, Object?>{
      'minDcVoltageV': minDcVoltageV,
      'maxDcVoltageV': maxDcVoltageV,
      'nominalAcVoltageV': 230.0,
      'ratedAcPowerW': 3500.0,
      'efficiency': efficiency,
      if (inverterCondition == ComponentCondition.degraded)
        'deratingFactor': deratingFactor,
    },
    condition: inverterCondition,
  );

  final List<ComponentInstance> components = <ComponentInstance>[inverter];
  if (includeLoad) {
    components.add(
      ComponentInstance(
        id: ComponentId('load'),
        modelType: 'pv_resistive_load',
        terminals: <Terminal>[
          Terminal(
            id: TerminalId('load-l'),
            name: 'L',
            role: TerminalRole.line,
            phase: PhaseTag.l1,
          ),
          Terminal(
            id: TerminalId('load-n'),
            name: 'N',
            role: TerminalRole.neutral,
            phase: PhaseTag.neutral,
          ),
        ],
        parameters: <String, Object?>{'resistanceOhm': resistance},
      ),
    );
  }

  final List<Connection> connections = <Connection>[
    if (!disconnectDcPositive)
      _wire('dc-pos', 'pv-pos', 'inv-dc-pos', PhaseTag.dcPositive),
    _wire('dc-', 'pv-', 'inv-dc-', PhaseTag.dcNegative),
    if (includeLoad && !disconnectLoadLine)
      _wire('ac-l', 'inv-l', 'load-l', PhaseTag.l1),
    if (includeLoad) _wire('ac-n', 'inv-n', 'load-n', PhaseTag.neutral),
  ];

  return CircuitState(
    circuitId: CircuitId('pv-test'),
    revision: 0,
    mode: ElectricalMode.pv,
    components: components,
    connections: connections,
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('pv'),
        modelType: 'pv_array',
        terminals: <Terminal>[
          Terminal(
            id: TerminalId('pv-pos'),
            name: '+',
            role: TerminalRole.positive,
            phase: PhaseTag.dcPositive,
          ),
          Terminal(
            id: TerminalId('pv-'),
            name: '-',
            role: TerminalRole.negative,
            phase: PhaseTag.dcNegative,
          ),
        ],
        parameters: <String, Object?>{
          'mppVoltageV': mppVoltageV,
          'mppCurrentA': mppCurrentA,
          'powerTemperatureCoefficientPerC': powerTemperatureCoefficientPerC,
          'voltageTemperatureCoefficientPerC':
              voltageTemperatureCoefficientPerC,
        },
      ),
    ],
    settings: omitEnvironmentalSettings
        ? const <String, Object?>{}
        : <String, Object?>{
            'irradianceWm2': invalidIrradianceSetting ? -1.0 : irradianceWm2,
            'shadingPct': invalidShadingSetting ? 101.0 : shadingPct,
            'cellTemperatureC': invalidTemperatureSetting
                ? 'invalid-temperature'
                : cellTemperatureC,
          },
  );
}

CircuitState _pvStorageCircuit({
  double irradianceWm2 = 1000.0,
  double loadPowerAt230W = 1000.0,
  double initialSoc = 0.60,
  double minSoc = 0.10,
  double maxSoc = 0.95,
  bool includeController = true,
  bool includeBattery = true,
  bool includeInverter = true,
  bool includeDcLamp = false,
  bool disconnectInverterDc = false,
  String controllerType = 'mppt',
  double controllerMaxPvInputVoltageV = 450.0,
  double controllerOutputVoltageV = 48.0,
}) {
  final double resistance = 230.0 * 230.0 / loadPowerAt230W;
  final ComponentInstance inverter = ComponentInstance(
    id: ComponentId('storage-inv'),
    modelType: 'pv_inverter',
    terminals: <Terminal>[
      Terminal(
        id: TerminalId('storage-inv-dc-pos'),
        name: 'DC+',
        role: TerminalRole.positive,
        phase: PhaseTag.dcPositive,
      ),
      Terminal(
        id: TerminalId('storage-inv-dc-neg'),
        name: 'DC-',
        role: TerminalRole.negative,
        phase: PhaseTag.dcNegative,
      ),
      Terminal(
        id: TerminalId('storage-inv-l'),
        name: 'L',
        role: TerminalRole.line,
        phase: PhaseTag.l1,
      ),
      Terminal(
        id: TerminalId('storage-inv-n'),
        name: 'N',
        role: TerminalRole.neutral,
        phase: PhaseTag.neutral,
      ),
    ],
    parameters: const <String, Object?>{
      'minDcVoltageV': 40.0,
      'maxDcVoltageV': 60.0,
      'nominalAcVoltageV': 230.0,
      'ratedAcPowerW': 3500.0,
      'efficiency': 0.95,
    },
  );
  final ComponentInstance controller = ComponentInstance(
    id: ComponentId('storage-controller'),
    modelType: 'pv_controller',
    terminals: <Terminal>[
      Terminal(
        id: TerminalId('storage-controller-pv-pos'),
        name: 'PV+',
        role: TerminalRole.positive,
        phase: PhaseTag.dcPositive,
      ),
      Terminal(
        id: TerminalId('storage-controller-pv-neg'),
        name: 'PV-',
        role: TerminalRole.negative,
        phase: PhaseTag.dcNegative,
      ),
      Terminal(
        id: TerminalId('storage-controller-bus-pos'),
        name: 'BAT+',
        role: TerminalRole.positive,
        phase: PhaseTag.dcPositive,
      ),
      Terminal(
        id: TerminalId('storage-controller-bus-neg'),
        name: 'BAT-',
        role: TerminalRole.negative,
        phase: PhaseTag.dcNegative,
      ),
    ],
    parameters: <String, Object?>{
      'outputVoltageV': controllerOutputVoltageV,
      'maxOutputCurrentA': 60.0,
      'efficiency': 0.97,
      'controllerType': controllerType,
      'maxPvInputVoltageV': controllerMaxPvInputVoltageV,
    },
  );
  final ComponentInstance battery = ComponentInstance(
    id: ComponentId('storage-battery'),
    modelType: 'pv_battery',
    terminals: <Terminal>[
      Terminal(
        id: TerminalId('storage-battery-pos'),
        name: '+',
        role: TerminalRole.positive,
        phase: PhaseTag.dcPositive,
      ),
      Terminal(
        id: TerminalId('storage-battery-neg'),
        name: '-',
        role: TerminalRole.negative,
        phase: PhaseTag.dcNegative,
      ),
    ],
    parameters: <String, Object?>{
      'nominalVoltageV': 48.0,
      'capacityAh': 100.0,
      'initialSoc': initialSoc,
      'minSoc': minSoc,
      'maxSoc': maxSoc,
      'maxChargeCurrentA': 30.0,
      'maxDischargeCurrentA': 60.0,
      'chargeEfficiency': 0.95,
      'dischargeEfficiency': 0.95,
    },
  );
  final ComponentInstance load = ComponentInstance(
    id: ComponentId('storage-load'),
    modelType: 'pv_resistive_load',
    terminals: <Terminal>[
      Terminal(
        id: TerminalId('storage-load-l'),
        name: 'L',
        role: TerminalRole.line,
        phase: PhaseTag.l1,
      ),
      Terminal(
        id: TerminalId('storage-load-n'),
        name: 'N',
        role: TerminalRole.neutral,
        phase: PhaseTag.neutral,
      ),
    ],
    parameters: <String, Object?>{'resistanceOhm': resistance},
  );

  final ComponentInstance dcLamp = ComponentInstance(
    id: ComponentId('storage-dc-lamp'),
    modelType: 'lamp',
    terminals: <Terminal>[
      Terminal(
        id: TerminalId('storage-dc-lamp-plus'),
        name: '+',
        role: TerminalRole.positive,
        phase: PhaseTag.dcPositive,
      ),
      Terminal(
        id: TerminalId('storage-dc-lamp-minus'),
        name: '-',
        role: TerminalRole.negative,
        phase: PhaseTag.dcNegative,
      ),
    ],
    parameters: const <String, Object?>{'resistanceOhm': 48.0},
  );
  final List<ComponentInstance> components = <ComponentInstance>[
    if (includeDcLamp) dcLamp,
    if (includeController) controller,
    if (includeBattery) battery,
    if (includeInverter) inverter,
    if (includeInverter) load,
  ];
  final List<Connection> connections = <Connection>[
    if (includeController) ...<Connection>[
      _wire(
        'storage-pv-pos',
        'storage-pv-source-pos',
        'storage-controller-pv-pos',
        PhaseTag.dcPositive,
      ),
      _wire(
        'storage-pv-neg',
        'storage-pv-source-neg',
        'storage-controller-pv-neg',
        PhaseTag.dcNegative,
      ),
      if (includeInverter && !disconnectInverterDc)
        _wire(
          'storage-bus-pos',
          'storage-controller-bus-pos',
          'storage-inv-dc-pos',
          PhaseTag.dcPositive,
        )
      else if (includeBattery)
        _wire(
          'storage-bus-pos-battery',
          'storage-controller-bus-pos',
          'storage-battery-pos',
          PhaseTag.dcPositive,
        ),
      if (includeInverter && !disconnectInverterDc)
        _wire(
          'storage-bus-neg',
          'storage-controller-bus-neg',
          'storage-inv-dc-neg',
          PhaseTag.dcNegative,
        )
      else if (includeBattery)
        _wire(
          'storage-bus-neg-battery',
          'storage-controller-bus-neg',
          'storage-battery-neg',
          PhaseTag.dcNegative,
        ),
    ] else ...<Connection>[
      _wire(
        'storage-direct-pos',
        'storage-pv-source-pos',
        'storage-inv-dc-pos',
        PhaseTag.dcPositive,
      ),
      _wire(
        'storage-direct-neg',
        'storage-pv-source-neg',
        'storage-inv-dc-neg',
        PhaseTag.dcNegative,
      ),
    ],
    if (includeBattery && includeInverter && !disconnectInverterDc) ...<Connection>[
      _wire(
        'storage-battery-pos-wire',
        'storage-battery-pos',
        'storage-inv-dc-pos',
        PhaseTag.dcPositive,
      ),
      _wire(
        'storage-battery-neg-wire',
        'storage-battery-neg',
        'storage-inv-dc-neg',
        PhaseTag.dcNegative,
      ),
    ],
    if (includeDcLamp) ...<Connection>[
      _wire('storage-dc-load-pos', 'storage-dc-lamp-plus',
        'storage-controller-bus-pos', PhaseTag.dcPositive),
      _wire('storage-dc-load-neg', 'storage-dc-lamp-minus',
        'storage-controller-bus-neg', PhaseTag.dcNegative),
    ],
    if (includeInverter)
      _wire('storage-ac-l', 'storage-inv-l', 'storage-load-l', PhaseTag.l1),
    if (includeInverter)
      _wire('storage-ac-n', 'storage-inv-n', 'storage-load-n', PhaseTag.neutral),
  ];

  return CircuitState(
    circuitId: CircuitId('pv-storage-test'),
    revision: 0,
    mode: ElectricalMode.pv,
    components: components,
    connections: connections,
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('storage-pv-source'),
        modelType: 'pv_array',
        terminals: <Terminal>[
          Terminal(
            id: TerminalId('storage-pv-source-pos'),
            name: '+',
            role: TerminalRole.positive,
            phase: PhaseTag.dcPositive,
          ),
          Terminal(
            id: TerminalId('storage-pv-source-neg'),
            name: '-',
            role: TerminalRole.negative,
            phase: PhaseTag.dcNegative,
          ),
        ],
        parameters: const <String, Object?>{
          'mppVoltageV': 360.0,
          'mppCurrentA': 10.0,
          'powerTemperatureCoefficientPerC': 0.0,
          'voltageTemperatureCoefficientPerC': 0.0,
        },
      ),
    ],
    settings: <String, Object?>{
      'irradianceWm2': irradianceWm2,
      'shadingPct': 0.0,
      'cellTemperatureC': 25.0,
    },
  );
}

SourceInstance _detachedPvArray(String id) => SourceInstance(
  id: SourceId(id),
  modelType: 'pv_array',
  terminals: <Terminal>[
    Terminal(
      id: TerminalId(id + '-pos'),
      name: '+',
      role: TerminalRole.positive,
      phase: PhaseTag.dcPositive,
    ),
    Terminal(
      id: TerminalId(id + '-neg'),
      name: '-',
      role: TerminalRole.negative,
      phase: PhaseTag.dcNegative,
    ),
  ],
  parameters: const <String, Object?>{
    'mppVoltageV': 400.0,
    'mppCurrentA': 10.0,
    'powerTemperatureCoefficientPerC': 0.0,
    'voltageTemperatureCoefficientPerC': 0.0,
  },
);

ComponentInstance _detachedInverter(String id) => ComponentInstance(
  id: ComponentId(id),
  modelType: 'pv_inverter',
  terminals: <Terminal>[
    Terminal(
      id: TerminalId(id + '-dc-pos'),
      name: 'DC+',
      role: TerminalRole.positive,
      phase: PhaseTag.dcPositive,
    ),
    Terminal(
      id: TerminalId(id + '-dc-neg'),
      name: 'DC-',
      role: TerminalRole.negative,
      phase: PhaseTag.dcNegative,
    ),
    Terminal(
      id: TerminalId(id + '-l'),
      name: 'L',
      role: TerminalRole.line,
      phase: PhaseTag.l1,
    ),
    Terminal(
      id: TerminalId(id + '-n'),
      name: 'N',
      role: TerminalRole.neutral,
      phase: PhaseTag.neutral,
    ),
  ],
  parameters: const <String, Object?>{
    'minDcVoltageV': 300.0,
    'maxDcVoltageV': 500.0,
    'nominalAcVoltageV': 230.0,
    'ratedAcPowerW': 3500.0,
    'efficiency': 0.95,
  },
);

Connection _wire(String id, String from, String to, PhaseTag phase) =>
    Connection(
      id: ConnectionId(id),
      fromTerminalId: TerminalId(from),
      toTerminalId: TerminalId(to),
      phase: phase,
    );
