import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';

import 'self_hold_valve52_cycle.dart';
import 'solenoid_actuator.dart';

/// R4 read-only instrument sample, measured from a fully accepted physical
/// state. No widget may derive an alternate pressure, flow, force or position.
/// Gauge pressure is explicitly relative to 101325 Pa.
final class PneumaticCylinderTelemetry {
  const PneumaticCylinderTelemetry({
    required this.timeS,
    required this.pressureAAbsPa,
    required this.pressureBAbsPa,
    required this.positionM,
    required this.velocityMPerS,
    required this.forceN,
    required this.totalGasMassKg,
    required this.externalMassAddedKg,
    required this.massResidualKg,
    required this.commutedSpool,
    required this.endStopActuated,
  });

  final double timeS;
  final double pressureAAbsPa;
  final double pressureBAbsPa;
  final double positionM;
  final double velocityMPerS;
  final double forceN;
  final double totalGasMassKg;
  final double externalMassAddedKg;
  final double massResidualKg;
  final ValveSpoolSide commutedSpool;
  final bool endStopActuated;

  double get pressureAGaugePa =>
      pressureAAbsPa - DryAirReference.atmosphericPressurePa;
  double get pressureBGaugePa =>
      pressureBAbsPa - DryAirReference.atmosphericPressurePa;
  double get pressureAGaugeBar => pressureAGaugePa / 100000;
  double get pressureBGaugeBar => pressureBGaugePa / 100000;
  double get positionMm => positionM * 1000;
}

/// Bounded memory chart history; samples are immutable and time-ordered.
/// Rendering interpolation must never feed back into the physical clock.
final class PneumaticTelemetrySeries {
  PneumaticTelemetrySeries({this.capacity = 2000}) {
    if (capacity < 2) {
      throw ArgumentError.value(capacity, 'capacity', 'At least 2 samples.');
    }
  }

  final int capacity;
  final List<PneumaticCylinderTelemetry> _samples =
      <PneumaticCylinderTelemetry>[];

  List<PneumaticCylinderTelemetry> get samples =>
      List<PneumaticCylinderTelemetry>.unmodifiable(_samples);

  void record(PneumaticCylinderTelemetry sample) {
    if (!sample.timeS.isFinite ||
        (_samples.isNotEmpty && sample.timeS < _samples.last.timeS)) {
      throw const ElectropneumaticRuntimeException(
        'nonmonotonic_telemetry',
        'Only chronological accepted physical states can enter charts.',
      );
    }
    if (_samples.isNotEmpty && sample.timeS == _samples.last.timeS) {
      _samples[_samples.length - 1] = sample;
      return;
    }
    _samples.add(sample);
    if (_samples.length > capacity) _samples.removeAt(0);
  }

  void reset() => _samples.clear();
}

/// Reader for 5/2 cylinder physical plant and accepted coupling snapshot.
abstract final class PneumaticTelemetryReader {
  static PneumaticCylinderTelemetry cylinder({
    required MovingDoubleActingAirCylinder model,
    required SelfHoldValve52Snapshot accepted,
  }) {
    final MovingCylinderSnapshot s = accepted.air;
    if ((s.timeS - accepted.timeS).abs() > 1e-9) {
      throw const ElectropneumaticRuntimeException(
        'telemetry_clock_mismatch',
        'Instrument must use the accepted common-clock snapshot.',
      );
    }
    return PneumaticCylinderTelemetry(
      timeS: s.timeS,
      pressureAAbsPa: model.pressureAAbsPa(s),
      pressureBAbsPa: model.pressureBAbsPa(s),
      positionM: s.positionM,
      velocityMPerS: s.velocityMPerS,
      forceN: model.mechanicalResultantN(s),
      totalGasMassKg: s.gasMassKg,
      externalMassAddedKg: s.externalMassAddedKg,
      massResidualKg: model.massResidualKg(s),
      commutedSpool: accepted.spool,
      endStopActuated: accepted.endStopActuated,
    );
  }
}
