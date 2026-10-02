import 'domain_error.dart';
import 'json_support.dart';

enum ElectricalMode { dc, ac1, ac3, pv }

enum ElectricalUnit {
  volt('V'),
  ampere('A'),
  ohm('Ω'),
  watt('W'),
  wattHour('Wh'),
  kilowattHour('kWh'),
  hertz('Hz'),
  voltAmpere('VA'),
  varUnit('var'),
  degree('deg'),
  radian('rad');

  const ElectricalUnit(this.symbol);

  final String symbol;
}

enum ComponentCondition { normal, openCircuit, shortCircuit, degraded, disabled }

enum TerminalRole {
  generic,
  positive,
  negative,
  line,
  neutral,
  protectiveEarth,
  phaseL1,
  phaseL2,
  phaseL3,
  input,
  output,
  common,
  normallyOpen,
  normallyClosed,
  measurement,
  lineL1,
  lineL2,
  lineL3,
  loadT1,
  loadT2,
  loadT3,
  coilA1,
  coilA2,
  auxiliaryCommon,
  auxiliaryNormallyOpen,
  auxiliaryNormallyClosed,
}

enum PhaseTag {
  none,
  dcPositive,
  dcNegative,
  l1,
  l2,
  l3,
  neutral,
  protectiveEarth,
}

enum ConductorType { wire, cable, jumper, busbar }

T enumByName<T extends Enum>(Iterable<T> values, String raw, String field) {
  for (final T value in values) {
    if (value.name == raw) {
      return value;
    }
  }
  throw DomainException(
    code: DomainErrorCode.invalidEnumValue,
    message: 'Invalid $field value: $raw',
    context: <String, Object?>{'field': field, 'value': raw},
  );
}

final class ElectricalQuantity {
  ElectricalQuantity({required this.value, required this.unit}) {
    if (!value.isFinite) {
      throw DomainException(
        code: DomainErrorCode.invalidValue,
        message: 'Electrical quantities must be finite.',
        context: <String, Object?>{'value': value.toString(), 'unit': unit.name},
      );
    }
  }

  factory ElectricalQuantity.fromJson(JsonMap json) {
    final Object? rawValue = json['value'];
    if (rawValue is! num) {
      return missingField('value', json);
    }
    return ElectricalQuantity(
      value: rawValue.toDouble(),
      unit: enumByName<ElectricalUnit>(
        ElectricalUnit.values,
        requireString(json, 'unit'),
        'unit',
      ),
    );
  }

  final double value;
  final ElectricalUnit unit;

  JsonMap toJson() => <String, Object?>{'value': value, 'unit': unit.name};

  @override
  bool operator ==(Object other) =>
      other is ElectricalQuantity && other.value == value && other.unit == unit;

  @override
  int get hashCode => Object.hash(value, unit);
}
