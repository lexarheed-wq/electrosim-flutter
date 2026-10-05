import 'domain_error.dart';
import 'json_support.dart';

/// Canonical receiver nominal data used by the Flutter engine.
///
/// These keys are intentionally distinct from protection settings. A receiver
/// nominal current describes the load itself; it must never be interpreted as
/// a breaker/fuse calibre.
final class ReceiverNominalRating {
  ReceiverNominalRating({double? voltageV, double? currentA, double? powerW})
    : voltageV = _positiveFiniteOrNull(voltageV, voltageKey),
      currentA = _positiveFiniteOrNull(currentA, currentKey),
      powerW = _positiveFiniteOrNull(powerW, powerKey) {
    if (this.voltageV == null && this.currentA == null && this.powerW == null) {
      throw DomainException(
        code: DomainErrorCode.invalidValue,
        message: 'ReceiverNominalRating requires at least one nominal value.',
      );
    }
  }

  static const String voltageKey = 'receiverNominalVoltageV';
  static const String currentKey = 'receiverNominalCurrentA';
  static const String powerKey = 'receiverNominalPowerW';

  final double? voltageV;
  final double? currentA;
  final double? powerW;

  static ReceiverNominalRating? tryFromParameters(JsonMap parameters) {
    final bool hasAny =
        parameters.containsKey(voltageKey) ||
        parameters.containsKey(currentKey) ||
        parameters.containsKey(powerKey);
    if (!hasAny) {
      return null;
    }
    return ReceiverNominalRating(
      voltageV: _readPositiveFinite(parameters, voltageKey),
      currentA: _readPositiveFinite(parameters, currentKey),
      powerW: _readPositiveFinite(parameters, powerKey),
    );
  }

  JsonMap toParameters() => <String, Object?>{
    if (voltageV != null) voltageKey: voltageV,
    if (currentA != null) currentKey: currentA,
    if (powerW != null) powerKey: powerW,
  };

  @override
  bool operator ==(Object other) =>
      other is ReceiverNominalRating &&
      other.voltageV == voltageV &&
      other.currentA == currentA &&
      other.powerW == powerW;

  @override
  int get hashCode => Object.hash(voltageV, currentA, powerW);
}

/// Canonical protection calibre data.
///
/// This is deliberately a separate type and a separate parameter key from
/// [ReceiverNominalRating.currentKey]. The separation prevents the historical
/// error where a receiver nominal current and a protection calibre are treated
/// as the same physical quantity.
final class ProtectionRating {
  ProtectionRating({required double ratedCurrentA})
    : ratedCurrentA = _positiveFiniteRequired(ratedCurrentA, ratedCurrentKey);

  static const String ratedCurrentKey = 'protectionRatedCurrentA';

  final double ratedCurrentA;

  static ProtectionRating? tryFromParameters(JsonMap parameters) {
    if (!parameters.containsKey(ratedCurrentKey)) {
      return null;
    }
    return ProtectionRating(
      ratedCurrentA: _readPositiveFinite(parameters, ratedCurrentKey)!,
    );
  }

  JsonMap toParameters() => <String, Object?>{ratedCurrentKey: ratedCurrentA};

  @override
  bool operator ==(Object other) =>
      other is ProtectionRating && other.ratedCurrentA == ratedCurrentA;

  @override
  int get hashCode => ratedCurrentA.hashCode;
}

double? _readPositiveFinite(JsonMap parameters, String key) {
  if (!parameters.containsKey(key)) {
    return null;
  }
  final Object? raw = parameters[key];
  if (raw is! num) {
    throw DomainException(
      code: DomainErrorCode.invalidValue,
      message: '$key must be a finite number greater than zero.',
      context: <String, Object?>{'key': key, 'value': raw},
    );
  }
  return _positiveFiniteRequired(raw.toDouble(), key);
}

double? _positiveFiniteOrNull(double? value, String key) {
  if (value == null) {
    return null;
  }
  return _positiveFiniteRequired(value, key);
}

double _positiveFiniteRequired(double value, String key) {
  if (!value.isFinite || value <= 0) {
    throw DomainException(
      code: DomainErrorCode.invalidValue,
      message: '$key must be finite and greater than zero.',
      context: <String, Object?>{'key': key, 'value': value},
    );
  }
  return value;
}
