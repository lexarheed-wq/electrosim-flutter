import 'domain_error.dart';
import 'ids.dart';
import 'json_support.dart';

/// A physical instrument is never an electrical receiver or a source.
/// Its selected function and ports are interpreted by InstrumentProjection.
enum InstrumentKind {
  voltmeter,
  ammeter,
  multimeter,
  clampAmmeter,
  frequencyMeter,
  phaseSequenceTester,
}

enum InstrumentMode {
  voltageDc,
  voltageAcRms,
  currentDc,
  currentAcRms,
  resistance,
  continuity,
  frequency,
  phaseSequence,
}

enum InstrumentPort { voltOhm, milliamp, amp, common, phase1, phase2, phase3, clamp }

final class InstrumentInstance {
  InstrumentInstance({
    required this.id,
    required this.kind,
    required this.mode,
    this.inputImpedanceOhm = 10000000.0,
    this.burdenResistanceOhm = 0.01,
    this.maximumVoltageV = 1000.0,
    this.maximumCurrentA = 10.0,
    this.fuseRatingA = 10.0,
    this.fuseBlown = false,
    this.poweredOn = true,
    this.cutConnectionId,
    Map<String, Object?> settings = const <String, Object?>{},
  }) : settings = freezeJsonMap(settings) {
    for (final MapEntry<String, double> value in <String, double>{
      'inputImpedanceOhm': inputImpedanceOhm,
      'burdenResistanceOhm': burdenResistanceOhm,
      'maximumVoltageV': maximumVoltageV,
      'maximumCurrentA': maximumCurrentA,
      'fuseRatingA': fuseRatingA,
    }.entries) {
      if (!value.value.isFinite || value.value <= 0.0) {
        throw DomainException(
          code: DomainErrorCode.invalidValue,
          message: 'Instrument ${value.key} must be positive and finite.',
          context: <String, Object?>{'instrumentId': id.value},
        );
      }
    }
  }

  final InstrumentId id;
  final InstrumentKind kind;
  final InstrumentMode mode;
  final double inputImpedanceOhm;
  final double burdenResistanceOhm;
  final double maximumVoltageV;
  final double maximumCurrentA;
  final double fuseRatingA;
  final bool fuseBlown;
  final bool poweredOn;

  /// Set only when a meter is inserted into an explicitly cut wire.
  /// The circuit designer never edits the permanent connection implicitly.
  final ConnectionId? cutConnectionId;
  final JsonMap settings;

  JsonMap toJson() => <String, Object?>{
    'id': id.value,
    'kind': kind.name,
    'mode': mode.name,
    'inputImpedanceOhm': inputImpedanceOhm,
    'burdenResistanceOhm': burdenResistanceOhm,
    'maximumVoltageV': maximumVoltageV,
    'maximumCurrentA': maximumCurrentA,
    'fuseRatingA': fuseRatingA,
    'fuseBlown': fuseBlown,
    'poweredOn': poweredOn,
    if (cutConnectionId != null) 'cutConnectionId': cutConnectionId!.value,
    'settings': settings,
  };

  factory InstrumentInstance.fromJson(JsonMap json) => InstrumentInstance(
    id: InstrumentId(requireString(json, 'id')),
    kind: _readEnum(InstrumentKind.values, requireString(json, 'kind'), 'kind'),
    mode: _readEnum(InstrumentMode.values, requireString(json, 'mode'), 'mode'),
    inputImpedanceOhm: _finitePositive(json, 'inputImpedanceOhm'),
    burdenResistanceOhm: _finitePositive(json, 'burdenResistanceOhm'),
    maximumVoltageV: _finitePositive(json, 'maximumVoltageV'),
    maximumCurrentA: _finitePositive(json, 'maximumCurrentA'),
    fuseRatingA: _finitePositive(json, 'fuseRatingA'),
    fuseBlown: requireBool(json, 'fuseBlown'),
    poweredOn: requireBool(json, 'poweredOn'),
    cutConnectionId: json['cutConnectionId'] == null
        ? null
        : ConnectionId(requireString(json, 'cutConnectionId')),
    settings: requireMap(json, 'settings'),
  );

  static T _readEnum<T extends Enum>(
    List<T> candidates,
    String name,
    String field,
  ) {
    for (final T item in candidates) {
      if (item.name == name) return item;
    }
    throw DomainException(
      code: DomainErrorCode.invalidValue,
      message: 'Unsupported instrument $field: $name.',
    );
  }

  static double _finitePositive(JsonMap json, String field) {
    final Object? raw = json[field];
    if (raw is! num || !raw.toDouble().isFinite || raw.toDouble() <= 0.0) {
      throw DomainException(
        code: DomainErrorCode.invalidValue,
        message: '$field must be positive and finite.',
      );
    }
    return raw.toDouble();
  }

  @override
  bool operator ==(Object other) =>
      other is InstrumentInstance &&
      other.id == id &&
      other.kind == kind &&
      other.mode == mode &&
      other.inputImpedanceOhm == inputImpedanceOhm &&
      other.burdenResistanceOhm == burdenResistanceOhm &&
      other.maximumVoltageV == maximumVoltageV &&
      other.maximumCurrentA == maximumCurrentA &&
      other.fuseRatingA == fuseRatingA &&
      other.fuseBlown == fuseBlown &&
      other.poweredOn == poweredOn &&
      other.cutConnectionId == cutConnectionId &&
      deepJsonEquals(other.settings, settings);

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    mode,
    inputImpedanceOhm,
    burdenResistanceOhm,
    maximumVoltageV,
    maximumCurrentA,
    fuseRatingA,
    fuseBlown,
    poweredOn,
    cutConnectionId,
    deepJsonHash(settings),
  );
}

final class ProbeConnection {
  ProbeConnection({
    required this.id,
    required this.instrumentId,
    required this.port,
    this.terminalId,
    this.connectionId,
  }) {
    if ((terminalId == null) == (connectionId == null)) {
      throw DomainException(
        code: DomainErrorCode.invalidValue,
        message: 'A probe must target exactly one terminal or existing wire.',
      );
    }
  }

  final ProbeId id;
  final InstrumentId instrumentId;
  final InstrumentPort port;
  final TerminalId? terminalId;
  final ConnectionId? connectionId;

  JsonMap toJson() => <String, Object?>{
    'id': id.value,
    'instrumentId': instrumentId.value,
    'port': port.name,
    if (terminalId != null) 'terminalId': terminalId!.value,
    if (connectionId != null) 'connectionId': connectionId!.value,
  };

  factory ProbeConnection.fromJson(JsonMap json) => ProbeConnection(
    id: ProbeId(requireString(json, 'id')),
    instrumentId: InstrumentId(requireString(json, 'instrumentId')),
    port: InstrumentInstance._readEnum(
      InstrumentPort.values, requireString(json, 'port'), 'port'),
    terminalId: json['terminalId'] == null
        ? null : TerminalId(requireString(json, 'terminalId')),
    connectionId: json['connectionId'] == null
        ? null : ConnectionId(requireString(json, 'connectionId')),
  );

  @override
  bool operator ==(Object other) =>
      other is ProbeConnection &&
      other.id == id &&
      other.instrumentId == instrumentId &&
      other.port == port &&
      other.terminalId == terminalId &&
      other.connectionId == connectionId;

  @override
  int get hashCode => Object.hash(
    id, instrumentId, port, terminalId, connectionId);
}
