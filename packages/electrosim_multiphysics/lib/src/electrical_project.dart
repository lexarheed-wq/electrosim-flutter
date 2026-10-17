import 'dart:convert';

import 'package:electrosim_domain/electrosim_domain.dart';

final class ElectricalProjectException implements Exception {
  const ElectricalProjectException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => 'ElectricalProjectException($code): $message';
}

String _projectId(String value) {
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$').hasMatch(value)) {
    throw ElectricalProjectException('invalid_id', 'Invalid ID: $value');
  }
  return value;
}

final class ElectricalNetwork {
  ElectricalNetwork({required String id, required this.circuit}) : id = _projectId(id);
  final String id;
  final CircuitState circuit;
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'circuit': circuit.toJson(),
  };
  factory ElectricalNetwork.fromJson(Map<String, dynamic> json) => ElectricalNetwork(
    id: _string(json, 'id'),
    circuit: CircuitState.fromJson(_map(json, 'circuit')),
  );
}

final class CrossNetworkRelayLink {
  CrossNetworkRelayLink({
    required String id,
    required String plcNetworkId,
    required String plcComponentId,
    required this.outputAddress,
    required String dcNetworkId,
    required String relayCoilId,
    required String ac3NetworkId,
    required String ac3ContactId,
  }) : id = _projectId(id),
       plcNetworkId = _projectId(plcNetworkId),
       plcComponentId = _projectId(plcComponentId),
       dcNetworkId = _projectId(dcNetworkId),
       relayCoilId = _projectId(relayCoilId),
       ac3NetworkId = _projectId(ac3NetworkId),
       ac3ContactId = _projectId(ac3ContactId);
  final String id;
  final String plcNetworkId;
  final String plcComponentId;
  final String outputAddress;
  final String dcNetworkId;
  final String relayCoilId;
  final String ac3NetworkId;
  final String ac3ContactId;
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id, 'plcNetworkId': plcNetworkId, 'plcComponentId': plcComponentId,
    'outputAddress': outputAddress, 'dcNetworkId': dcNetworkId,
    'relayCoilId': relayCoilId, 'ac3NetworkId': ac3NetworkId,
    'ac3ContactId': ac3ContactId,
  };
  factory CrossNetworkRelayLink.fromJson(Map<String, dynamic> json) => CrossNetworkRelayLink(
    id: _string(json, 'id'), plcNetworkId: _string(json, 'plcNetworkId'),
    plcComponentId: _string(json, 'plcComponentId'), outputAddress: _string(json, 'outputAddress'),
    dcNetworkId: _string(json, 'dcNetworkId'), relayCoilId: _string(json, 'relayCoilId'),
    ac3NetworkId: _string(json, 'ac3NetworkId'), ac3ContactId: _string(json, 'ac3ContactId'),
  );
}

final class CrossNetworkSignalLink {
  CrossNetworkSignalLink({
    required String id,
    required String ac3NetworkId,
    required String auxiliaryContactId,
    required String dcNetworkId,
    required String plcComponentId,
    required this.inputAddress,
  }) : id = _projectId(id),
       ac3NetworkId = _projectId(ac3NetworkId),
       auxiliaryContactId = _projectId(auxiliaryContactId),
       dcNetworkId = _projectId(dcNetworkId),
       plcComponentId = _projectId(plcComponentId);
  final String id;
  final String ac3NetworkId;
  final String auxiliaryContactId;
  final String dcNetworkId;
  final String plcComponentId;
  final String inputAddress;
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id, 'ac3NetworkId': ac3NetworkId, 'auxiliaryContactId': auxiliaryContactId,
    'dcNetworkId': dcNetworkId, 'plcComponentId': plcComponentId,
    'inputAddress': inputAddress,
  };
  factory CrossNetworkSignalLink.fromJson(Map<String, dynamic> json) => CrossNetworkSignalLink(
    id: _string(json, 'id'), ac3NetworkId: _string(json, 'ac3NetworkId'),
    auxiliaryContactId: _string(json, 'auxiliaryContactId'), dcNetworkId: _string(json, 'dcNetworkId'),
    plcComponentId: _string(json, 'plcComponentId'), inputAddress: _string(json, 'inputAddress'),
  );
}

final class CrossNetworkActuatorLink {
  CrossNetworkActuatorLink({required String id, required String plcNetworkId,
    required String plcComponentId, required this.outputAddress,
    required String targetNetworkId, required String contactorId})
      : id = _projectId(id), plcNetworkId = _projectId(plcNetworkId),
        plcComponentId = _projectId(plcComponentId), targetNetworkId = _projectId(targetNetworkId),
        contactorId = _projectId(contactorId);
  final String id, plcNetworkId, plcComponentId, outputAddress, targetNetworkId, contactorId;
  Map<String, Object?> toJson() => <String, Object?>{'id': id, 'plcNetworkId': plcNetworkId,
    'plcComponentId': plcComponentId, 'outputAddress': outputAddress,
    'targetNetworkId': targetNetworkId, 'contactorId': contactorId};
  factory CrossNetworkActuatorLink.fromJson(Map<String, dynamic> json) => CrossNetworkActuatorLink(
    id: _string(json, 'id'), plcNetworkId: _string(json, 'plcNetworkId'),
    plcComponentId: _string(json, 'plcComponentId'), outputAddress: _string(json, 'outputAddress'),
    targetNetworkId: _string(json, 'targetNetworkId'), contactorId: _string(json, 'contactorId'));
}

final class CrossNetworkConverterLink {
  CrossNetworkConverterLink({required String id, required String inputNetworkId,
    required String converterComponentId, required String outputNetworkId,
    required String outputLineTerminalId, required String outputNeutralTerminalId})
      : id = _projectId(id), inputNetworkId = _projectId(inputNetworkId),
        converterComponentId = _projectId(converterComponentId), outputNetworkId = _projectId(outputNetworkId),
        outputLineTerminalId = _projectId(outputLineTerminalId), outputNeutralTerminalId = _projectId(outputNeutralTerminalId);
  final String id, inputNetworkId, converterComponentId, outputNetworkId;
  final String outputLineTerminalId, outputNeutralTerminalId;
  Map<String, Object?> toJson() => <String, Object?>{'id': id, 'inputNetworkId': inputNetworkId,
    'converterComponentId': converterComponentId, 'outputNetworkId': outputNetworkId,
    'outputLineTerminalId': outputLineTerminalId, 'outputNeutralTerminalId': outputNeutralTerminalId};
  factory CrossNetworkConverterLink.fromJson(Map<String, dynamic> json) => CrossNetworkConverterLink(
    id: _string(json, 'id'), inputNetworkId: _string(json, 'inputNetworkId'),
    converterComponentId: _string(json, 'converterComponentId'), outputNetworkId: _string(json, 'outputNetworkId'),
    outputLineTerminalId: _string(json, 'outputLineTerminalId'), outputNeutralTerminalId: _string(json, 'outputNeutralTerminalId'));
}

/// Versioned container for independent, homogeneous electrical circuits.
final class ElectricalProject {
  ElectricalProject({
    required List<ElectricalNetwork> networks,
    List<CrossNetworkRelayLink> relayLinks = const <CrossNetworkRelayLink>[],
    List<CrossNetworkSignalLink> signalLinks = const <CrossNetworkSignalLink>[],
    List<CrossNetworkActuatorLink> actuatorLinks = const <CrossNetworkActuatorLink>[],
    List<CrossNetworkConverterLink> converterLinks = const <CrossNetworkConverterLink>[],
  }) : networks = List<ElectricalNetwork>.unmodifiable(networks),
       relayLinks = List<CrossNetworkRelayLink>.unmodifiable(relayLinks),
       signalLinks = List<CrossNetworkSignalLink>.unmodifiable(signalLinks),
       actuatorLinks = List<CrossNetworkActuatorLink>.unmodifiable(actuatorLinks),
       converterLinks = List<CrossNetworkConverterLink>.unmodifiable(converterLinks) {
    _validate();
  }

  static const int currentSchemaVersion = 2;
  final List<ElectricalNetwork> networks;
  final List<CrossNetworkRelayLink> relayLinks;
  final List<CrossNetworkSignalLink> signalLinks;
  final List<CrossNetworkActuatorLink> actuatorLinks;
  final List<CrossNetworkConverterLink> converterLinks;

  factory ElectricalProject.emptyMixedBoard() => ElectricalProject(networks: <ElectricalNetwork>[
    for (final ElectricalMode mode in <ElectricalMode>[ElectricalMode.dc, ElectricalMode.ac1, ElectricalMode.ac3, ElectricalMode.pv])
      ElectricalNetwork(id: 'mixed:${mode.name}', circuit: CircuitState(
        circuitId: CircuitId('mixed-${mode.name}'), revision: 0, mode: mode,
        settings: switch (mode) {
          ElectricalMode.dc => const <String, Object?>{},
          ElectricalMode.ac1 || ElectricalMode.ac3 => const <String, Object?>{'frequencyHz': 50.0},
          ElectricalMode.pv => const <String, Object?>{'irradianceWm2': 1000.0, 'cellTemperatureC': 25.0, 'shadingPct': 0.0},
          ElectricalMode.mixed => const <String, Object?>{},
        })),
  ]);

  factory ElectricalProject.fromLegacyCircuit(CircuitState circuit) => ElectricalProject(
    networks: <ElectricalNetwork>[ElectricalNetwork(id: 'network', circuit: circuit)],
  );

  factory ElectricalProject.fromJson(Map<String, dynamic> json) {
    final Object? version = json['schemaVersion'];
    if (version != 1 && version != currentSchemaVersion) {
      throw ElectricalProjectException('unsupported_schema', 'Unsupported electrical project schema: $version');
    }
    return ElectricalProject(
      networks: _list(json, 'networks').map((Object? v) => ElectricalNetwork.fromJson(v! as Map<String, dynamic>)).toList(),
      relayLinks: _list(json, 'relayLinks').map((Object? v) => CrossNetworkRelayLink.fromJson(v! as Map<String, dynamic>)).toList(),
      signalLinks: _list(json, 'signalLinks').map((Object? v) => CrossNetworkSignalLink.fromJson(v! as Map<String, dynamic>)).toList(),
      actuatorLinks: _optionalList(json, 'actuatorLinks').map((Object? v) => CrossNetworkActuatorLink.fromJson(v! as Map<String, dynamic>)).toList(),
      converterLinks: _optionalList(json, 'converterLinks').map((Object? v) => CrossNetworkConverterLink.fromJson(v! as Map<String, dynamic>)).toList(),
    );
  }

  factory ElectricalProject.fromJsonString(String source) {
    final Object? value = jsonDecode(source);
    if (value is! Map<String, dynamic>) throw const ElectricalProjectException('invalid_json', 'Electrical project JSON root must be an object.');
    return ElectricalProject.fromJson(value);
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': currentSchemaVersion,
    'networks': networks.map((ElectricalNetwork n) => n.toJson()).toList(),
    'relayLinks': relayLinks.map((CrossNetworkRelayLink l) => l.toJson()).toList(),
    'signalLinks': signalLinks.map((CrossNetworkSignalLink l) => l.toJson()).toList(),
    'actuatorLinks': actuatorLinks.map((CrossNetworkActuatorLink l) => l.toJson()).toList(),
    'converterLinks': converterLinks.map((CrossNetworkConverterLink l) => l.toJson()).toList(),
  };
  String toJsonString() => jsonEncode(toJson());

  void _validate() {
    if (networks.isEmpty) _fail('missing_network', 'An electrical project needs at least one network.');
    final Map<String, ElectricalNetwork> byId = <String, ElectricalNetwork>{};
    for (final ElectricalNetwork network in networks) {
      if (byId.containsKey(network.id)) _fail('duplicate_network', 'Duplicate network: ${network.id}');
      byId[network.id] = network;
    }
    final Set<ElectricalMode> domains = <ElectricalMode>{};
    for (final ElectricalNetwork network in networks) {
      if (network.circuit.mode == ElectricalMode.mixed) _fail('invalid_solver_mode', 'Project networks must use homogeneous solver domains.');
      if (!domains.add(network.circuit.mode)) _fail('duplicate_domain', 'Only one network per solver domain is supported.');
      if (network.circuit.components.where((ComponentInstance c) => c.modelType == 'plc_dc').length > 1) {
        _fail('unsupported_plc_count', 'Each DC network supports at most one PLC.');
      }
    }
    final Set<String> linkIds = <String>{};
    final Set<String> usedAddresses = <String>{};
    final Set<String> usedDevices = <String>{};
    for (final CrossNetworkRelayLink link in relayLinks) {
      if (!linkIds.add(link.id)) _fail('duplicate_link', 'Duplicate link: ${link.id}');
      final ElectricalNetwork? plcNet = byId[link.plcNetworkId];
      final ElectricalNetwork? dcNet = byId[link.dcNetworkId];
      final ElectricalNetwork? acNet = byId[link.ac3NetworkId];
      if (plcNet == null || dcNet == null || acNet == null) _fail('dangling_link', 'Relay link ${link.id} names an absent network.');
      if (plcNet.circuit.mode != ElectricalMode.dc || dcNet.circuit.mode != ElectricalMode.dc || acNet.circuit.mode != ElectricalMode.ac3) _fail('wrong_mode', 'Relay link ${link.id} has incompatible network modes.');
      if (plcNet.id != dcNet.id) _fail('split_control_network', 'PLC and relay coil must be in the same DC network.');
      _component(plcNet.circuit, link.plcComponentId, 'plc_dc', link.id);
      _component(dcNet.circuit, link.relayCoilId, 'relay_coil', link.id);
      final ComponentInstance contact = _componentAny(acNet.circuit, link.ac3ContactId, link.id);
      if (contact.modelType != 'contactor_aux_no' && contact.modelType != 'contactor_aux_nc') _fail('invalid_contact', 'Relay link ${link.id} must target an AC3 auxiliary dry contact.');
      if (!_qAddress.hasMatch(link.outputAddress)) _fail('invalid_address', 'Invalid PLC output address: ${link.outputAddress}');
      if (!usedAddresses.add('${link.plcNetworkId}/${link.plcComponentId}/${link.outputAddress}')) _fail('duplicate_endpoint', 'PLC output is linked more than once.');
      if (!usedDevices.add('${link.dcNetworkId}/${link.relayCoilId}') || !usedDevices.add('${link.ac3NetworkId}/${link.ac3ContactId}')) _fail('duplicate_endpoint', 'Physical relay endpoint is linked more than once.');
    }
    for (final CrossNetworkSignalLink link in signalLinks) {
      if (!linkIds.add(link.id)) _fail('duplicate_link', 'Duplicate link: ${link.id}');
      final ElectricalNetwork? acNet = byId[link.ac3NetworkId];
      final ElectricalNetwork? dcNet = byId[link.dcNetworkId];
      if (acNet == null || dcNet == null) _fail('dangling_link', 'Signal link ${link.id} names an absent network.');
      if (acNet.circuit.mode != ElectricalMode.ac3 || dcNet.circuit.mode != ElectricalMode.dc) _fail('wrong_mode', 'Signal link ${link.id} has incompatible network modes.');
      _component(dcNet.circuit, link.plcComponentId, 'plc_dc', link.id);
      final ComponentInstance contact = _componentAny(acNet.circuit, link.auxiliaryContactId, link.id);
      if (!<String>{'contactor_aux_no', 'contactor_aux_nc', 'aux_no', 'aux_nc'}.contains(contact.modelType)) _fail('invalid_contact', 'Signal link ${link.id} must target an AC3 auxiliary contact.');
      if (!_iAddress.hasMatch(link.inputAddress)) _fail('invalid_address', 'Invalid PLC input address: ${link.inputAddress}');
      if (!usedAddresses.add('${link.dcNetworkId}/${link.plcComponentId}/${link.inputAddress}')) _fail('duplicate_endpoint', 'PLC input is linked more than once.');
      if (!usedDevices.add('${link.ac3NetworkId}/${link.auxiliaryContactId}')) _fail('duplicate_endpoint', 'Auxiliary contact is linked more than once.');
    }
    for (final CrossNetworkActuatorLink link in actuatorLinks) {
      if (!linkIds.add(link.id)) _fail('duplicate_link', 'Duplicate link: ${link.id}');
      final ElectricalNetwork? plc = byId[link.plcNetworkId], target = byId[link.targetNetworkId];
      if (plc == null || target == null) _fail('dangling_link', 'Actuator link ${link.id} names an absent network.');
      if (plc.circuit.mode != ElectricalMode.dc || !<ElectricalMode>{ElectricalMode.ac1, ElectricalMode.ac3}.contains(target.circuit.mode)) {
        _fail('wrong_mode', 'Actuator link must connect a DC PLC to an AC1 or AC3 network.');
      }
      _component(plc.circuit, link.plcComponentId, 'plc_dc', link.id);
      final ComponentInstance contactor = _componentAny(target.circuit, link.contactorId, link.id);
      if (!<String>{'contactor_ac1', 'contactor_3p'}.contains(contactor.modelType)) _fail('invalid_contactor', 'Actuator link must target a power contactor.');
      if (!_qAddress.hasMatch(link.outputAddress)) _fail('invalid_address', 'Invalid PLC output address: ${link.outputAddress}');
      if (!usedAddresses.add('${link.plcNetworkId}/${link.plcComponentId}/${link.outputAddress}')) _fail('duplicate_endpoint', 'PLC output is linked more than once.');
      if (!usedDevices.add('${link.targetNetworkId}/${link.contactorId}')) _fail('duplicate_endpoint', 'Contactor is linked more than once.');
    }
    for (final CrossNetworkConverterLink link in converterLinks) {
      if (!linkIds.add(link.id)) _fail('duplicate_link', 'Duplicate link: ${link.id}');
      final ElectricalNetwork? input = byId[link.inputNetworkId], output = byId[link.outputNetworkId];
      if (input == null || output == null) _fail('dangling_link', 'Converter link ${link.id} names an absent network.');
      if (input.id == output.id || input.circuit.mode != ElectricalMode.pv || output.circuit.mode != ElectricalMode.ac1) {
        _fail('wrong_mode', 'The modeled PV inverter boundary requires a PV input network and an AC1 output network.');
      }
      _component(input.circuit, link.converterComponentId, 'pv_inverter', link.id);
      final Terminal? line = _terminal(output.circuit, link.outputLineTerminalId);
      final Terminal? neutral = _terminal(output.circuit, link.outputNeutralTerminalId);
      if (line == null || neutral == null || line.id == neutral.id ||
          line.role != TerminalRole.line || neutral.role != TerminalRole.neutral) {
        _fail('invalid_converter_endpoint', 'Converter link ${link.id} must name distinct AC line and neutral terminals in its AC1 output network.');
      }
      if (!usedDevices.add('${link.inputNetworkId}/${link.converterComponentId}')) _fail('duplicate_endpoint', 'PV inverter is linked more than once.');
      if (!usedDevices.add('converter-output:${link.outputNetworkId}')) _fail('duplicate_endpoint', 'An AC1 output network can have only one cross-network PV converter boundary.');
      if (!usedDevices.add('${link.outputNetworkId}/${link.outputLineTerminalId}') ||
          !usedDevices.add('${link.outputNetworkId}/${link.outputNeutralTerminalId}')) {
        _fail('duplicate_endpoint', 'Converter output terminals are already used by another project link.');
      }
    }
  }

  static final RegExp _qAddress = RegExp(r'^Q[0-3]$');
  static final RegExp _iAddress = RegExp(r'^I[0-3]$');
  static ComponentInstance _component(CircuitState circuit, String id, String model, String link) {
    final ComponentInstance component = _componentAny(circuit, id, link);
    if (component.modelType != model) _fail('wrong_component', 'Link $link expected $model but found ${component.modelType}.');
    return component;
  }
  static ComponentInstance _componentAny(CircuitState circuit, String id, String link) {
    for (final ComponentInstance component in circuit.components) {
      if (component.id.value == id) return component;
    }
    _fail('dangling_component', 'Link $link references missing component $id.');
  }
  static Terminal? _terminal(CircuitState circuit, String id) {
    for (final ComponentInstance component in circuit.components) {
      for (final Terminal terminal in component.terminals) {
        if (terminal.id.value == id) return terminal;
      }
    }
    for (final SourceInstance source in circuit.sources) {
      for (final Terminal terminal in source.terminals) {
        if (terminal.id.value == id) return terminal;
      }
    }
    return null;
  }
  static Never _fail(String code, String message) => throw ElectricalProjectException(code, message);
}

String _string(Map<String, dynamic> map, String key) {
  final Object? v = map[key];
  if (v is String) return v;
  throw ElectricalProjectException('invalid_json', 'Expected string $key.');
}
Map<String, dynamic> _map(Map<String, dynamic> map, String key) {
  final Object? v = map[key];
  if (v is Map<String, dynamic>) return v;
  throw ElectricalProjectException('invalid_json', 'Expected object $key.');
}
List<Object?> _list(Map<String, dynamic> map, String key) {
  final Object? v = map[key];
  if (v is List<Object?>) return v;
  throw ElectricalProjectException('invalid_json', 'Expected list $key.');
}
List<Object?> _optionalList(Map<String, dynamic> map, String key) {
  final Object? value = map[key];
  if (value == null) return const <Object?>[];
  if (value is List<Object?>) return value;
  throw ElectricalProjectException('invalid_json', 'Expected list $key.');
}
