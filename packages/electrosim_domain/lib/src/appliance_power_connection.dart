import 'circuit_state.dart';
import 'component.dart';
import 'connection.dart';
import 'electrical_types.dart';
import 'ids.dart';
import 'terminal.dart';

/// Physical connections are real graph edges, never implicit voltage sources.
/// Legacy circuits remain fixed-wired until the author explicitly changes them.
abstract final class AppliancePowerConnection {
  static CircuitState addProtectiveEarth(CircuitState circuit) {
    var changed = false;
    final usedTerminalIds = {
      ...circuit.components.expand((c) => c.terminals).map((t) => t.id),
      ...circuit.sources.expand((c) => c.terminals).map((t) => t.id),
    };
    final components = circuit.components.map((c) {
      if (!isExternal(c) ||
          isDc(c) ||
          (c.terminals.length != 2 && c.terminals.length != 6) ||
          (c.parameters['protectionClass'] == 'II' ||
              c.parameters['protectionClass'] == 'III' ||
              (c.parameters['_visualVariant'] == 'television' &&
                  c.parameters['protectionClass'] != 'I')) ||
          !const {'resistor', 'impedance', 'motor_3p_6t'}.contains(c.modelType))
        return c;
      final baseEarthId = '${c.id.value}:chassis-pe';
      var earthId = TerminalId(baseEarthId);
      var serial = 2;
      while (!usedTerminalIds.add(earthId)) {
        earthId = TerminalId('$baseEarthId:${serial++}');
      }
      changed = true;
      return ComponentInstance(
        id: c.id,
        modelType: c.modelType == 'motor_3p_6t'
            ? 'earthed_machine_3p_7t'
            : c.modelType == 'resistor'
            ? 'earthed_resistor'
            : 'earthed_impedance',
        terminals: [
          ...c.terminals,
          Terminal(id: earthId, name: 'PE', role: TerminalRole.protectiveEarth),
        ],
        parameters: {
          ...c.parameters,
          'originalElectricalModelType': c.modelType,
          'protectionClass': 'I',
        },
        condition: c.condition,
        controlState: {...c.controlState, 'chassisEarthModeled': true},
      );
    }).toList();
    if (!changed) return circuit;
    final data = circuit.toJson();
    data['components'] = components.map((c) => c.toJson()).toList();
    data['revision'] = circuit.revision + 1;
    return CircuitState.fromJson(data);
  }

  /// Runtime-only insulation resistance; the authored component keeps its IDs.
  static CircuitState projectInsulationFaults(CircuitState circuit) {
    final components = [...circuit.components];
    final wires = [...circuit.connections];
    for (final c in circuit.components) {
      if (!const {
            'earthed_resistor',
            'earthed_impedance',
            'earthed_machine_3p_7t',
          }.contains(c.modelType) ||
          c.controlState['insulationFault'] != true)
        continue;
      final value = c.parameters['insulationFaultResistanceOhm'] ?? 1000.0;
      if (value is! num || !value.isFinite || value <= 0) {
        throw ArgumentError(
          'La résistance de défaut doit être finie et strictement positive.',
        );
      }
      final key = 'earth-fault:${c.id.value}';
      final id = ComponentId(key);
      if (components.any((x) => x.id == id))
        throw ArgumentError('Identifiant de défaut réservé déjà utilisé.');
      final a = TerminalId('$key:line');
      final b = TerminalId('$key:chassis');
      components.add(
        ComponentInstance(
          id: id,
          modelType: 'resistor',
          terminals: [
            Terminal(id: a, name: 'L'),
            Terminal(id: b, name: 'PE'),
          ],
          parameters: {'resistanceOhm': value.toDouble()},
        ),
      );
      wires.addAll([
        Connection(
          id: ConnectionId('$key:line-link'),
          fromTerminalId: c.terminals[0].id,
          toTerminalId: a,
        ),
        Connection(
          id: ConnectionId('$key:earth-link'),
          fromTerminalId: c.terminals.last.id,
          toTerminalId: b,
        ),
      ]);
    }
    if (components.length == circuit.components.length) return circuit;
    final data = circuit.toJson();
    data['components'] = components.map((c) => c.toJson()).toList();
    data['connections'] = wires.map((w) => w.toJson()).toList();
    return CircuitState.fromJson(data);
  }

  static CircuitState setInsulationFault(
    CircuitState circuit,
    String id,
    bool active,
  ) {
    final data = circuit.toJson();
    data['revision'] = circuit.revision + 1;
    data['components'] = circuit.components.map((c) {
      final json = c.toJson();
      if (c.id.value == id) {
        if (!const {
          'earthed_resistor',
          'earthed_impedance',
          'earthed_machine_3p_7t',
        }.contains(c.modelType)) {
          throw ArgumentError('Cet appareil ne modélise pas de châssis PE.');
        }
        json['controlState'] = {...c.controlState, 'insulationFault': active};
      }
      return json;
    }).toList();
    return CircuitState.fromJson(data);
  }

  static const cableTag = 'appliancePowerCable';
  static bool isExternal(ComponentInstance c) => const {
    'catalog_appliance_2t',
    'catalog_motor_driven_2t',
    'catalog_motor_driven_6t',
    'catalog_heater',
  }.contains(c.parameters['_visualModelType']);

  static bool isDc(ComponentInstance c) =>
      c.parameters['_visualVariant'] == 'refrigerator-dc' ||
      c.parameters['_visualVariant'] == 'solar-pump' ||
      c.modelType == 'motor_dc';

  static bool canPlug(ComponentInstance c) =>
      isExternal(c) &&
      (c.terminals.length == 2 ||
          (c.terminals.length == 3 &&
              c.terminals.last.role == TerminalRole.protectiveEarth));

  static String defaultMode(ComponentInstance c) {
    if (isDc(c)) return 'dc';
    if (const {
      'computer',
      'television',
      'iron',
      'freezer',
      'refrigerator',
    }.contains(c.parameters['_visualVariant']))
      return 'plug';
    return 'fixed';
  }

  static String mode(ComponentInstance c) =>
      c.parameters['powerConnectionMode'] as String? ?? 'fixed';

  static List<ComponentInstance> compatibleSockets(
    CircuitState circuit,
    ComponentInstance c,
  ) => circuit.components
      .where(
        (s) => s.modelType == (isDc(c) ? 'power_socket_dc' : 'power_socket_ac'),
      )
      .toList(growable: false);

  static CircuitState configure(
    CircuitState circuit,
    String applianceId,
    String mode, {
    String? socketId,
  }) {
    final appliance = circuit.components.firstWhere(
      (c) => c.id.value == applianceId,
    );
    if (!isExternal(appliance))
      throw ArgumentError('Les moteurs seuls conservent leur bornier.');
    if (!const {'fixed', 'plug', 'dc'}.contains(mode))
      throw ArgumentError('Raccordement inconnu.');
    if (mode != 'fixed' &&
        (!canPlug(appliance) || (mode == 'dc') != isDc(appliance))) {
      throw ArgumentError(
        'Connecteur incompatible : conserver le bornier de cet équipement.',
      );
    }
    final ids = appliance.terminals.map((t) => t.id).toSet();
    bool ownCable(Connection wire) => wire.metadata[cableTag] == applianceId;
    if (mode != 'fixed' &&
        circuit.connections.any(
          (w) =>
              !ownCable(w) &&
              (ids.contains(w.fromTerminalId) || ids.contains(w.toTerminalId)),
        )) {
      throw ArgumentError(
        'Retirer les fils du raccordement fixe avant de choisir une fiche.',
      );
    }
    final wires = circuit.connections.where((w) => !ownCable(w)).toList();
    if (socketId != null) {
      if (mode == 'fixed')
        throw ArgumentError('Un raccordement fixe ne reçoit pas de fiche.');
      final socket = compatibleSockets(circuit, appliance).firstWhere(
        (s) => s.id.value == socketId,
        orElse: () =>
            throw ArgumentError('Prise absente ou incompatible AC/DC.'),
      );
      if (wires.any((w) => w.metadata['powerSocketId'] == socketId)) {
        throw ArgumentError('Cette prise est déjà occupée.');
      }
      final poleCount = socket.terminals.length ~/ 2;
      for (var pole = 0; pole < appliance.terminals.length; pole++) {
        final id = ConnectionId('power-cable:$applianceId:$pole');
        if (wires.any((w) => w.id == id))
          throw ArgumentError('Identifiant de câble déjà utilisé.');
        wires.add(
          Connection(
            id: id,
            fromTerminalId: socket.terminals[poleCount + pole].id,
            toTerminalId: appliance.terminals[pole].id,
            phase: socket.terminals[poleCount + pole].phase,
            metadata: {cableTag: applianceId, 'powerSocketId': socketId},
          ),
        );
      }
    }
    final json = circuit.toJson();
    json['revision'] = circuit.revision + 1;
    json['connections'] = wires.map((w) => w.toJson()).toList();
    json['components'] = circuit.components.map((c) {
      final data = c.toJson();
      if (c.id.value == applianceId) {
        data['parameters'] = {...c.parameters, 'powerConnectionMode': mode};
        data['controlState'] = {
          ...c.controlState, 'powerSocketId': socketId,
          // Existing two-terminal loads have no modeled chassis-earth contact.
          'chassisEarthModeled': appliance.terminals.any(
            (t) => t.role == TerminalRole.protectiveEarth,
          ),
        };
      }
      return data;
    }).toList();
    return CircuitState.fromJson(json);
  }
}
