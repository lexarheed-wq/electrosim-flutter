import 'dart:convert';

import 'package:electrosim_domain/electrosim_domain.dart';

/// Document references live in metadata, never in electrical IDs or topology.
enum IndustrialMarkingKind { device, conductor, terminal }
enum IndustrialConductorColor {
  unspecified, brown, black, grey, blue, greenYellow, red,
}

final class IndustrialMarkingIssue {
  const IndustrialMarkingIssue(this.id, this.message);
  final String id;
  final String message;
}

final class IndustrialMarkingRegistry {
  IndustrialMarkingRegistry._(
    this.devices, this.conductors, this.terminals,
    this.colors, this.locks, this.issues,
  );

  static const metadataKey = 'industrialMarkingV1';
  final Map<String, String> devices;
  final Map<String, String> conductors;
  final Map<String, String> terminals;
  final Map<String, IndustrialConductorColor> colors;
  final Map<String, bool> locks;
  final List<IndustrialMarkingIssue> issues;

  static String _group(IndustrialMarkingKind kind) => kind.name + 's';
  static String _id(IndustrialMarkingKind kind, String id) =>
      kind.name + ':' + id;

  static Map<String, Object?> _map(Object? value) {
    if (value is! Map) return <String, Object?>{};
    return <String, Object?>{
      for (final entry in value.entries)
        if (entry.key is String) entry.key as String: entry.value,
    };
  }

  static Map<String, Object?> _data(
    CircuitState circuit, IndustrialMarkingKind kind,
  ) => _map(_map(circuit.metadata[metadataKey])[_group(kind)]);

  static String? _reference(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static String _prefix(String model) {
    final type = model.toLowerCase();
    if (type.startsWith('contactor_')) return 'KM';
    if (type.startsWith('relay_')) return 'KA';
    if (type.startsWith('push_button') || type.contains('switch') ||
        type.contains('selector')) return 'S';
    if (type.contains('breaker') || type.contains('disconnector')) return 'Q';
    if (type.contains('fuse') || type.contains('overload')) return 'F';
    if (type.contains('motor')) return 'M';
    if (type.contains('lamp') || type.contains('indicator') ||
        type.contains('buzzer') || type.contains('horn')) return 'H';
    if (type.contains('terminal') || type.contains('bornier')) return 'X';
    if (type.contains('source') || type.contains('battery') ||
        type.contains('generator')) return 'G';
    if (type.contains('transformer')) return 'T';
    if (type.contains('resistor')) return 'R';
    if (type.contains('capacitor')) return 'C';
    if (type.contains('diode')) return 'V';
    return 'A';
  }

  static IndustrialConductorColor _color(PhaseTag phase) => switch (phase) {
    PhaseTag.l1 => IndustrialConductorColor.brown,
    PhaseTag.l2 => IndustrialConductorColor.black,
    PhaseTag.l3 => IndustrialConductorColor.grey,
    PhaseTag.neutral => IndustrialConductorColor.blue,
    PhaseTag.protectiveEarth => IndustrialConductorColor.greenYellow,
    PhaseTag.dcPositive => IndustrialConductorColor.red,
    PhaseTag.dcNegative => IndustrialConductorColor.black,
    PhaseTag.none => IndustrialConductorColor.unspecified,
  };

  String referenceOf(IndustrialMarkingKind kind, String id) =>
      switch (kind) {
        IndustrialMarkingKind.device => devices[id] ?? id,
        IndustrialMarkingKind.conductor => conductors[id] ?? id,
        IndustrialMarkingKind.terminal => terminals[id] ?? id,
      };

  /// Pure deterministic projection. The first materialization freezes
  /// allocated numbers for later circuit edits and additions.
  static IndustrialMarkingRegistry inspect(CircuitState circuit) {
    final deviceData = _data(circuit, IndustrialMarkingKind.device);
    final wireData = _data(circuit, IndustrialMarkingKind.conductor);
    final terminalData = _data(circuit, IndustrialMarkingKind.terminal);
    final list = <({String id, String type, Map<String, Object?> params,
        List<Terminal> terminals})>[
      for (final item in circuit.sources)
        (id: item.id.value, type: item.modelType,
         params: item.parameters, terminals: item.terminals),
      for (final item in circuit.components)
        (id: item.id.value, type: item.modelType,
         params: item.parameters, terminals: item.terminals),
    ]..sort((a, b) => a.id.compareTo(b.id));

    final devices = <String, String>{};
    final conductors = <String, String>{};
    final terminals = <String, String>{};
    final colors = <String, IndustrialConductorColor>{};
    final locks = <String, bool>{};
    final issues = <IndustrialMarkingIssue>[];
    final used = <String, String>{};
    final reserved = <String>{
      for (final value in deviceData.values)
        if (_reference(_map(value)['reference']) case final String ref)
          ref.toUpperCase(),
    };

    void put(String id, String label) {
      final owner = used.putIfAbsent(label.toUpperCase(), () => id);
      if (owner != id) {
        issues.add(IndustrialMarkingIssue(
          id, 'Duplicate reference ' + label + ' belongs to ' + owner,
        ));
      }
      devices[id] = label;
    }

    for (final item in list) {
      final stored = _map(deviceData[item.id]);
      final explicit = _reference(item.params['industrialReference']);
      final manual = stored['manual'] == true || explicit != null;
      final auxiliary = item.type.startsWith('contactor_aux_') ||
          item.type.startsWith('relay_contact_');
      final old = _reference(stored['reference']);
      if (old != null && (!auxiliary || manual)) {
        put(item.id, old);
      } else if (explicit != null) {
        put(item.id, explicit);
      }
      locks[_id(IndustrialMarkingKind.device, item.id)] =
          stored['locked'] == true;
    }

    final counter = <String, int>{};
    void assign(({String id, String type, Map<String, Object?> params,
        List<Terminal> terminals}) item) {
      if (devices.containsKey(item.id)) return;
      final family = _prefix(item.type);
      var n = counter[family] ?? 1;
      while (reserved.contains((family + n.toString()).toUpperCase()) ||
          used.containsKey((family + n.toString()).toUpperCase())) {
        n++;
      }
      put(item.id, family + n.toString());
      counter[family] = n + 1;
    }

    for (final item in list) {
      if (!item.type.startsWith('contactor_aux_') &&
          !item.type.startsWith('relay_contact_')) assign(item);
    }
    for (final item in list) {
      final aux = item.type.startsWith('contactor_aux_') ||
          item.type.startsWith('relay_contact_');
      if (!aux || devices.containsKey(item.id)) continue;
      final link = item.params['linkedRelayId'] ??
          item.params['linkedContactorId'];
      if (link is String && devices.containsKey(link)) {
        final portNames = item.terminals.map((e) => e.name).join('-');
        final candidate = devices[link]! + ':' + portNames;
        var label = candidate;
        var n = 2;
        while (reserved.contains(label.toUpperCase()) ||
            used.containsKey(label.toUpperCase())) {
          label = candidate + '-' + n.toString();
          n++;
        }
        put(item.id, label);
      } else {
        if (link is String) {
          issues.add(IndustrialMarkingIssue(
            item.id, 'Unknown controlling coil: ' + link,
          ));
        }
        assign(item);
      }
    }

    final reservedWires = <String>{
      for (final value in wireData.values)
        if (_reference(_map(value)['reference']) case final String ref)
          ref.toUpperCase(),
    };
    final usedWires = <String, String>{};
    var next = 1;
    final wires = [...circuit.connections]
      ..sort((a, b) => a.id.value.compareTo(b.id.value));
    for (final wire in wires) {
      final id = wire.id.value;
      final stored = _map(wireData[id]);
      var label = _reference(stored['reference']) ??
          _reference(wire.metadata['industrialReference']);
      if (label == null) {
        while (reservedWires.contains(next.toString().padLeft(3, '0')) ||
            usedWires.containsKey(next.toString().padLeft(3, '0'))) {
          next++;
        }
        label = next.toString().padLeft(3, '0');
        next++;
      }
      conductors[id] = label;
      final owner = usedWires.putIfAbsent(label.toUpperCase(), () => id);
      if (owner != id) {
        issues.add(IndustrialMarkingIssue(
          id, 'Duplicate conductor ' + label + ' belongs to ' + owner,
        ));
      }
      locks[_id(IndustrialMarkingKind.conductor, id)] =
          stored['locked'] == true;
      // A hint exists only for a phase explicitly tagged on the wire.
      colors[id] = _color(wire.phase);
    }

    for (final item in list) {
      for (final port in item.terminals) {
        final id = port.id.value;
        final stored = _map(terminalData[id]);
        final explicit = _reference(port.metadata['industrialReference']);
        final manuallyAssigned = stored['manual'] == true || explicit != null;
        // Automatic terminal labels track a deliberate device rename.
        // Teacher-edited terminal labels remain fixed.
        terminals[id] = (manuallyAssigned
                ? _reference(stored['reference']) ?? explicit
                : null) ??
            devices[item.id]! + ':' + port.name;
        locks[_id(IndustrialMarkingKind.terminal, id)] =
            stored['locked'] == true;
      }
    }
    return IndustrialMarkingRegistry._(
      Map.unmodifiable(devices), Map.unmodifiable(conductors),
      Map.unmodifiable(terminals), Map.unmodifiable(colors),
      Map.unmodifiable(locks), List.unmodifiable(issues),
    );
  }

  /// Persist labels in a document-only metadata namespace.
  static CircuitState materialize(CircuitState circuit) {
    final plan = inspect(circuit);
    final metadata = <String, Object?>{...circuit.metadata};
    final old = _map(metadata[metadataKey]);
    final result = <String, Object?>{...old};
    for (final kind in IndustrialMarkingKind.values) {
      final oldData = _data(circuit, kind);
      final labels = switch (kind) {
        IndustrialMarkingKind.device => plan.devices,
        IndustrialMarkingKind.conductor => plan.conductors,
        IndustrialMarkingKind.terminal => plan.terminals,
      };
      final updated = <String, Object?>{...oldData};
      for (final ref in labels.entries) {
        final existing = _map(updated[ref.key]);
        updated[ref.key] = <String, Object?>{
          'reference': ref.value,
          'locked': plan.locks[_id(kind, ref.key)]!,
          'manual': existing['manual'] == true,
        };
      }
      result[_group(kind)] = updated;
    }
    metadata[metadataKey] = result;
    if (jsonEncode(metadata) == jsonEncode(circuit.metadata)) return circuit;
    return _copy(circuit, metadata);
  }

  static CircuitState setReference(
    CircuitState circuit, {
    required IndustrialMarkingKind kind,
    required String id,
    required String reference,
    required bool teacherAuthorized,
    bool? locked,
  }) {
    if (!teacherAuthorized) throw StateError('Teacher authorization required');
    final value = reference.trim();
    if (value.isEmpty || value.length > 64) {
      throw ArgumentError.value(reference, 'reference', 'Invalid length');
    }
    final base = materialize(circuit);
    final plan = inspect(base);
    final known = switch (kind) {
      IndustrialMarkingKind.device => plan.devices.containsKey(id),
      IndustrialMarkingKind.conductor => plan.conductors.containsKey(id),
      IndustrialMarkingKind.terminal => plan.terminals.containsKey(id),
    };
    if (!known) throw ArgumentError.value(id, 'id', 'Unknown marking target');
    final metadata = <String, Object?>{...base.metadata};
    final updated = _map(metadata[metadataKey]);
    final records = _data(base, kind);
    final before = _map(records[id]);
    records[id] = <String, Object?>{
      'reference': value, 'manual': true,
      'locked': locked ?? (before['locked'] == true),
    };
    updated[_group(kind)] = records;
    metadata[metadataKey] = updated;
    if (jsonEncode(metadata) == jsonEncode(base.metadata)) return base;
    return _copy(base, metadata);
  }

  static CircuitState setLock(
    CircuitState circuit, {
    required IndustrialMarkingKind kind,
    required String id,
    required bool locked,
    required bool teacherAuthorized,
  }) {
    if (!teacherAuthorized) throw StateError('Teacher authorization required');
    return setReference(
      circuit, kind: kind, id: id,
      reference: inspect(circuit).referenceOf(kind, id),
      teacherAuthorized: true, locked: locked,
    );
  }

  static CircuitState _copy(
    CircuitState source, Map<String, Object?> metadata,
  ) => CircuitState(
    circuitId: source.circuitId, revision: source.revision + 1,
    mode: source.mode, components: source.components,
    connections: source.connections, sources: source.sources,
    instruments: source.instruments, probes: source.probes,
    settings: source.settings, metadata: metadata,
  );
}
