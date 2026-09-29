import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_energy/electrosim_energy.dart';
import 'package:electrosim_pv/electrosim_pv.dart';
import 'package:test/test.dart';

void main() {
  const EnergyEngine engine = EnergyEngine();

  group('EnergyEngine', () {
    test('ENERGY-001 integrates W into Wh and kWh with explicit elapsed time', () {
      final CircuitId id = CircuitId('energy-1');
      final EnergySnapshot zero = EnergySnapshot.zero(
        circuitId: id,
        circuitRevision: 0,
        sourceEngineVersion: 'test/1',
      );
      final EnergyPowerSample sample = EnergyPowerSample(
        circuitId: id,
        circuitRevision: 0,
        engineVersion: 'test/1',
        inputPowerW: 1000.0,
        outputPowerW: 900.0,
        lossPowerW: 100.0,
      );
      final EnergySnapshot result = engine.advance(
        previous: zero,
        sample: sample,
        elapsed: const Duration(hours: 1),
      );
      expect(result.inputEnergyWh, closeTo(1000.0, 1e-9));
      expect(result.outputEnergyWh, closeTo(900.0, 1e-9));
      expect(result.lossEnergyWh, closeTo(100.0, 1e-9));
      expect(result.inputEnergyKWh, closeTo(1.0, 1e-12));
      expect(result.outputEnergyKWh, closeTo(0.9, 1e-12));
      expect(result.lossEnergyKWh, closeTo(0.1, 1e-12));
      expect(result.instantaneousEfficiency, closeTo(0.9, 1e-12));
      expect(result.cumulativeEfficiency, closeTo(0.9, 1e-12));
    });

    test('ENERGY-002 multiple intervals accumulate deterministically', () {
      final CircuitId id = CircuitId('energy-2');
      EnergySnapshot state = EnergySnapshot.zero(
        circuitId: id,
        circuitRevision: 0,
        sourceEngineVersion: 'test/1',
      );
      final EnergyPowerSample sample = EnergyPowerSample(
        circuitId: id,
        circuitRevision: 0,
        engineVersion: 'test/1',
        inputPowerW: 500.0,
        outputPowerW: 450.0,
        lossPowerW: 50.0,
      );
      state = engine.advance(
        previous: state,
        sample: sample,
        elapsed: const Duration(minutes: 30),
      );
      state = engine.advance(
        previous: state,
        sample: sample,
        elapsed: const Duration(minutes: 30),
      );
      expect(state.elapsedSeconds, 3600.0);
      expect(state.inputEnergyWh, closeTo(500.0, 1e-9));
      expect(state.outputEnergyWh, closeTo(450.0, 1e-9));
      expect(state.lossEnergyWh, closeTo(50.0, 1e-9));
    });

    test('EnergyPowerSample consumes solved PV physical results', () {
      final PvSolveResult pv = PvSolveResult(
        circuitId: CircuitId('pv-energy'),
        circuitRevision: 3,
        engineVersion: 'solver-pv/test',
        status: PvSolveStatus.solved,
        irradianceWm2: 1000.0,
        cellTemperatureC: 25.0,
        pvOperatingVoltageV: 400.0,
        pvAvailableCurrentA: 10.0,
        pvAvailablePowerW: 4000.0,
        pvDrawnCurrentA: 5.0,
        pvDrawnPowerW: 2000.0,
        curtailedPowerW: 2000.0,
        inverterState: PvInverterState.running,
        inverterEfficiency: 0.95,
        inverterOutputVoltageRmsV: 230.0,
        inverterOutputCurrentRmsA: 8.260869565,
        inverterOutputPowerW: 1900.0,
        inverterConversionLossW: 100.0,
        loadResults: const <PvLoadResult>[],
        diagnostics: const <PvSolverDiagnostic>[],
      );
      final EnergyPowerSample sample = EnergyPowerSample.fromPvResult(pv);
      expect(sample.inputPowerW, 2000.0);
      expect(sample.outputPowerW, 1900.0);
      expect(sample.lossPowerW, 100.0);
      expect(sample.efficiency, closeTo(0.95, 1e-12));
      expect(sample.circuitRevision, 3);
    });

    test('faulted inverter contributes zero output energy when physical draw is zero', () {
      final CircuitId id = CircuitId('fault-energy');
      final PvSolveResult pv = PvSolveResult(
        circuitId: id,
        circuitRevision: 0,
        engineVersion: 'solver-pv/test',
        status: PvSolveStatus.solved,
        irradianceWm2: 1000.0,
        cellTemperatureC: 25.0,
        pvOperatingVoltageV: 400.0,
        pvAvailableCurrentA: 10.0,
        pvAvailablePowerW: 4000.0,
        pvDrawnCurrentA: 0.0,
        pvDrawnPowerW: 0.0,
        curtailedPowerW: 4000.0,
        inverterState: PvInverterState.faulted,
        inverterEfficiency: 0.95,
        inverterOutputVoltageRmsV: 0.0,
        inverterOutputCurrentRmsA: 0.0,
        inverterOutputPowerW: 0.0,
        inverterConversionLossW: 0.0,
        loadResults: const <PvLoadResult>[],
        diagnostics: const <PvSolverDiagnostic>[],
      );
      final EnergyPowerSample sample = EnergyPowerSample.fromPvResult(pv);
      final EnergySnapshot result = engine.advance(
        previous: EnergySnapshot.zero(
          circuitId: id,
          circuitRevision: 0,
          sourceEngineVersion: pv.engineVersion,
        ),
        sample: sample,
        elapsed: const Duration(hours: 2),
      );
      expect(result.outputEnergyWh, 0.0);
      expect(result.inputEnergyWh, 0.0);
      expect(result.lossEnergyWh, 0.0);
    });

    test('invalid power balance is rejected instead of normalized silently', () {
      expect(
        () => EnergyPowerSample(
          circuitId: CircuitId('bad'),
          circuitRevision: 0,
          engineVersion: 'test',
          inputPowerW: 100.0,
          outputPowerW: 80.0,
          lossPowerW: 10.0,
        ),
        throwsA(
          isA<EnergyException>().having(
            (EnergyException error) => error.code,
            'code',
            EnergyErrorCode.unbalancedPower,
          ),
        ),
      );
    });

    test('negative, NaN and infinite powers are rejected', () {
      for (final double invalid in <double>[-1.0, double.nan, double.infinity]) {
        expect(
          () => EnergyPowerSample(
            circuitId: CircuitId('bad-power'),
            circuitRevision: 0,
            engineVersion: 'test',
            inputPowerW: invalid,
            outputPowerW: 0.0,
            lossPowerW: 0.0,
          ),
          throwsA(isA<EnergyException>()),
        );
      }
    });

    test('different circuits cannot be accumulated together', () {
      final EnergySnapshot previous = EnergySnapshot.zero(
        circuitId: CircuitId('a'),
        circuitRevision: 0,
        sourceEngineVersion: 'test',
      );
      final EnergyPowerSample sample = EnergyPowerSample(
        circuitId: CircuitId('b'),
        circuitRevision: 0,
        engineVersion: 'test',
        inputPowerW: 0.0,
        outputPowerW: 0.0,
        lossPowerW: 0.0,
      );
      expect(
        () => engine.advance(
          previous: previous,
          sample: sample,
          elapsed: Duration.zero,
        ),
        throwsA(
          isA<EnergyException>().having(
            (EnergyException error) => error.code,
            'code',
            EnergyErrorCode.circuitMismatch,
          ),
        ),
      );
    });

    test('negative elapsed time is rejected', () {
      final CircuitId id = CircuitId('negative-time');
      final EnergySnapshot previous = EnergySnapshot.zero(
        circuitId: id,
        circuitRevision: 0,
        sourceEngineVersion: 'test',
      );
      final EnergyPowerSample sample = EnergyPowerSample(
        circuitId: id,
        circuitRevision: 0,
        engineVersion: 'test',
        inputPowerW: 0.0,
        outputPowerW: 0.0,
        lossPowerW: 0.0,
      );
      expect(
        () => engine.advance(
          previous: previous,
          sample: sample,
          elapsed: const Duration(seconds: -1),
        ),
        throwsA(isA<EnergyException>()),
      );
    });

    test('bounded EnergyHistory drops oldest entries only after capacity', () {
      final CircuitId id = CircuitId('history');
      final EnergyHistory history = EnergyHistory(maxEntries: 2);
      final EnergySnapshot a = EnergySnapshot.zero(
        circuitId: id,
        circuitRevision: 0,
        sourceEngineVersion: 'a',
      );
      final EnergySnapshot b = EnergySnapshot.zero(
        circuitId: id,
        circuitRevision: 1,
        sourceEngineVersion: 'b',
      );
      final EnergySnapshot c = EnergySnapshot.zero(
        circuitId: id,
        circuitRevision: 2,
        sourceEngineVersion: 'c',
      );
      final EnergyHistory result = history.add(a).add(b).add(c);
      expect(result.entries.length, 2);
      expect(result.entries.first.circuitRevision, 1);
      expect(result.entries.last.circuitRevision, 2);
      expect(() => result.entries.add(a), throwsUnsupportedError);
    });

    test('unsolved PV result cannot be converted into energy sample', () {
      final PvSolveResult pv = PvSolveResult(
        circuitId: CircuitId('invalid-pv'),
        circuitRevision: 0,
        engineVersion: 'solver-pv/test',
        status: PvSolveStatus.invalid,
        irradianceWm2: 0.0,
        cellTemperatureC: 0.0,
        pvOperatingVoltageV: 0.0,
        pvAvailableCurrentA: 0.0,
        pvAvailablePowerW: 0.0,
        pvDrawnCurrentA: 0.0,
        pvDrawnPowerW: 0.0,
        curtailedPowerW: 0.0,
        inverterState: PvInverterState.faulted,
        inverterEfficiency: 0.0,
        inverterOutputVoltageRmsV: 0.0,
        inverterOutputCurrentRmsA: 0.0,
        inverterOutputPowerW: 0.0,
        inverterConversionLossW: 0.0,
        loadResults: const <PvLoadResult>[],
        diagnostics: const <PvSolverDiagnostic>[],
      );
      expect(
        () => EnergyPowerSample.fromPvResult(pv),
        throwsA(
          isA<EnergyException>().having(
            (EnergyException error) => error.code,
            'code',
            EnergyErrorCode.unsolvedSource,
          ),
        ),
      );
    });
  });
}
