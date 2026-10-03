import 'package:electrosim_domain/electrosim_domain.dart';

enum ReceiverLoadCode {
  unavailable,
  off,
  underload,
  normal,
  overload,
  severeOverload,
}

final class ReceiverLoadState {
  const ReceiverLoadState({
    required this.componentId,
    required this.code,
    required this.currentA,
    required this.ratedCurrentA,
    required this.loadRatio,
  });

  final ComponentId componentId;
  final ReceiverLoadCode code;
  final double currentA;
  final double ratedCurrentA;
  final double loadRatio;

  double get loadPercent => loadRatio * 100.0;
  bool get isOverloaded =>
      code == ReceiverLoadCode.overload ||
      code == ReceiverLoadCode.severeOverload;
}

/// Pure receiver load classifier.
///
/// Thresholds intentionally match the last validated V1 behavior, but the
/// contract and implementation are new Dart code:
/// OFF <= tolerance, UNDERLOAD < 75 %, NORMAL <= 105 %,
/// OVERLOAD <= 150 %, SEVERE_OVERLOAD > 150 %.
final class ReceiverLoadClassifier {
  const ReceiverLoadClassifier({this.zeroTolerance = 1e-9});

  final double zeroTolerance;

  ReceiverLoadState? evaluate({
    required ComponentInstance component,
    required double currentA,
  }) {
    final Object? raw = component.parameters[ReceiverNominalRating.currentKey];
    if (raw is! num) return null;
    final double rated = raw.toDouble();
    if (!rated.isFinite || rated <= zeroTolerance || !currentA.isFinite) {
      return null;
    }

    final double current = currentA.abs();
    final double ratio = current / rated;
    final ReceiverLoadCode code;
    if (current <= zeroTolerance) {
      code = ReceiverLoadCode.off;
    } else if (ratio > 1.5) {
      code = ReceiverLoadCode.severeOverload;
    } else if (ratio > 1.05) {
      code = ReceiverLoadCode.overload;
    } else if (ratio < 0.75) {
      code = ReceiverLoadCode.underload;
    } else {
      code = ReceiverLoadCode.normal;
    }

    return ReceiverLoadState(
      componentId: component.id,
      code: code,
      currentA: current,
      ratedCurrentA: rated,
      loadRatio: ratio,
    );
  }
}
