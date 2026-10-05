import 'energy_models.dart';

final class EnergyEngine {
  const EnergyEngine();

  static const String engineVersion = 'energy/0.1.0';

  EnergySnapshot advance({
    required EnergySnapshot previous,
    required EnergyPowerSample sample,
    required Duration elapsed,
  }) {
    if (elapsed.isNegative) {
      throw const EnergyException(
        EnergyErrorCode.invalidDuration,
        'Elapsed duration cannot be negative.',
      );
    }
    if (previous.circuitId != sample.circuitId) {
      throw const EnergyException(
        EnergyErrorCode.circuitMismatch,
        'Energy samples cannot be accumulated across different circuits.',
      );
    }
    final double hours = elapsed.inMicroseconds / 3600000000.0;
    return EnergySnapshot(
      circuitId: sample.circuitId,
      circuitRevision: sample.circuitRevision,
      sourceEngineVersion: sample.engineVersion,
      elapsedSeconds:
          previous.elapsedSeconds + elapsed.inMicroseconds / 1000000.0,
      inputPowerW: sample.inputPowerW,
      outputPowerW: sample.outputPowerW,
      lossPowerW: sample.lossPowerW,
      inputEnergyWh: previous.inputEnergyWh + sample.inputPowerW * hours,
      outputEnergyWh: previous.outputEnergyWh + sample.outputPowerW * hours,
      lossEnergyWh: previous.lossEnergyWh + sample.lossPowerW * hours,
    );
  }
}
