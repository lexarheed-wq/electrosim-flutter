import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

/// R1 contracts only. No solver, app or Flutter dependency.
final class PneumaticContractException implements Exception {
  const PneumaticContractException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => 'PneumaticContractException($code): $message';
}

String _checkedId(String id) {
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9.:-]{0,127}$').hasMatch(id)) {
    throw PneumaticContractException('invalid_id', 'Invalid pneumatic ID: $id');
  }
  return id;
}

void _positiveFinite(double value, String field) {
  if (!value.isFinite || value <= 0) {
    throw PneumaticContractException(
      'invalid_dimension',
      '$field must be finite and strictly positive.',
    );
  }
}

void _nonnegativeFinite(double value, String field) {
  if (!value.isFinite || value < 0) {
    throw PneumaticContractException(
      'invalid_dimension',
      '$field must be finite and nonnegative.',
    );
  }
}

/// Never substitute an electrical TerminalId for this type.
final class PneumaticPortId {
  PneumaticPortId(String value) : value = _checkedId(value);
  final String value;
  @override
  bool operator ==(Object other) => other is PneumaticPortId && other.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => value;
}

/// Pneumatic connections never become ElectricalMode values.
enum PneumaticPortRole { supply, work, exhaust, pilot }

enum PneumaticDeviceKind {
  idealSource,
  regulator,
  valve32,
  valve52,
  checkValve,
  restrictor,
  singleActingCylinder,
  doubleActingCylinder,
  tee,
  manifold,
  silencer,
  manometer,
  pressureSwitch,
  positionSensor,
  other,
}

/// Pressure parameters use *absolute* pascals. No graphical coordinates.
final class PneumaticPort {
  PneumaticPort({
    required this.id,
    required String deviceId,
    required this.role,
    double? maxAbsolutePressurePa,
  }) : deviceId = _checkedId(deviceId),
       maxAbsolutePressurePa = maxAbsolutePressurePa {
    if (maxAbsolutePressurePa != null) {
      _positiveFinite(maxAbsolutePressurePa, 'maxAbsolutePressurePa');
    }
  }
  final PneumaticPortId id;
  final String deviceId;
  final PneumaticPortRole role;
  final double? maxAbsolutePressurePa;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id.value,
    'deviceId': deviceId,
    'role': role.name,
    if (maxAbsolutePressurePa != null)
      'maxAbsolutePressurePa': maxAbsolutePressurePa,
  };

  factory PneumaticPort.fromJson(Map<String, dynamic> j) => PneumaticPort(
    id: PneumaticPortId(_string(j, 'id')),
    deviceId: _string(j, 'deviceId'),
    role: _enumByName(PneumaticPortRole.values, _string(j, 'role'), 'role'),
    maxAbsolutePressurePa: _optionalDouble(j, 'maxAbsolutePressurePa'),
  );
}

/// Valid model parameters are pure, typed SI doubles, not UI state.
final class PneumaticDevice {
  PneumaticDevice({
    required String id,
    required this.kind,
    required List<PneumaticPort> ports,
    Map<String, double> parametersSi = const <String, double>{},
  }) : id = _checkedId(id),
       ports = List<PneumaticPort>.unmodifiable(ports),
       parametersSi = UnmodifiableMapView<String, double>(
         Map<String, double>.from(parametersSi),
       ) {
    if (ports.isEmpty) {
      throw const PneumaticContractException(
        'missing_ports', 'Pneumatic device requires explicit physical ports.',
      );
    }
    final Set<String> ids = <String>{};
    for (final PneumaticPort port in ports) {
      if (port.deviceId != id) {
        throw PneumaticContractException(
          'wrong_owner', 'Port ${port.id} does not belong to device $id.',
        );
      }
      if (!ids.add(port.id.value)) {
        throw PneumaticContractException('duplicate_port', 'Duplicate port ${port.id}.');
      }
    }
    for (final MapEntry<String, double> entry in parametersSi.entries) {
      _checkedId(entry.key);
      if (!entry.value.isFinite) {
        throw PneumaticContractException(
          'invalid_parameter', 'Non-finite parameter ${entry.key}.',
        );
      }
    }
  }
  final String id;
  final PneumaticDeviceKind kind;
  final List<PneumaticPort> ports;
  final Map<String, double> parametersSi;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id, 'kind': kind.name,
    'ports': ports.map((PneumaticPort p) => p.toJson()).toList(),
    'parametersSi': parametersSi,
  };

  factory PneumaticDevice.fromJson(Map<String, dynamic> j) {
    final Map<String, dynamic> p = _map(j['parametersSi'] ?? <String, Object?>{});
    final Map<String, double> params = <String, double>{};
    for (final MapEntry<String, dynamic> entry in p.entries) {
      if (entry.value is! num) {
        throw PneumaticContractException(
          'invalid_parameter', 'Non-numeric parameter ${entry.key}.',
        );
      }
      params[entry.key] = (entry.value as num).toDouble();
    }
    return PneumaticDevice(
      id: _string(j, 'id'),
      kind: _enumByName(PneumaticDeviceKind.values, _string(j, 'kind'), 'kind'),
      ports: _list(j, 'ports').map(
        (Object? item) => PneumaticPort.fromJson(_map(item)),
      ).toList(),
      parametersSi: params,
    );
  }
}

enum PneumaticPipeFault { none, leaking, blocked, disconnected }
enum PneumaticPipeLossModel { ideal, effectiveOrifice, distributedDarcy }

/// Physical hose dimensions are immutable and independent of zoom/layout.
final class PneumaticPipe {
  PneumaticPipe({
    required String id,
    required this.fromPortId,
    required this.toPortId,
    required this.lengthM,
    required this.innerDiameterM,
    this.lossModel = PneumaticPipeLossModel.effectiveOrifice,
    this.fault = PneumaticPipeFault.none,
    this.lossCoefficient = 0,
  }) : id = _checkedId(id) {
    if (fromPortId == toPortId) {
      throw const PneumaticContractException(
        'self_connection', 'A pneumatic hose cannot connect a port to itself.',
      );
    }
    _positiveFinite(lengthM, 'lengthM');
    _positiveFinite(innerDiameterM, 'innerDiameterM');
    _nonnegativeFinite(lossCoefficient, 'lossCoefficient');
  }
  final String id;
  final PneumaticPortId fromPortId;
  final PneumaticPortId toPortId;
  final double lengthM;
  final double innerDiameterM;
  final PneumaticPipeLossModel lossModel;
  final PneumaticPipeFault fault;
  final double lossCoefficient;

  double get internalVolumeM3 => math.pi * innerDiameterM *
      innerDiameterM * lengthM / 4.0;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'fromPortId': fromPortId.value, 'toPortId': toPortId.value,
    'lengthM': lengthM, 'innerDiameterM': innerDiameterM,
    'lossModel': lossModel.name, 'fault': fault.name,
    'lossCoefficient': lossCoefficient,
  };

  factory PneumaticPipe.fromJson(Map<String, dynamic> j) => PneumaticPipe(
    id: _string(j, 'id'),
    fromPortId: PneumaticPortId(_string(j, 'fromPortId')),
    toPortId: PneumaticPortId(_string(j, 'toPortId')),
    lengthM: _double(j, 'lengthM'),
    innerDiameterM: _double(j, 'innerDiameterM'),
    lossModel: _enumByName(
      PneumaticPipeLossModel.values, _string(j, 'lossModel'), 'lossModel',
    ),
    fault: _enumByName(
      PneumaticPipeFault.values, _string(j, 'fault'), 'fault',
    ),
    lossCoefficient: _double(j, 'lossCoefficient'),
  );
}

/// A tee is a device with three separate ports; crossings and branches are not
/// inferred from drawn line intersections. Each individual port takes one hose.
final class PneumaticNetwork {
  PneumaticNetwork({
    List<PneumaticDevice> devices = const <PneumaticDevice>[],
    List<PneumaticPipe> pipes = const <PneumaticPipe>[],
  }) : devices = List<PneumaticDevice>.unmodifiable(devices),
       pipes = List<PneumaticPipe>.unmodifiable(pipes) {
    final Set<String> deviceIds = <String>{};
    final Set<PneumaticPortId> portIds = <PneumaticPortId>{};
    final Set<String> pipeIds = <String>{};
    for (final PneumaticDevice device in devices) {
      if (!deviceIds.add(device.id)) {
        throw PneumaticContractException('duplicate_device', 'Device ${device.id}.');
      }
      for (final PneumaticPort port in device.ports) {
        if (!portIds.add(port.id)) {
          throw PneumaticContractException('duplicate_port', 'Port ${port.id}.');
        }
      }
    }
    final Set<PneumaticPortId> occupiedPorts = <PneumaticPortId>{};
    for (final PneumaticPipe pipe in pipes) {
      if (!pipeIds.add(pipe.id)) {
        throw PneumaticContractException('duplicate_pipe', 'Pipe ${pipe.id}.');
      }
      if (!portIds.contains(pipe.fromPortId) || !portIds.contains(pipe.toPortId)) {
        throw PneumaticContractException(
          'unknown_port', 'Pipe ${pipe.id} references an unknown air port.',
        );
      }
      if (!occupiedPorts.add(pipe.fromPortId) ||
          !occupiedPorts.add(pipe.toPortId)) {
        throw PneumaticContractException(
          'implicit_branch', 'Branch requires an explicit tee/manifold device.',
        );
      }
    }
  }
  static const int currentSchemaVersion = 1;
  final List<PneumaticDevice> devices;
  final List<PneumaticPipe> pipes;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': currentSchemaVersion,
    'devices': devices.map((PneumaticDevice d) => d.toJson()).toList(),
    'pipes': pipes.map((PneumaticPipe p) => p.toJson()).toList(),
  };
  String toJsonString() => jsonEncode(toJson());
  factory PneumaticNetwork.fromJsonString(String source) {
    final Object? decoded = jsonDecode(source);
    return PneumaticNetwork.fromJson(_map(decoded));
  }
  factory PneumaticNetwork.fromJson(Map<String, dynamic> j) {
    final Object? version = j['schemaVersion'];
    if (version != currentSchemaVersion) {
      throw PneumaticContractException(
        'unsupported_schema', 'Unsupported air network version: $version.',
      );
    }
    return PneumaticNetwork(
      devices: _list(j, 'devices').map(
        (Object? item) => PneumaticDevice.fromJson(_map(item)),
      ).toList(),
      pipes: _list(j, 'pipes').map(
        (Object? item) => PneumaticPipe.fromJson(_map(item)),
      ).toList(),
    );
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  throw const PneumaticContractException(
    'invalid_json', 'Expected a JSON object.',
  );
}
List<Object?> _list(Map<String, dynamic> j, String field) {
  final Object? value = j[field];
  if (value is List) return value.cast<Object?>();
  throw PneumaticContractException('invalid_json', '$field must be an array.');
}
String _string(Map<String, dynamic> j, String field) {
  final Object? value = j[field];
  if (value is String) return value;
  throw PneumaticContractException('invalid_json', '$field must be a string.');
}
double _double(Map<String, dynamic> j, String field) {
  final Object? value = j[field];
  if (value is num) return value.toDouble();
  throw PneumaticContractException('invalid_json', '$field must be numeric.');
}
double? _optionalDouble(Map<String, dynamic> j, String field) {
  if (!j.containsKey(field) || j[field] == null) return null;
  return _double(j, field);
}
T _enumByName<T extends Enum>(List<T> values, String name, String field) {
  for (final T v in values) {
    if (v.name == name) return v;
  }
  throw PneumaticContractException('invalid_enum', '$field: unknown $name.');
}
