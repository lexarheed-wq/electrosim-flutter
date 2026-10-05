import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_pv/electrosim_pv.dart';

enum EnergyErrorCode {
  unsolvedSource,
  invalidPower,
  unbalancedPower,
  invalidDuration,
  circuitMismatch,
  invalidHistoryCapacity,
}

final class EnergyException implements Exception {
  const EnergyException(this.code, this.message);

  final EnergyErrorCode code;
  final String message;

  @override
  String toString() => 'EnergyException(${code.name}): $message';
}

final class EnergyPowerSample {
  EnergyPowerSample({
    required this.circuitId,
    required this.circuitRevision,
    required this.engineVersion,
    required this.inputPowerW,
    required this.outputPowerW,
    required this.lossPowerW,
    double balanceToleranceW = 1e-6,
  }) {
    for (final double value in <double>[inputPowerW, outputPowerW, lossPowerW]) {
      if (!value.isFinite || value < 0.0) {
        throw const EnergyException(
          EnergyErrorCode.invalidPower,
          'Power values must be finite and non-negative.',
        );
      }
    }
    final double residual = (inputPowerW - outputPowerW - lossPowerW).abs();
    if (residual > balanceToleranceW) {
      throw EnergyException(
        EnergyErrorCode.unbalancedPower,
        'Power balance residual $residual W exceeds tolerance $balanceToleranceW W.',
      );
    }
  }

  factory EnergyPowerSample.fromPvResult(PvSolveResult result) {
    if (!result.isSolved) {
      throw const EnergyException(
        EnergyErrorCode.unsolvedSource,
        'EnergyPowerSample requires a solved PV result.',
      );
    }
    final double batteryRawDischargeW =
        result.batteryPresent && result.batteryPowerW > 0.0
            ? result.batteryPowerW + result.batteryConversionLossW
            : 0.0;
    final double batteryStoredChargeW =
        result.batteryPresent && result.batteryPowerW < 0.0
            ? (-result.batteryPowerW - result.batteryConversionLossW)
                .clamp(0.0, double.infinity)
                .toDouble()
            : 0.0;
    return EnergyPowerSample(
      circuitId: result.circuitId,
      circuitRevision: result.circuitRevision,
      engineVersion: result.engineVersion,
      inputPowerW: result.pvDrawnPowerW + batteryRawDischargeW,
      outputPowerW: result.inverterOutputPowerW + batteryStoredChargeW,
      lossPowerW: result.controllerConversionLossW +
          result.inverterConversionLossW +
          result.batteryConversionLossW,
    );
  }

  final CircuitId circuitId;
  final int circuitRevision;
  final String engineVersion;
  final double inputPowerW;
  final double outputPowerW;
  final double lossPowerW;

  double get efficiency => inputPowerW <= 1e-15 ? 1.0 : outputPowerW / inputPowerW;
}

final class EnergySnapshot {
  const EnergySnapshot({
    required this.circuitId,
    required this.circuitRevision,
    required this.sourceEngineVersion,
    required this.elapsedSeconds,
    required this.inputPowerW,
    required this.outputPowerW,
    required this.lossPowerW,
    required this.inputEnergyWh,
    required this.outputEnergyWh,
    required this.lossEnergyWh,
  });

  factory EnergySnapshot.zero({
    required CircuitId circuitId,
    required int circuitRevision,
    required String sourceEngineVersion,
  }) =>
      EnergySnapshot(
        circuitId: circuitId,
        circuitRevision: circuitRevision,
        sourceEngineVersion: sourceEngineVersion,
        elapsedSeconds: 0.0,
        inputPowerW: 0.0,
        outputPowerW: 0.0,
        lossPowerW: 0.0,
        inputEnergyWh: 0.0,
        outputEnergyWh: 0.0,
        lossEnergyWh: 0.0,
      );

  final CircuitId circuitId;
  final int circuitRevision;
  final String sourceEngineVersion;
  final double elapsedSeconds;
  final double inputPowerW;
  final double outputPowerW;
  final double lossPowerW;
  final double inputEnergyWh;
  final double outputEnergyWh;
  final double lossEnergyWh;

  double get inputEnergyKWh => inputEnergyWh / 1000.0;
  double get outputEnergyKWh => outputEnergyWh / 1000.0;
  double get lossEnergyKWh => lossEnergyWh / 1000.0;
  double get instantaneousEfficiency =>
      inputPowerW <= 1e-15 ? 1.0 : outputPowerW / inputPowerW;
  double get cumulativeEfficiency =>
      inputEnergyWh <= 1e-15 ? 1.0 : outputEnergyWh / inputEnergyWh;
}

final class EnergyHistory {
  EnergyHistory({required this.maxEntries, Iterable<EnergySnapshot> entries = const <EnergySnapshot>[]})
    : entries = List<EnergySnapshot>.unmodifiable(entries) {
    if (maxEntries <= 0) {
      throw const EnergyException(
        EnergyErrorCode.invalidHistoryCapacity,
        'EnergyHistory maxEntries must be greater than zero.',
      );
    }
    if (this.entries.length > maxEntries) {
      throw const EnergyException(
        EnergyErrorCode.invalidHistoryCapacity,
        'Initial history contains more entries than maxEntries.',
      );
    }
  }

  final int maxEntries;
  final List<EnergySnapshot> entries;

  EnergyHistory add(EnergySnapshot snapshot) {
    final List<EnergySnapshot> next = <EnergySnapshot>[...entries, snapshot];
    if (next.length > maxEntries) {
      next.removeRange(0, next.length - maxEntries);
    }
    return EnergyHistory(maxEntries: maxEntries, entries: next);
  }
}
