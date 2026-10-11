import 'dart:collection';
import 'dart:convert';

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';

final class MultiphysicsContractException implements Exception {
  const MultiphysicsContractException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => 'MultiphysicsContractException($code): $message';
}

String _id(String id) {
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9.:-]{0,127}$').hasMatch(id)) {
    throw MultiphysicsContractException('invalid_id', 'Invalid ID: $id');
  }
  return id;
}

enum ElectropneumaticLinkRole {
  solenoidCoil,
  positionContact,
  pressureContact,
}

/// A link does not change or replace an existing electrical Connection.
final class ElectropneumaticLink {
  ElectropneumaticLink({
    required String id,
    required String electricalComponentId,
    required String pneumaticDeviceId,
    required this.role,
    String channel = 'main',
  }) : id = _id(id),
       electricalComponentId = _id(electricalComponentId),
       pneumaticDeviceId = _id(pneumaticDeviceId),
       channel = _id(channel);
  final String id;
  final String electricalComponentId;
  final String pneumaticDeviceId;
  final ElectropneumaticLinkRole role;
  final String channel;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'electricalComponentId': electricalComponentId,
    'pneumaticDeviceId': pneumaticDeviceId,
    'role': role.name,
    'channel': channel,
  };

  factory ElectropneumaticLink.fromJson(Map<String, dynamic> j) =>
      ElectropneumaticLink(
        id: _text(j, 'id'),
        electricalComponentId: _text(j, 'electricalComponentId'),
        pneumaticDeviceId: _text(j, 'pneumaticDeviceId'),
        role: _enumByName(
          ElectropneumaticLinkRole.values,
          _text(j, 'role'),
          'role',
        ),
        channel: _text(j, 'channel'),
      );
}

/// The same *physical* device can have electrical and pneumatic subparts.
final class PhysicalDeviceRecord {
  PhysicalDeviceRecord({
    required String id,
    String? pneumaticDeviceId,
    List<String> electricalComponentIds = const <String>[],
  }) : id = _id(id),
       pneumaticDeviceId =
           pneumaticDeviceId == null ? null : _id(pneumaticDeviceId),
       electricalComponentIds = List<String>.unmodifiable(
         electricalComponentIds.map(_id),
       ) {
    if (this.pneumaticDeviceId == null && this.electricalComponentIds.isEmpty) {
      throw const MultiphysicsContractException(
        'empty_device', 'A physical device must reference a subpart.',
      );
    }
    if (this.electricalComponentIds.toSet().length !=
        this.electricalComponentIds.length) {
      throw const MultiphysicsContractException(
        'duplicate_subpart', 'Duplicate electrical subpart on a device.',
      );
    }
  }
  final String id;
  final String? pneumaticDeviceId;
  final List<String> electricalComponentIds;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    if (pneumaticDeviceId != null) 'pneumaticDeviceId': pneumaticDeviceId,
    'electricalComponentIds': electricalComponentIds,
  };

  factory PhysicalDeviceRecord.fromJson(Map<String, dynamic> j) =>
      PhysicalDeviceRecord(
        id: _text(j, 'id'),
        pneumaticDeviceId: _optionalText(j, 'pneumaticDeviceId'),
        electricalComponentIds: _array(j, 'electricalComponentIds')
            .map((Object? v) {
              if (v is String) return v;
              throw const MultiphysicsContractException(
                'invalid_json', 'Electrical subpart ID must be a string.',
              );
            })
            .toList(),
      );
}

/// Positions exist solely for presentation, never physics or hose length.
final class PhysicalViewPose {
  PhysicalViewPose({
    required this.x,
    required this.y,
    this.rotationRad = 0,
  }) {
    if (!x.isFinite || !y.isFinite || !rotationRad.isFinite) {
      throw const MultiphysicsContractException(
        'invalid_layout', 'View poses must be finite numbers.',
      );
    }
  }
  final double x;
  final double y;
  final double rotationRad;
  Map<String, Object?> toJson() => <String, Object?>{
    'x': x, 'y': y, 'rotationRad': rotationRad,
  };
  factory PhysicalViewPose.fromJson(Map<String, dynamic> j) => PhysicalViewPose(
    x: _number(j, 'x'), y: _number(j, 'y'),
    rotationRad: _number(j, 'rotationRad'),
  );
}

/// Structural design state only. Runtime air pressures and positions live in
/// a later versioned RuntimeSnapshot, not this immutable design envelope.
final class MultiphysicsProject {
  MultiphysicsProject({
    required this.electricalCircuit,
    PneumaticNetwork? pneumaticNetwork,
    List<PhysicalDeviceRecord> devices = const <PhysicalDeviceRecord>[],
    List<ElectropneumaticLink> links = const <ElectropneumaticLink>[],
    Map<String, PhysicalViewPose> physicalLayout =
        const <String, PhysicalViewPose>{},
    Map<String, PhysicalViewPose> schematicLayout =
        const <String, PhysicalViewPose>{},
  }) : pneumaticNetwork = pneumaticNetwork ?? PneumaticNetwork(),
       devices = List<PhysicalDeviceRecord>.unmodifiable(devices),
       links = List<ElectropneumaticLink>.unmodifiable(links),
       physicalLayout = UnmodifiableMapView<String, PhysicalViewPose>(
         Map<String, PhysicalViewPose>.from(physicalLayout),
       ),
       schematicLayout = UnmodifiableMapView<String, PhysicalViewPose>(
         Map<String, PhysicalViewPose>.from(schematicLayout),
       ) {
    _validate();
  }

  static const int currentSchemaVersion = 1;
  final CircuitState electricalCircuit;
  final PneumaticNetwork pneumaticNetwork;
  final List<PhysicalDeviceRecord> devices;
  final List<ElectropneumaticLink> links;
  final Map<String, PhysicalViewPose> physicalLayout;
  final Map<String, PhysicalViewPose> schematicLayout;

  void _validate() {
    final Set<String> electricalIds = <String>{
      for (final ComponentInstance c in electricalCircuit.components) c.id.value,
    };
    final Set<String> pneumaticIds = <String>{
      for (final PneumaticDevice d in pneumaticNetwork.devices) d.id,
    };
    final Set<String> deviceIds = <String>{};
    final Set<String> assignedElectrical = <String>{};
    final Set<String> assignedPneumatic = <String>{};
    final Map<String, PhysicalDeviceRecord> ownerByElectrical =
        <String, PhysicalDeviceRecord>{};
    final Map<String, PhysicalDeviceRecord> ownerByPneumatic =
        <String, PhysicalDeviceRecord>{};
    for (final PhysicalDeviceRecord physical in devices) {
      if (!deviceIds.add(physical.id)) {
        throw MultiphysicsContractException(
          'duplicate_device', 'Duplicate physical device: ${physical.id}',
        );
      }
      final String? air = physical.pneumaticDeviceId;
      if (air != null) {
        if (!pneumaticIds.contains(air)) {
          throw MultiphysicsContractException(
            'unknown_pneumatic_device', 'Unknown air device: $air',
          );
        }
        if (!assignedPneumatic.add(air)) {
          throw MultiphysicsContractException(
            'ambiguous_identity', 'Air device $air has several owners.',
          );
        }
        ownerByPneumatic[air] = physical;
      }
      for (final String electrical in physical.electricalComponentIds) {
        if (!electricalIds.contains(electrical)) {
          throw MultiphysicsContractException(
            'unknown_electrical_component', 'Unknown electrical subpart: $electrical',
          );
        }
        if (!assignedElectrical.add(electrical)) {
          throw MultiphysicsContractException(
            'ambiguous_identity', 'Electrical subpart has several owners.',
          );
        }
        ownerByElectrical[electrical] = physical;
      }
    }
    final Set<String> linkIds = <String>{};
    for (final ElectropneumaticLink link in links) {
      if (!linkIds.add(link.id)) {
        throw MultiphysicsContractException(
          'duplicate_link', 'Duplicate coupling link: ${link.id}',
        );
      }
      if (!electricalIds.contains(link.electricalComponentId) ||
          !pneumaticIds.contains(link.pneumaticDeviceId)) {
        throw MultiphysicsContractException(
          'dangling_link', 'Link ${link.id} contains an absent subpart.',
        );
      }
      if (electricalCircuit.mode != ElectricalMode.dc) {
        throw const MultiphysicsContractException(
          'unsupported_coupling_mode',
          'First electropneumatic coupling supports DC control only.',
        );
      }
      final PhysicalDeviceRecord? electricalOwner =
          ownerByElectrical[link.electricalComponentId];
      final PhysicalDeviceRecord? airOwner =
          ownerByPneumatic[link.pneumaticDeviceId];
      if (electricalOwner == null ||
          airOwner == null ||
          !identical(electricalOwner, airOwner)) {
        throw MultiphysicsContractException(
          'identity_mismatch',
          'Linked electrical and pneumatic subparts must share one physical device.',
        );
      }
    }
    for (final Map<String, PhysicalViewPose> layout in
        <Map<String, PhysicalViewPose>>[physicalLayout, schematicLayout]) {
      for (final String key in layout.keys) {
        if (!deviceIds.contains(key)) {
          throw MultiphysicsContractException(
            'unknown_layout_object', 'Layout references absent device: $key',
          );
        }
      }
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': currentSchemaVersion,
    'electricalCircuit': electricalCircuit.toJson(),
    'pneumaticNetwork': pneumaticNetwork.toJson(),
    'devices': devices.map((PhysicalDeviceRecord d) => d.toJson()).toList(),
    'links': links.map((ElectropneumaticLink l) => l.toJson()).toList(),
    'physicalLayout': <String, Object?>{
      for (final MapEntry<String, PhysicalViewPose> e in physicalLayout.entries)
        e.key: e.value.toJson(),
    },
    'schematicLayout': <String, Object?>{
      for (final MapEntry<String, PhysicalViewPose> e in schematicLayout.entries)
        e.key: e.value.toJson(),
    },
  };
  String toJsonString() => jsonEncode(toJson());

  factory MultiphysicsProject.fromJsonString(String source) =>
      MultiphysicsProject.fromJson(_map(jsonDecode(source)));

  factory MultiphysicsProject.fromJson(Map<String, dynamic> j) {
    if (j['schemaVersion'] != currentSchemaVersion) {
      throw MultiphysicsContractException(
        'unsupported_schema', 'Unsupported project schema ${j['schemaVersion']}.',
      );
    }
    return MultiphysicsProject(
      electricalCircuit: CircuitState.fromJson(_map(j['electricalCircuit'])),
      pneumaticNetwork: PneumaticNetwork.fromJson(_map(j['pneumaticNetwork'])),
      devices: _array(j, 'devices')
          .map((Object? x) => PhysicalDeviceRecord.fromJson(_map(x)))
          .toList(),
      links: _array(j, 'links')
          .map((Object? x) => ElectropneumaticLink.fromJson(_map(x)))
          .toList(),
      physicalLayout: _poses(j, 'physicalLayout'),
      schematicLayout: _poses(j, 'schematicLayout'),
    );
  }
}

Map<String, PhysicalViewPose> _poses(Map<String, dynamic> j, String key) {
  final Map<String, dynamic> raw = _map(j[key]);
  return raw.map(
    (String id, dynamic value) => MapEntry(
      id, PhysicalViewPose.fromJson(_map(value)),
    ),
  );
}
Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  throw const MultiphysicsContractException('invalid_json', 'Expected object.');
}
List<Object?> _array(Map<String, dynamic> j, String key) {
  final Object? value = j[key];
  if (value is List) return value.cast<Object?>();
  throw MultiphysicsContractException('invalid_json', '$key must be an array.');
}
String _text(Map<String, dynamic> j, String key) {
  final Object? value = j[key];
  if (value is String) return value;
  throw MultiphysicsContractException('invalid_json', '$key must be a string.');
}
String? _optionalText(Map<String, dynamic> j, String key) {
  final Object? value = j[key];
  if (value == null) return null;
  if (value is String) return value;
  throw MultiphysicsContractException('invalid_json', '$key must be a string.');
}
double _number(Map<String, dynamic> j, String key) {
  final Object? value = j[key];
  if (value is num) return value.toDouble();
  throw MultiphysicsContractException('invalid_json', '$key must be numeric.');
}
T _enumByName<T extends Enum>(List<T> values, String name, String field) {
  for (final T item in values) {
    if (item.name == name) return item;
  }
  throw MultiphysicsContractException('invalid_enum', 'Unknown $field: $name');
}
