import 'package:electrosim_controls/electrosim_controls.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';

import 'electrosim_runtime_engine.dart';

/// Runtime state for a complete two-network electrical project.
final class ElectricalProjectRuntimeSnapshot {
  ElectricalProjectRuntimeSnapshot({
    required Map<String, ElectroSimRuntimeSnapshot> networks,
    required Map<String, bool> relayBridgeStates,
    required Map<String, bool> feedbackSignalStates,
    required Map<String, Map<String, LadderRuntimeState>> ladderStates,
    required this.elapsed,
    Iterable<String> diagnostics = const <String>[],
  }) : networks = Map<String, ElectroSimRuntimeSnapshot>.unmodifiable(networks),
       relayBridgeStates = Map<String, bool>.unmodifiable(relayBridgeStates),
       feedbackSignalStates = Map<String, bool>.unmodifiable(
         feedbackSignalStates,
       ),
       ladderStates = Map<String, Map<String, LadderRuntimeState>>.unmodifiable(
         ladderStates.map(
           (String id, Map<String, LadderRuntimeState> states) =>
               MapEntry<String, Map<String, LadderRuntimeState>>(
                 id,
                 Map<String, LadderRuntimeState>.unmodifiable(states),
               ),
         ),
       ),
       diagnostics = List<String>.unmodifiable(diagnostics);
  final Map<String, ElectroSimRuntimeSnapshot> networks;
  final Map<String, bool> relayBridgeStates;
  final Map<String, bool> feedbackSignalStates;
  final Map<String, Map<String, LadderRuntimeState>> ladderStates;
  final Duration elapsed;
  final List<String> diagnostics;
}

/// Coordinates separate homogeneous solvers and the explicitly typed links.
final class ElectricalProjectRuntimeEngine {
  const ElectricalProjectRuntimeEngine({
    this.networkEngine = const ElectroSimRuntimeEngine(),
    this.ladderEngine = const LadderProgramEngine(),
  });
  final ElectroSimRuntimeEngine networkEngine;
  final LadderProgramEngine ladderEngine;

  ElectricalProjectRuntimeSnapshot advance(
    ElectricalProject project, {
    required Duration elapsed,
    ElectricalProjectRuntimeSnapshot? previous,
  }) {
    if (elapsed.isNegative) throw ArgumentError.value(elapsed, 'elapsed');
    final List<String> diagnostics = <String>[];
    final Map<String, LadderRuntimeState> ladder = <String, LadderRuntimeState>{
      for (final MapEntry<String, Map<String, LadderRuntimeState>> entry
          in (previous?.ladderStates ??
                  const <String, Map<String, LadderRuntimeState>>{})
              .entries)
        ...entry.value.map(
          (String id, LadderRuntimeState state) =>
              MapEntry<String, LadderRuntimeState>('${entry.key}/$id', state),
        ),
    };
    final ElectricalNetwork? dcNetwork = project.networks
        .where((ElectricalNetwork n) => n.circuit.mode == ElectricalMode.dc)
        .firstOrNull;
    final ElectricalNetwork? acNetwork = project.networks
        .where((ElectricalNetwork n) => n.circuit.mode == ElectricalMode.ac3)
        .firstOrNull;
    if (dcNetwork == null || acNetwork == null) {
      final Map<String, ElectroSimRuntimeSnapshot> single =
          <String, ElectroSimRuntimeSnapshot>{
            for (final ElectricalNetwork n in project.networks)
              n.id: networkEngine.advance(
                n.circuit,
                elapsed: elapsed,
                previousContactorStates:
                    previous?.networks[n.id]?.contactorStates.map(
                      (ComponentId id, ContactorActuationState s) =>
                          MapEntry<ComponentId, bool>(id, s.actuated),
                    ) ??
                    const <ComponentId, bool>{},
              ),
          };
      return ElectricalProjectRuntimeSnapshot(
        networks: single,
        relayBridgeStates: const <String, bool>{},
        feedbackSignalStates: const <String, bool>{},
        ladderStates: const {},
        elapsed: (previous?.elapsed ?? Duration.zero) + elapsed,
        diagnostics: const <String>[
          'Composite runtime requires one DC and one AC3 network.',
        ],
      );
    }

    // Solve DC once with the previous PLC Q state. This is the only solve in
    // the tick that advances physical time.
    final CircuitState dcBefore = _projectPlcState(
      dcNetwork.id,
      dcNetwork.circuit,
      ladder,
      supplyValid: true,
    );
    final ElectroSimRuntimeSnapshot dcFirst = networkEngine.advance(
      dcBefore,
      elapsed: elapsed,
      previousContactorStates: _previousActuators(
        previous?.networks[dcNetwork.id],
      ),
    );
    final Set<String> isolatedInputs = project.signalLinks
        .where((CrossNetworkSignalLink l) => l.dcNetworkId == dcNetwork.id)
        .map((CrossNetworkSignalLink l) => l.inputAddress)
        .toSet();
    final Map<String, bool> inputs = _readInputs(
      dcNetwork.circuit,
      dcFirst,
      diagnostics,
      isolatedInputs: isolatedInputs,
    );
    for (final CrossNetworkSignalLink link in project.signalLinks) {
      if (link.dcNetworkId == dcNetwork.id) {
        inputs[link.inputAddress] =
            previous?.feedbackSignalStates[link.id] ?? false;
      }
    }

    bool supplyValid = true;
    final Map<String, bool> plcSupply = <String, bool>{};
    final Map<String, double> plcSupplyVoltages = <String, double>{};
    final Map<String, bool> plcProgramErrors = <String, bool>{};
    final Map<String, Map<String, bool>> plcInputs =
        <String, Map<String, bool>>{};
    for (final ComponentInstance plc in dcNetwork.circuit.components.where(
      (ComponentInstance c) => c.modelType == 'plc_dc',
    )) {
      final double? voltage = _terminalVoltage(
        dcFirst,
        plc.terminals[0].id,
        plc.terminals[1].id,
      );
      final bool valid =
          voltage != null &&
          voltage >= 20.4 &&
          voltage <= 28.8 &&
          plc.condition == ComponentCondition.normal;
      plcSupply[plc.id.value] = valid;
      if (voltage != null) plcSupplyVoltages[plc.id.value] = voltage;
      supplyValid = supplyValid && valid;
      if (!valid) {
        diagnostics.add(
          'PLC ${plc.id.value}: alimentation 24 V absente ou hors plage.',
        );
      }
      final Object? rawProgram = plc.parameters['ladderProgram'];
      final List<Map<String, Object?>> program = _program(rawProgram);
      final String key = '${dcNetwork.id}/${plc.id.value}';
      plcInputs[plc.id.value] = <String, bool>{
        for (int i = 0; i < 4; i++) 'I$i': inputs['I$i'] ?? false,
      };
      final LadderScanResult scan = ladderEngine.scan(
        program: program,
        inputs: valid ? inputs : const <String, bool>{},
        previous: ladder[key] ?? LadderRuntimeState(),
        elapsed: elapsed,
      );
      ladder[key] = scan.state;
      plcProgramErrors[plc.id.value] = scan.programError;
      if (scan.programError) {
        diagnostics.add(
          'PLC ${plc.id.value}: programme Ladder invalide; sorties désactivées.',
        );
      }
      if (!valid) {
        ladder[key] = LadderRuntimeState(
          outputs: const <String, bool>{},
          memories: scan.state.memories,
          timerSeconds: scan.state.timerSeconds,
          timerDone: scan.state.timerDone,
        );
      }
    }

    // Corrective solve applies the newly scanned Q outputs at zero elapsed.
    final CircuitState dcAfter = _projectPlcState(
      dcNetwork.id,
      dcNetwork.circuit,
      ladder,
      supplyValid: supplyValid,
      perPlcSupply: plcSupply,
      perPlcVoltage: plcSupplyVoltages,
      perPlcInputs: plcInputs,
      perPlcProgramError: plcProgramErrors,
    );
    final ElectroSimRuntimeSnapshot dcFinal = networkEngine.advance(
      dcAfter,
      elapsed: Duration.zero,
      previousContactorStates: _previousActuators(dcFirst),
      previousComponentHealthStates: dcFirst.componentHealthStates,
    );

    final Map<String, bool> relayStates = <String, bool>{};
    final Map<String, bool> relayByCoil = <String, bool>{};
    for (final CrossNetworkRelayLink link in project.relayLinks) {
      final ComponentId coilId = ComponentId(link.relayCoilId);
      final bool actuated = dcFinal.contactorStates[coilId]?.actuated ?? false;
      relayStates[link.id] = actuated;
      relayByCoil[link.relayCoilId] = actuated;
      if (dcFinal.contactorStates[coilId] == null) {
        diagnostics.add(
          'Liaison ${link.id}: état de bobine relais DC indisponible.',
        );
      }
    }

    final CircuitState acProjected = _projectAcRelayContacts(
      acNetwork.circuit,
      project,
      relayByCoil,
    );
    final ElectroSimRuntimeSnapshot acFinal = networkEngine.advance(
      acProjected,
      elapsed: elapsed,
      previousContactorStates: _previousActuators(
        previous?.networks[acNetwork.id],
      ),
    );
    final Map<String, bool> feedback = <String, bool>{};
    for (final CrossNetworkSignalLink link in project.signalLinks) {
      final ComponentInstance? contact = acFinal.effectiveCircuit.components
          .where((ComponentInstance c) => c.id.value == link.auxiliaryContactId)
          .firstOrNull;
      final bool actuated = contact?.controlState['actuated'] == true;
      feedback[link.id] = contact?.modelType.endsWith('_nc') == true
          ? !actuated
          : actuated;
    }
    return ElectricalProjectRuntimeSnapshot(
      networks: <String, ElectroSimRuntimeSnapshot>{
        dcNetwork.id: dcFinal,
        acNetwork.id: acFinal,
      },
      relayBridgeStates: relayStates,
      feedbackSignalStates: feedback,
      ladderStates: <String, Map<String, LadderRuntimeState>>{
        dcNetwork.id: <String, LadderRuntimeState>{
          for (final MapEntry<String, LadderRuntimeState> e in ladder.entries)
            if (e.key.startsWith('${dcNetwork.id}/'))
              e.key.substring(dcNetwork.id.length + 1): e.value,
        },
      },
      elapsed: (previous?.elapsed ?? Duration.zero) + elapsed,
      diagnostics: diagnostics,
    );
  }

  static Map<ComponentId, bool> _previousActuators(
    ElectroSimRuntimeSnapshot? snapshot,
  ) =>
      snapshot?.contactorStates.map(
        (ComponentId id, ContactorActuationState state) =>
            MapEntry<ComponentId, bool>(id, state.actuated),
      ) ??
      const <ComponentId, bool>{};

  static List<Map<String, Object?>> _program(Object? raw) {
    if (raw is! List) {
      return const <Map<String, Object?>>[
        <String, Object?>{'steps': <Object?>[]},
      ];
    }
    try {
      return raw
          .map(
            (Object? row) => row is Map
                ? Map<String, Object?>.from(row)
                : <String, Object?>{'steps': <Object?>[]},
          )
          .toList(growable: false);
    } on Object {
      return const <Map<String, Object?>>[
        <String, Object?>{'steps': <Object?>[]},
      ];
    }
  }

  static CircuitState _projectPlcState(
    String networkId,
    CircuitState circuit,
    Map<String, LadderRuntimeState> ladder, {
    required bool supplyValid,
    Map<String, bool> perPlcSupply = const <String, bool>{},
    Map<String, double> perPlcVoltage = const <String, double>{},
    Map<String, Map<String, bool>> perPlcInputs =
        const <String, Map<String, bool>>{},
    Map<String, bool> perPlcProgramError = const <String, bool>{},
  }) => CircuitState(
    circuitId: circuit.circuitId,
    revision: circuit.revision,
    mode: circuit.mode,
    components: circuit.components
        .map((ComponentInstance component) {
          if (component.modelType != 'plc_dc') return component;
          final LadderRuntimeState state =
              ladder['$networkId/${component.id.value}'] ??
              LadderRuntimeState();
          final bool valid = perPlcSupply[component.id.value] ?? supplyValid;
          return ComponentInstance(
            id: component.id,
            modelType: component.modelType,
            terminals: component.terminals,
            parameters: component.parameters,
            condition: component.condition,
            controlState: <String, Object?>{
              ...component.controlState,
              for (int i = 0; i < 4; i++)
                'I$i': perPlcInputs[component.id.value]?['I$i'] ?? false,
              for (int i = 0; i < 4; i++)
                'Q$i': valid && state.outputs['Q$i'] == true,
              'plcSupplyValid': valid,
              'supplyValid': valid,
              'supplyVoltageV': perPlcVoltage[component.id.value] ?? 0.0,
              'programError': perPlcProgramError[component.id.value] ?? false,
            },
          );
        })
        .toList(growable: false),
    connections: circuit.connections,
    sources: circuit.sources,
    instruments: circuit.instruments,
    probes: circuit.probes,
    settings: circuit.settings,
    metadata: circuit.metadata,
  );

  static CircuitState _projectAcRelayContacts(
    CircuitState circuit,
    ElectricalProject project,
    Map<String, bool> states,
  ) => CircuitState(
    circuitId: circuit.circuitId,
    revision: circuit.revision,
    mode: circuit.mode,
    components: circuit.components
        .map((ComponentInstance component) {
          final CrossNetworkRelayLink? link = project.relayLinks
              .where(
                (CrossNetworkRelayLink l) =>
                    l.ac3ContactId == component.id.value,
              )
              .firstOrNull;
          if (link == null) return component;
          final bool relay = states[link.relayCoilId] ?? false;
          return ComponentInstance(
            id: component.id,
            modelType: component.modelType,
            terminals: component.terminals,
            parameters: component.parameters,
            condition: component.condition,
            controlState: <String, Object?>{
              ...component.controlState,
              'actuated': relay,
              'externalLinkResolved': true,
            },
          );
        })
        .toList(growable: false),
    connections: circuit.connections,
    sources: circuit.sources,
    instruments: circuit.instruments,
    probes: circuit.probes,
    settings: circuit.settings,
    metadata: circuit.metadata,
  );

  static Map<String, bool> _readInputs(
    CircuitState circuit,
    ElectroSimRuntimeSnapshot snapshot,
    List<String> diagnostics, {
    Set<String> isolatedInputs = const <String>{},
  }) {
    final DcSolveResult? result = snapshot.dcResult;
    if (result == null || !result.isSolved) return <String, bool>{};
    final Map<String, bool> inputs = <String, bool>{};
    for (final ComponentInstance plc in circuit.components.where(
      (ComponentInstance c) => c.modelType == 'plc_dc',
    )) {
      for (int i = 0; i < 4; i++) {
        final String address = 'I$i';
        if (isolatedInputs.contains(address)) continue;
        final TerminalId terminal = plc.terminals[2 + i].id;
        final String? node = snapshot.topology.terminalToNode[terminal];
        final double? value = node == null ? null : result.nodeVoltages[node];
        final bool floating =
            node == null ||
            result.diagnostics.any(
              (DcSolverDiagnostic d) =>
                  d.code == DcDiagnosticCode.floatingElectricalIsland &&
                  d.nodeIds.contains(node),
            );
        final double? common = _terminalVoltageToReference(
          snapshot,
          plc.terminals[1].id,
        );
        final double? relative = value == null || common == null
            ? null
            : value - common;
        if (floating || relative == null) {
          inputs[address] = false;
          diagnostics.add('PLC ${plc.id.value} $address: entrée flottante.');
        } else if (relative >= 15) {
          inputs[address] = true;
        } else if (relative <= 5) {
          inputs[address] = false;
        } else {
          inputs[address] = false;
          diagnostics.add(
            'PLC ${plc.id.value} $address: niveau d’entrée indéterminé (${relative.toStringAsFixed(1)} V).',
          );
        }
      }
    }
    return inputs;
  }

  static double? _terminalVoltage(
    ElectroSimRuntimeSnapshot snapshot,
    TerminalId a,
    TerminalId b,
  ) {
    final String? an = snapshot.topology.terminalToNode[a];
    final String? bn = snapshot.topology.terminalToNode[b];
    final double? av = an == null ? null : snapshot.dcResult?.nodeVoltages[an];
    final double? bv = bn == null ? null : snapshot.dcResult?.nodeVoltages[bn];
    return av == null || bv == null ? null : av - bv;
  }

  static double? _terminalVoltageToReference(
    ElectroSimRuntimeSnapshot snapshot,
    TerminalId terminal,
  ) {
    final String? node = snapshot.topology.terminalToNode[terminal];
    return node == null ? null : snapshot.dcResult?.nodeVoltages[node];
  }
}
