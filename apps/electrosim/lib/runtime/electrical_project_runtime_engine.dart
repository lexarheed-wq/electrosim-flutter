import 'dart:math' as math;

import 'package:electrosim_controls/electrosim_controls.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_pv/electrosim_pv.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_solver_ac/electrosim_solver_ac.dart';

import 'electrosim_runtime_engine.dart';

/// Runtime state for a project containing any set of homogeneous networks.
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

final class _ConverterCouplingResult {
  const _ConverterCouplingResult({
    required this.pvSnapshot,
    required this.acSnapshot,
    required this.converged,
  });
  final ElectroSimRuntimeSnapshot pvSnapshot;
  final ElectroSimRuntimeSnapshot acSnapshot;
  final bool converged;
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
    if (dcNetwork != null &&
        acNetwork == null &&
        project.actuatorLinks.isNotEmpty) {
      return _advanceDcActuatorNetworks(
        project,
        dcNetwork,
        elapsed,
        previous,
        ladder,
        diagnostics,
      );
    }
    if (dcNetwork == null || acNetwork == null) {
      final Set<String> converterNetworks = <String>{
        for (final CrossNetworkConverterLink link
            in project.converterLinks) ...<String>{
          link.inputNetworkId,
          link.outputNetworkId,
        },
      };
      final Map<String, ElectroSimRuntimeSnapshot> single =
          <String, ElectroSimRuntimeSnapshot>{
            for (final ElectricalNetwork n in project.networks)
              if (!converterNetworks.contains(n.id))
                n.id: _advanceIndependent(n, elapsed, previous?.networks[n.id]),
          };
      for (final CrossNetworkConverterLink link in project.converterLinks) {
        final ElectricalNetwork? input = project.networks
            .where((ElectricalNetwork n) => n.id == link.inputNetworkId)
            .firstOrNull;
        final ElectricalNetwork? output = project.networks
            .where((ElectricalNetwork n) => n.id == link.outputNetworkId)
            .firstOrNull;
        if (input == null || output == null) {
          diagnostics.add(
            'Convertisseur ${link.id}: réseau d’entrée ou de sortie absent; frontière ouverte.',
          );
          continue;
        }
        final _ConverterCouplingResult coupling = _couplePvToAc1(
          link: link,
          input: input,
          output: output,
          outputCircuit: output.circuit,
          elapsed: elapsed,
          previousPv: previous?.networks[input.id],
          previousAc: previous?.networks[output.id],
        );
        single[input.id] = coupling.pvSnapshot;
        single[output.id] = coupling.acSnapshot;
        if (!coupling.converged) {
          diagnostics.add(
            'Convertisseur ${link.id}: couplage PV–AC1 non convergé après 8 itérations; frontière ouverte.',
          );
        }
      }
      return ElectricalProjectRuntimeSnapshot(
        networks: single,
        relayBridgeStates: const <String, bool>{},
        feedbackSignalStates: const <String, bool>{},
        ladderStates: const {},
        elapsed: (previous?.elapsed ?? Duration.zero) + elapsed,
        diagnostics: diagnostics,
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
    final Map<String, Map<String, bool>> actuatorCommands =
        _plcActuatorCommands(
          project: project,
          dcNetwork: dcNetwork,
          ladder: ladder,
          plcSupply: plcSupply,
          plcProgramErrors: plcProgramErrors,
          diagnostics: diagnostics,
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

    final CircuitState acProjected = _projectPlcActuatorCommands(
      _projectAcRelayContacts(acNetwork.circuit, project, relayByCoil),
      actuatorCommands[acNetwork.id] ?? const <String, bool>{},
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
    final Set<String> converterNetworks = <String>{
      for (final CrossNetworkConverterLink link
          in project.converterLinks) ...<String>{
        link.inputNetworkId,
        link.outputNetworkId,
      },
    };
    final Map<String, ElectroSimRuntimeSnapshot> snapshots =
        <String, ElectroSimRuntimeSnapshot>{
          dcNetwork.id: dcFinal,
          acNetwork.id: acFinal,
          for (final ElectricalNetwork network in project.networks)
            if (network.id != dcNetwork.id &&
                network.id != acNetwork.id &&
                !converterNetworks.contains(network.id))
              network.id: networkEngine.advance(
                _projectPlcActuatorCommands(
                  network.circuit,
                  actuatorCommands[network.id] ?? const <String, bool>{},
                ),
                elapsed: elapsed,
                previousEnergyMeters:
                    previous?.networks[network.id]?.energyMeters ?? const {},
                previousProtectionState:
                    previous?.networks[network.id]?.protectionState,
                previousContactorStates: _previousActuators(
                  previous?.networks[network.id],
                ),
                previousControlStates:
                    previous?.networks[network.id]?.controlRuntimeStates ??
                    const {},
                previousComponentHealthStates:
                    previous?.networks[network.id]?.componentHealthStates ??
                    const {},
                previousPvBatterySoc:
                    previous?.networks[network.id]?.pvResult?.batteryPresent ==
                        true
                    ? previous!.networks[network.id]!.pvResult!.batterySoc
                    : null,
                previousDcBatterySocs:
                    previous?.networks[network.id]?.dcBatterySocs ?? const {},
                previousMotorAngularSpeedsRadS:
                    previous?.networks[network.id]?.motorAngularSpeedsRadS ??
                    const {},
              ),
        };
    for (final CrossNetworkConverterLink link in project.converterLinks) {
      final ElectricalNetwork? input = project.networks
          .where((ElectricalNetwork n) => n.id == link.inputNetworkId)
          .firstOrNull;
      final ElectricalNetwork? output = project.networks
          .where((ElectricalNetwork n) => n.id == link.outputNetworkId)
          .firstOrNull;
      if (input == null || output == null) {
        diagnostics.add(
          'Convertisseur ${link.id}: réseau d’entrée ou de sortie absent; frontière ouverte.',
        );
        continue;
      }
      final _ConverterCouplingResult result = _couplePvToAc1(
        link: link,
        input: input,
        output: output,
        outputCircuit: _projectPlcActuatorCommands(
          output.circuit,
          actuatorCommands[output.id] ?? const <String, bool>{},
        ),
        elapsed: elapsed,
        previousPv: previous?.networks[input.id],
        previousAc: previous?.networks[output.id],
      );
      snapshots[input.id] = result.pvSnapshot;
      snapshots[output.id] = result.acSnapshot;
      if (!result.converged) {
        diagnostics.add(
          'Convertisseur ${link.id}: couplage PV–AC1 non convergé après 8 itérations; frontière ouverte.',
        );
      }
    }
    return ElectricalProjectRuntimeSnapshot(
      networks: snapshots,
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

  _ConverterCouplingResult _couplePvToAc1({
    required CrossNetworkConverterLink link,
    required ElectricalNetwork input,
    required ElectricalNetwork output,
    required CircuitState outputCircuit,
    required Duration elapsed,
    required ElectroSimRuntimeSnapshot? previousPv,
    required ElectroSimRuntimeSnapshot? previousAc,
  }) {
    final ComponentInstance? inverter = input.circuit.components
        .where(
          (ComponentInstance c) =>
              c.id.value == link.converterComponentId &&
              c.modelType == 'pv_inverter',
        )
        .firstOrNull;
    if (inverter == null ||
        inverter.terminals.length < 4 ||
        output.circuit.sources.any(
          (SourceInstance s) => s.enabled && s.modelType == 'ac_voltage_source',
        )) {
      final ElectroSimRuntimeSnapshot pv = _advanceIndependent(
        input,
        elapsed,
        previousPv,
      );
      final ElectroSimRuntimeSnapshot ac = _advanceIndependent(
        output,
        elapsed,
        previousAc,
      );
      return _ConverterCouplingResult(
        pvSnapshot: pv,
        acSnapshot: ac,
        converged: false,
      );
    }

    double reflectedLoadOhm = 1000.0;
    double priorVoltage = double.nan;
    double priorPower = double.nan;
    double? pvSoc = previousPv?.pvResult?.batteryPresent == true
        ? previousPv!.pvResult!.batterySoc
        : null;
    ElectroSimRuntimeSnapshot? finalPv;
    ElectroSimRuntimeSnapshot? finalAc;
    for (int pass = 0; pass < 8; pass++) {
      final CircuitState pvDesign = _projectExternalPvLoad(
        input.circuit,
        inverter,
        link,
        reflectedLoadOhm,
      );
      finalPv = networkEngine.advance(
        pvDesign,
        elapsed: pass == 0 ? elapsed : Duration.zero,
        previousPvBatterySoc: pvSoc,
        previousEnergyMeters: pass == 0
            ? previousPv?.energyMeters ?? const {}
            : const {},
        previousComponentHealthStates:
            previousPv?.componentHealthStates ?? const {},
      );
      final PvSolveResult? pvResult = finalPv.pvResult;
      if (pvResult == null ||
          !pvResult.isSolved ||
          pvResult.inverterOutputPowerW <= 0.0) {
        break;
      }
      pvSoc = pvResult.batteryPresent ? pvResult.batterySoc : pvSoc;
      final double nominal =
          _positiveParameter(inverter.parameters['nominalAcVoltageV']) ?? 230.0;
      final double voltage = pvResult.inverterOutputVoltageRmsV > 0.0
          ? pvResult.inverterOutputVoltageRmsV
          : nominal;
      final CircuitState acDesign = _projectPvInverterSource(
        outputCircuit,
        link,
        voltage,
      );
      finalAc = networkEngine.advance(
        acDesign,
        elapsed: pass == 0 ? elapsed : Duration.zero,
        previousEnergyMeters: pass == 0
            ? previousAc?.energyMeters ?? const {}
            : const {},
        previousProtectionState: previousAc?.protectionState,
        previousContactorStates: _previousActuators(previousAc),
        previousComponentHealthStates:
            previousAc?.componentHealthStates ?? const {},
      );
      final Ac1SolveResult? acResult = finalAc.ac1Result;
      if (acResult == null || !acResult.isSolved) break;
      final double demandedPower = acResult.branchResults
          .where((Ac1BranchResult b) => b.kind != Ac1BranchKind.voltageSource)
          .fold<double>(
            0.0,
            (double sum, Ac1BranchResult b) =>
                sum + math.max(0.0, b.activePowerW ?? 0.0),
          );
      final double deliveredVoltage =
          voltage *
          (demandedPower > pvResult.inverterOutputPowerW
              ? math.sqrt(pvResult.inverterOutputPowerW / demandedPower)
              : 1.0);
      final double deliveredPower = math.min(
        demandedPower,
        pvResult.inverterOutputPowerW,
      );
      if (priorVoltage.isFinite &&
          priorPower.isFinite &&
          _couplingConverged(priorVoltage, deliveredVoltage, 0.01) &&
          _couplingConverged(priorPower, deliveredPower, 0.1)) {
        return _ConverterCouplingResult(
          pvSnapshot: finalPv,
          acSnapshot: finalAc,
          converged: true,
        );
      }
      priorVoltage = deliveredVoltage;
      priorPower = deliveredPower;
      if (demandedPower > 0.0 && voltage > 0.0) {
        reflectedLoadOhm = voltage * voltage / demandedPower;
      }
    }

    final CircuitState openCircuit = _withoutPvInverterSource(
      outputCircuit,
      link,
    );
    final ElectroSimRuntimeSnapshot safeAc = networkEngine.advance(
      openCircuit,
      elapsed: finalAc == null ? elapsed : Duration.zero,
      previousEnergyMeters: previousAc?.energyMeters ?? const {},
      previousProtectionState: previousAc?.protectionState,
      previousContactorStates: _previousActuators(previousAc),
      previousComponentHealthStates:
          previousAc?.componentHealthStates ?? const {},
    );
    return _ConverterCouplingResult(
      pvSnapshot: finalPv ?? _advanceIndependent(input, elapsed, previousPv),
      acSnapshot: safeAc,
      converged: false,
    );
  }

  static CircuitState _projectExternalPvLoad(
    CircuitState circuit,
    ComponentInstance inverter,
    CrossNetworkConverterLink link,
    double resistanceOhm,
  ) {
    final String id = 'mixed-${link.id}-load';
    final ComponentInstance load = ComponentInstance(
      id: ComponentId(id),
      modelType: 'pv_resistive_load',
      terminals: <Terminal>[
        Terminal(
          id: TerminalId('$id-line'),
          name: 'L',
          role: TerminalRole.line,
          phase: PhaseTag.l1,
        ),
        Terminal(
          id: TerminalId('$id-neutral'),
          name: 'N',
          role: TerminalRole.neutral,
          phase: PhaseTag.neutral,
        ),
      ],
      parameters: <String, Object?>{'resistanceOhm': resistanceOhm},
    );
    return CircuitState(
      circuitId: circuit.circuitId,
      revision: circuit.revision,
      mode: circuit.mode,
      components: <ComponentInstance>[...circuit.components, load],
      connections: <Connection>[
        ...circuit.connections,
        Connection(
          id: ConnectionId('$id-wire-line'),
          fromTerminalId: inverter.terminals[2].id,
          toTerminalId: load.terminals[0].id,
          phase: PhaseTag.l1,
        ),
        Connection(
          id: ConnectionId('$id-wire-neutral'),
          fromTerminalId: inverter.terminals[3].id,
          toTerminalId: load.terminals[1].id,
          phase: PhaseTag.neutral,
        ),
      ],
      sources: circuit.sources,
      instruments: circuit.instruments,
      probes: circuit.probes,
      settings: circuit.settings,
      metadata: circuit.metadata,
    );
  }

  static CircuitState _projectPvInverterSource(
    CircuitState circuit,
    CrossNetworkConverterLink link,
    double voltageRmsV,
  ) {
    if (circuit.sources.any(
      (SourceInstance s) => s.id.value == 'mixed-${link.id}-source',
    )) {
      return circuit;
    }
    final String id = 'mixed-${link.id}-source';
    final SourceInstance source = SourceInstance(
      id: SourceId(id),
      modelType: 'ac_voltage_source',
      terminals: <Terminal>[
        Terminal(
          id: TerminalId('$id-line'),
          name: 'L',
          role: TerminalRole.line,
          phase: PhaseTag.l1,
        ),
        Terminal(
          id: TerminalId('$id-neutral'),
          name: 'N',
          role: TerminalRole.neutral,
          phase: PhaseTag.neutral,
        ),
      ],
      parameters: <String, Object?>{
        'voltageRmsV': voltageRmsV,
        'phaseDeg': 0.0,
      },
    );
    return _withVirtualSource(
      circuit,
      source,
      link.outputLineTerminalId,
      link.outputNeutralTerminalId,
    );
  }

  static CircuitState _withoutPvInverterSource(
    CircuitState circuit,
    CrossNetworkConverterLink link,
  ) => CircuitState(
    circuitId: circuit.circuitId,
    revision: circuit.revision,
    mode: circuit.mode,
    components: circuit.components,
    connections: circuit.connections
        .where(
          (Connection c) => !c.id.value.startsWith('mixed-${link.id}-source-'),
        )
        .toList(),
    sources: circuit.sources
        .where((SourceInstance s) => s.id.value != 'mixed-${link.id}-source')
        .toList(),
    instruments: circuit.instruments,
    probes: circuit.probes,
    settings: circuit.settings,
    metadata: circuit.metadata,
  );

  static CircuitState _withVirtualSource(
    CircuitState circuit,
    SourceInstance source,
    String lineTarget,
    String neutralTarget,
  ) => CircuitState(
    circuitId: circuit.circuitId,
    revision: circuit.revision,
    mode: circuit.mode,
    components: circuit.components,
    connections: <Connection>[
      ...circuit.connections,
      Connection(
        id: ConnectionId('${source.id.value}-wire-line'),
        fromTerminalId: source.terminals[0].id,
        toTerminalId: TerminalId(lineTarget),
        phase: PhaseTag.l1,
      ),
      Connection(
        id: ConnectionId('${source.id.value}-wire-neutral'),
        fromTerminalId: source.terminals[1].id,
        toTerminalId: TerminalId(neutralTarget),
        phase: PhaseTag.neutral,
      ),
    ],
    sources: <SourceInstance>[...circuit.sources, source],
    instruments: circuit.instruments,
    probes: circuit.probes,
    settings: circuit.settings,
    metadata: circuit.metadata,
  );

  static bool _couplingConverged(
    double previous,
    double current,
    double floor,
  ) =>
      (previous - current).abs() <=
      math.max(floor, math.max(previous.abs(), current.abs()) * 0.001);

  static double? _positiveParameter(Object? value) =>
      value is num && value.isFinite && value > 0 ? value.toDouble() : null;

  static Map<String, Map<String, bool>> _plcActuatorCommands({
    required ElectricalProject project,
    required ElectricalNetwork dcNetwork,
    required Map<String, LadderRuntimeState> ladder,
    required Map<String, bool> plcSupply,
    required Map<String, bool> plcProgramErrors,
    required List<String> diagnostics,
  }) {
    final Map<String, Map<String, bool>> commands =
        <String, Map<String, bool>>{};
    for (final CrossNetworkActuatorLink link in project.actuatorLinks) {
      if (link.plcNetworkId != dcNetwork.id) continue;
      final ComponentInstance? plc = dcNetwork.circuit.components
          .where(
            (ComponentInstance c) =>
                c.id.value == link.plcComponentId && c.modelType == 'plc_dc',
          )
          .firstOrNull;
      final bool enabled =
          plc != null &&
          plcSupply[plc.id.value] == true &&
          plcProgramErrors[plc.id.value] != true;
      final bool requested =
          enabled &&
          ladder['${dcNetwork.id}/${link.plcComponentId}']?.outputs[link
                  .outputAddress] ==
              true;
      if (!enabled) {
        diagnostics.add(
          'Liaison ${link.id}: automate non alimenté ou programme invalide; contacteur relâché.',
        );
      }
      (commands[link.targetNetworkId] ??= <String, bool>{})[link.contactorId] =
          requested;
    }
    return commands;
  }

  static CircuitState _projectPlcActuatorCommands(
    CircuitState circuit,
    Map<String, bool> commands,
  ) => CircuitState(
    circuitId: circuit.circuitId,
    revision: circuit.revision,
    mode: circuit.mode,
    components: circuit.components
        .map((ComponentInstance component) {
          final bool? command = commands[component.id.value];
          if (command == null) return component;
          return ComponentInstance(
            id: component.id,
            modelType: component.modelType,
            terminals: component.terminals,
            parameters: component.parameters,
            condition: component.condition,
            controlState: <String, Object?>{
              ...component.controlState,
              'plcCommand': command,
              'plcEnable': true,
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

  ElectroSimRuntimeSnapshot _advanceIndependent(
    ElectricalNetwork network,
    Duration elapsed,
    ElectroSimRuntimeSnapshot? previous,
  ) {
    final double? pvSoc = previous?.pvResult?.batteryPresent == true
        ? previous!.pvResult!.batterySoc
        : null;
    return networkEngine.advance(
      network.circuit,
      elapsed: elapsed,
      previousEnergyMeters: previous?.energyMeters ?? const {},
      previousProtectionState: previous?.protectionState,
      previousContactorStates: _previousActuators(previous),
      previousControlStates: previous?.controlRuntimeStates ?? const {},
      previousComponentHealthStates:
          previous?.componentHealthStates ?? const {},
      previousPvBatterySoc: pvSoc,
      previousDcBatterySocs: previous?.dcBatterySocs ?? const {},
      previousMotorAngularSpeedsRadS:
          previous?.motorAngularSpeedsRadS ?? const {},
    );
  }

  ElectricalProjectRuntimeSnapshot _advanceDcActuatorNetworks(
    ElectricalProject project,
    ElectricalNetwork dcNetwork,
    Duration elapsed,
    ElectricalProjectRuntimeSnapshot? previous,
    Map<String, LadderRuntimeState> ladder,
    List<String> diagnostics,
  ) {
    final ElectroSimRuntimeSnapshot dcFirst = _advanceIndependent(
      dcNetwork,
      elapsed,
      previous?.networks[dcNetwork.id],
    );
    final Map<String, bool> inputs = _readInputs(
      dcNetwork.circuit,
      dcFirst,
      diagnostics,
    );
    final Map<String, bool> supply = <String, bool>{};
    final Map<String, double> supplyVoltage = <String, double>{};
    final Map<String, bool> programErrors = <String, bool>{};
    final Map<String, Map<String, bool>> plcInputs =
        <String, Map<String, bool>>{};
    for (final ComponentInstance plc in dcNetwork.circuit.components.where(
      (ComponentInstance c) => c.modelType == 'plc_dc',
    )) {
      final double? voltage = plc.terminals.length >= 2
          ? _terminalVoltage(dcFirst, plc.terminals[0].id, plc.terminals[1].id)
          : null;
      final bool valid =
          voltage != null &&
          voltage >= 20.4 &&
          voltage <= 28.8 &&
          plc.condition == ComponentCondition.normal;
      supply[plc.id.value] = valid;
      if (voltage != null) supplyVoltage[plc.id.value] = voltage;
      if (!valid) {
        diagnostics.add(
          'PLC ${plc.id.value}: alimentation 24 V absente ou hors plage.',
        );
      }
      plcInputs[plc.id.value] = <String, bool>{
        for (int i = 0; i < 4; i++) 'I$i': inputs['I$i'] ?? false,
      };
      final String key = '${dcNetwork.id}/${plc.id.value}';
      final LadderScanResult scan = ladderEngine.scan(
        program: _program(plc.parameters['ladderProgram']),
        inputs: valid ? inputs : const <String, bool>{},
        previous: ladder[key] ?? LadderRuntimeState(),
        elapsed: elapsed,
      );
      ladder[key] = valid
          ? scan.state
          : LadderRuntimeState(
              memories: scan.state.memories,
              timerSeconds: scan.state.timerSeconds,
              timerDone: scan.state.timerDone,
            );
      programErrors[plc.id.value] = scan.programError;
      if (scan.programError) {
        diagnostics.add(
          'PLC ${plc.id.value}: programme Ladder invalide; sorties désactivées.',
        );
      }
    }
    final CircuitState corrected = _projectPlcState(
      dcNetwork.id,
      dcNetwork.circuit,
      ladder,
      supplyValid: supply.values.every((bool value) => value),
      perPlcSupply: supply,
      perPlcVoltage: supplyVoltage,
      perPlcInputs: plcInputs,
      perPlcProgramError: programErrors,
    );
    final ElectroSimRuntimeSnapshot dcFinal = networkEngine.advance(
      corrected,
      elapsed: Duration.zero,
      previousContactorStates: _previousActuators(dcFirst),
      previousComponentHealthStates: dcFirst.componentHealthStates,
    );
    final Map<String, Map<String, bool>> commands = _plcActuatorCommands(
      project: project,
      dcNetwork: dcNetwork,
      ladder: ladder,
      plcSupply: supply,
      plcProgramErrors: programErrors,
      diagnostics: diagnostics,
    );
    final Set<String> converterNetworks = <String>{
      for (final CrossNetworkConverterLink link
          in project.converterLinks) ...<String>{
        link.inputNetworkId,
        link.outputNetworkId,
      },
    };
    final Map<String, ElectroSimRuntimeSnapshot> snapshots =
        <String, ElectroSimRuntimeSnapshot>{dcNetwork.id: dcFinal};
    for (final ElectricalNetwork network in project.networks) {
      if (network.id == dcNetwork.id ||
          converterNetworks.contains(network.id)) {
        continue;
      }
      snapshots[network.id] = networkEngine.advance(
        _projectPlcActuatorCommands(
          network.circuit,
          commands[network.id] ?? const <String, bool>{},
        ),
        elapsed: elapsed,
        previousContactorStates: _previousActuators(
          previous?.networks[network.id],
        ),
        previousProtectionState:
            previous?.networks[network.id]?.protectionState,
        previousComponentHealthStates:
            previous?.networks[network.id]?.componentHealthStates ?? const {},
      );
    }
    for (final CrossNetworkConverterLink link in project.converterLinks) {
      final ElectricalNetwork input = project.networks.firstWhere(
        (ElectricalNetwork n) => n.id == link.inputNetworkId,
      );
      final ElectricalNetwork output = project.networks.firstWhere(
        (ElectricalNetwork n) => n.id == link.outputNetworkId,
      );
      final _ConverterCouplingResult coupling = _couplePvToAc1(
        link: link,
        input: input,
        output: output,
        outputCircuit: _projectPlcActuatorCommands(
          output.circuit,
          commands[output.id] ?? const <String, bool>{},
        ),
        elapsed: elapsed,
        previousPv: previous?.networks[input.id],
        previousAc: previous?.networks[output.id],
      );
      snapshots[input.id] = coupling.pvSnapshot;
      snapshots[output.id] = coupling.acSnapshot;
      if (!coupling.converged) {
        diagnostics.add(
          'Convertisseur ${link.id}: couplage PV–AC1 non convergé après 8 itérations; frontière ouverte.',
        );
      }
    }
    return ElectricalProjectRuntimeSnapshot(
      networks: snapshots,
      relayBridgeStates: const {},
      feedbackSignalStates: const {},
      ladderStates: <String, Map<String, LadderRuntimeState>>{
        dcNetwork.id: <String, LadderRuntimeState>{
          for (final MapEntry<String, LadderRuntimeState> entry
              in ladder.entries)
            if (entry.key.startsWith('${dcNetwork.id}/'))
              entry.key.substring(dcNetwork.id.length + 1): entry.value,
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
