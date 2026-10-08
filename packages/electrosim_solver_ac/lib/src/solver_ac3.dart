import 'dart:math' as math;

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_topology/electrosim_topology.dart';

import 'ac1_complex.dart';
import 'ac3_diagnostic.dart';
import 'ac3_result.dart';
import 'ac3_solver_options.dart';

final class SolverAC3 {
  const SolverAC3({this.options = const Ac3SolverOptions()});

  static const String engineVersion = 'solver-ac3/0.4.0';

  final Ac3SolverOptions options;

  Ac3SolveResult solve(CircuitState circuit, TopologyGraph topology) {
    final List<Ac3SolverDiagnostic> diagnostics = <Ac3SolverDiagnostic>[];
    if (circuit.mode != ElectricalMode.ac3 ||
        topology.mode != ElectricalMode.ac3) {
      diagnostics.add(
        Ac3SolverDiagnostic(
          code: Ac3DiagnosticCode.wrongElectricalMode,
          severity: Ac3DiagnosticSeverity.error,
          message: 'SolverAC3 accepts AC three-phase circuits only.',
        ),
      );
      return _failure(circuit, Ac3SolveStatus.invalid, diagnostics);
    }
    if (circuit.circuitId != topology.circuitId ||
        circuit.revision != topology.circuitRevision) {
      diagnostics.add(
        Ac3SolverDiagnostic(
          code: Ac3DiagnosticCode.topologyIdentityMismatch,
          severity: Ac3DiagnosticSeverity.error,
          message:
              'TopologyGraph does not match the CircuitState identity/revision.',
        ),
      );
      return _failure(circuit, Ac3SolveStatus.invalid, diagnostics);
    }
    if (topology.nodes.isEmpty) {
      diagnostics.add(
        Ac3SolverDiagnostic(
          code: Ac3DiagnosticCode.emptyCircuit,
          severity: Ac3DiagnosticSeverity.error,
          message: 'AC3 circuit contains no electrical nodes.',
        ),
      );
      return _failure(circuit, Ac3SolveStatus.invalid, diagnostics);
    }

    for (final TopologyFinding finding in topology.findings) {
      if (finding.severity == TopologyFindingSeverity.error) {
        diagnostics.add(
          Ac3SolverDiagnostic(
            code: Ac3DiagnosticCode.topologyError,
            severity: Ac3DiagnosticSeverity.error,
            message: finding.message,
            componentId: finding.componentId,
            sourceId: finding.sourceId,
            nodeIds: <String>[if (finding.nodeId != null) finding.nodeId!],
          ),
        );
      }
    }

    final double? frequencyHz = _frequency(circuit, diagnostics);
    if (frequencyHz == null || diagnostics.any(_isError)) {
      return _failure(
        circuit,
        Ac3SolveStatus.invalid,
        diagnostics,
        frequencyHz: frequencyHz,
      );
    }

    final _CompiledAc3Model compiled = _compileModel(
      circuit,
      topology,
      frequencyHz,
      diagnostics,
    );
    if (compiled.hasErrors || diagnostics.any(_isError)) {
      return _failure(
        circuit,
        Ac3SolveStatus.invalid,
        diagnostics,
        frequencyHz: frequencyHz,
      );
    }

    final List<PhaseTag> missingPhases = _threePhases
        .where(
          (PhaseTag phase) => !compiled.presentSourcePhases.contains(phase),
        )
        .toList(growable: false);
    for (final PhaseTag phase in missingPhases) {
      diagnostics.add(
        Ac3SolverDiagnostic(
          code: Ac3DiagnosticCode.phaseLoss,
          severity: Ac3DiagnosticSeverity.warning,
          message:
              'Phase ${phase.name.toUpperCase()} has no enabled AC source.',
          phase: phase,
        ),
      );
    }

    final String referenceNodeId = _selectReferenceNode(circuit, topology);
    final List<String> floatingNodes = _findFloatingNodes(
      topology.nodes.map((TopologyNode node) => node.id),
      referenceNodeId,
      compiled.activeElements,
    );
    if (floatingNodes.isNotEmpty) {
      diagnostics.add(
        Ac3SolverDiagnostic(
          code: Ac3DiagnosticCode.floatingElectricalIsland,
          severity: Ac3DiagnosticSeverity.error,
          message:
              'Electrical island is not connected to the AC3 reference node.',
          nodeIds: floatingNodes,
        ),
      );
      return _failure(
        circuit,
        Ac3SolveStatus.singular,
        diagnostics,
        frequencyHz: frequencyHz,
        referenceNodeId: referenceNodeId,
        missingPhases: missingPhases,
      );
    }

    final List<String> unknownNodes =
        topology.nodes
            .map((TopologyNode node) => node.id)
            .where((String nodeId) => nodeId != referenceNodeId)
            .toList(growable: false)
          ..sort();
    final Map<String, int> nodeIndex = <String, int>{
      for (var i = 0; i < unknownNodes.length; i++) unknownNodes[i]: i,
    };
    final List<_Ac3Element> idealConstraints =
        compiled.activeElements
            .where(
              (_Ac3Element element) =>
                  element.kind == _Ac3ElementKind.idealVoltage,
            )
            .toList(growable: false)
          ..sort((_Ac3Element a, _Ac3Element b) => a.id.compareTo(b.id));
    final Map<String, int> idealIndex = <String, int>{
      for (var i = 0; i < idealConstraints.length; i++)
        idealConstraints[i].id: i,
    };

    final int nodeCount = unknownNodes.length;
    final int size = nodeCount + idealConstraints.length;
    final List<List<AcComplex>> matrix = List<List<AcComplex>>.generate(
      size,
      (_) => List<AcComplex>.filled(size, AcComplex.zero),
      growable: false,
    );
    final List<AcComplex> rhs = List<AcComplex>.filled(size, AcComplex.zero);

    for (final _Ac3Element element in compiled.activeElements) {
      switch (element.kind) {
        case _Ac3ElementKind.impedance:
          final AcComplex admittance = AcComplex.one / element.value;
          _stampAdmittance(
            matrix,
            nodeIndex,
            referenceNodeId,
            element.fromNodeId,
            element.toNodeId,
            admittance,
          );
        case _Ac3ElementKind.currentSource:
          _stampCurrentSource(
            rhs,
            nodeIndex,
            referenceNodeId,
            element.fromNodeId,
            element.toNodeId,
            element.value,
          );
        case _Ac3ElementKind.idealVoltage:
          _stampIdealVoltage(
            matrix,
            rhs,
            nodeIndex,
            referenceNodeId,
            nodeCount + idealIndex[element.id]!,
            element.fromNodeId,
            element.toNodeId,
            element.value,
          );
      }
    }

    final _Ac3LinearSolveOutcome outcome = _solveLinearSystem(
      matrix,
      rhs,
      options.pivotTolerance,
    );
    if (outcome.solution == null) {
      diagnostics.add(
        Ac3SolverDiagnostic(
          code: Ac3DiagnosticCode.singularMatrix,
          severity: Ac3DiagnosticSeverity.error,
          message:
              'Complex AC3 MNA matrix is singular or numerically rank-deficient.',
        ),
      );
      return _failure(
        circuit,
        Ac3SolveStatus.singular,
        diagnostics,
        frequencyHz: frequencyHz,
        referenceNodeId: referenceNodeId,
        missingPhases: missingPhases,
      );
    }

    final List<AcComplex> solution = outcome.solution!;
    final double maxResidual = _maxMatrixResidual(matrix, solution, rhs);
    if (!maxResidual.isFinite || maxResidual > options.residualTolerance) {
      diagnostics.add(
        Ac3SolverDiagnostic(
          code: Ac3DiagnosticCode.numericalResidualExceeded,
          severity: Ac3DiagnosticSeverity.error,
          message: 'AC3 MNA numerical residual exceeds configured tolerance.',
        ),
      );
      return _failure(
        circuit,
        Ac3SolveStatus.invalid,
        diagnostics,
        frequencyHz: frequencyHz,
        referenceNodeId: referenceNodeId,
        missingPhases: missingPhases,
      );
    }

    final Map<String, AcComplex> nodeVoltages = <String, AcComplex>{
      referenceNodeId: AcComplex.zero,
    };
    for (final MapEntry<String, int> entry in nodeIndex.entries) {
      nodeVoltages[entry.key] = solution[entry.value];
    }

    final List<Ac3BranchResult> branches = <Ac3BranchResult>[];
    final Map<String, AcComplex> nodeCurrentBalance = <String, AcComplex>{
      for (final TopologyNode node in topology.nodes) node.id: AcComplex.zero,
    };
    final Map<PhaseTag, AcComplex> phaseVoltages = <PhaseTag, AcComplex>{};
    final Map<PhaseTag, AcComplex> lineCurrents = <PhaseTag, AcComplex>{};

    for (final _Ac3Element element in compiled.allElements) {
      final AcComplex voltage =
          nodeVoltages[element.fromNodeId]! - nodeVoltages[element.toNodeId]!;
      AcComplex? current;
      switch (element.kind) {
        case _Ac3ElementKind.impedance:
          current = element.isOpen ? AcComplex.zero : voltage / element.value;
        case _Ac3ElementKind.currentSource:
          current = element.value;
        case _Ac3ElementKind.idealVoltage:
          final int? constraintIndex = idealIndex[element.id];
          current = constraintIndex == null
              ? null
              : solution[nodeCount + constraintIndex];
      }
      if (current != null) {
        nodeCurrentBalance[element.fromNodeId] =
            nodeCurrentBalance[element.fromNodeId]! + current;
        nodeCurrentBalance[element.toNodeId] =
            nodeCurrentBalance[element.toNodeId]! - current;
      }
      branches.add(
        Ac3BranchResult(
          id: element.id,
          modelType: element.modelType,
          kind: element.branchKind,
          fromNodeId: element.fromNodeId,
          toNodeId: element.toNodeId,
          voltage: voltage,
          current: current,
          phase: element.phase,
        ),
      );

      if (element.isSource &&
          element.kind == _Ac3ElementKind.idealVoltage &&
          element.phase != null) {
        phaseVoltages.putIfAbsent(element.phase!, () => voltage);
        if (current != null) {
          final AcComplex suppliedCurrent = -current;
          lineCurrents.update(
            element.phase!,
            (AcComplex previous) => previous + suppliedCurrent,
            ifAbsent: () => suppliedCurrent,
          );
        }
      }
    }
    branches.sort(
      (Ac3BranchResult a, Ac3BranchResult b) => a.id.compareTo(b.id),
    );

    final Map<String, double> kclResiduals = <String, double>{
      for (final MapEntry<String, AcComplex> entry
          in nodeCurrentBalance.entries)
        entry.key: entry.value.magnitude,
    };
    var worstKcl = 0.0;
    for (final double residual in kclResiduals.values) {
      if (residual > worstKcl) {
        worstKcl = residual;
      }
    }
    if (worstKcl > options.residualTolerance) {
      diagnostics.add(
        Ac3SolverDiagnostic(
          code: Ac3DiagnosticCode.numericalResidualExceeded,
          severity: Ac3DiagnosticSeverity.error,
          message: 'AC3 KCL residual exceeds configured tolerance.',
        ),
      );
      return _failure(
        circuit,
        Ac3SolveStatus.invalid,
        diagnostics,
        frequencyHz: frequencyHz,
        referenceNodeId: referenceNodeId,
        missingPhases: missingPhases,
      );
    }

    final AcComplex sumLineCurrent = _threePhases.fold<AcComplex>(
      AcComplex.zero,
      (AcComplex sum, PhaseTag phase) =>
          sum + (lineCurrents[phase] ?? AcComplex.zero),
    );
    final AcComplex neutralCurrent = -sumLineCurrent;
    final Map<String, AcComplex> lineToLineVoltages = _lineToLine(
      phaseVoltages,
    );
    final Ac3PhaseSequence sourceSequence = _sequence(
      _threePhases
          .map((PhaseTag phase) => phaseVoltages[phase])
          .toList(growable: false),
      options.phaseAngleToleranceDegrees,
    );
    final bool voltageBalanced = _balancedMagnitudes(
      _threePhases
          .map((PhaseTag phase) => phaseVoltages[phase])
          .toList(growable: false),
      options.balanceRelativeTolerance,
    );
    final bool currentBalanced =
        _balancedMagnitudes(
          _threePhases
              .map((PhaseTag phase) => lineCurrents[phase])
              .toList(growable: false),
          options.balanceRelativeTolerance,
        ) &&
        neutralCurrent.magnitude <=
            options.balanceRelativeTolerance *
                math.max(
                  1.0,
                  _threePhases
                      .map(
                        (PhaseTag phase) =>
                            lineCurrents[phase]?.magnitude ?? 0.0,
                      )
                      .fold<double>(
                        0.0,
                        (double maximum, double value) =>
                            math.max(maximum, value),
                      ),
                );

    final List<Ac3PhaseOrderObservation> observations =
        <Ac3PhaseOrderObservation>[];
    for (final _Ac3Probe probe in compiled.probes) {
      final List<AcComplex> voltages = probe.nodeIds
          .map((String nodeId) => nodeVoltages[nodeId]!)
          .toList(growable: false);
      observations.add(
        Ac3PhaseOrderObservation(
          componentId: probe.componentId,
          sequence: _sequence(voltages, options.phaseAngleToleranceDegrees),
          terminalVoltages: voltages,
        ),
      );
    }
    observations.sort(
      (Ac3PhaseOrderObservation a, Ac3PhaseOrderObservation b) =>
          a.componentId.value.compareTo(b.componentId.value),
    );

    return Ac3SolveResult(
      circuitId: circuit.circuitId,
      circuitRevision: circuit.revision,
      engineVersion: engineVersion,
      status: Ac3SolveStatus.solved,
      frequencyHz: frequencyHz,
      referenceNodeId: referenceNodeId,
      nodeVoltages: nodeVoltages,
      branchResults: branches,
      diagnostics: diagnostics,
      maxMatrixResidual: maxResidual,
      kclResiduals: kclResiduals,
      phaseVoltages: phaseVoltages,
      lineCurrents: lineCurrents,
      lineToLineVoltages: lineToLineVoltages,
      neutralCurrent: neutralCurrent,
      missingPhases: missingPhases,
      sourceSequence: sourceSequence,
      voltageBalanced: voltageBalanced,
      currentBalanced: currentBalanced,
      neutralConnected: _neutralConnected(circuit, topology, referenceNodeId),
      phaseOrderObservations: observations,
    );
  }
}

const List<PhaseTag> _threePhases = <PhaseTag>[
  PhaseTag.l1,
  PhaseTag.l2,
  PhaseTag.l3,
];

double? _frequency(
  CircuitState circuit,
  List<Ac3SolverDiagnostic> diagnostics,
) {
  final Object? raw = circuit.settings['frequencyHz'];
  if (raw == null) {
    diagnostics.add(
      Ac3SolverDiagnostic(
        code: Ac3DiagnosticCode.missingFrequency,
        severity: Ac3DiagnosticSeverity.error,
        message: 'AC3 circuit settings must define frequencyHz.',
      ),
    );
    return null;
  }
  if (raw is! num) {
    diagnostics.add(
      Ac3SolverDiagnostic(
        code: Ac3DiagnosticCode.invalidFrequency,
        severity: Ac3DiagnosticSeverity.error,
        message: 'frequencyHz must be numeric.',
      ),
    );
    return null;
  }
  final double value = raw.toDouble();
  if (!value.isFinite || value <= 0.0) {
    diagnostics.add(
      Ac3SolverDiagnostic(
        code: Ac3DiagnosticCode.invalidFrequency,
        severity: Ac3DiagnosticSeverity.error,
        message: 'frequencyHz must be finite and greater than zero.',
      ),
    );
    return null;
  }
  return value;
}

_CompiledAc3Model _compileModel(
  CircuitState circuit,
  TopologyGraph topology,
  double frequencyHz,
  List<Ac3SolverDiagnostic> diagnostics,
) {
  final List<_Ac3Element> elements = <_Ac3Element>[];
  final List<_Ac3Probe> probes = <_Ac3Probe>[];
  final Set<PhaseTag> sourcePhases = <PhaseTag>{};
  final Set<PhaseTag> voltageSourcePhases = <PhaseTag>{};

  final List<ComponentInstance> components =
      circuit.components.toList(growable: false)..sort(
        (ComponentInstance a, ComponentInstance b) =>
            a.id.value.compareTo(b.id.value),
      );
  for (final ComponentInstance component in components) {
    if (component.modelType == 'phase_sequence_probe') {
      if (component.terminals.length != 3) {
        diagnostics.add(
          Ac3SolverDiagnostic(
            code: Ac3DiagnosticCode.invalidTerminalCount,
            severity: Ac3DiagnosticSeverity.error,
            message:
                'phase_sequence_probe ${component.id.value} must expose exactly three terminals.',
            componentId: component.id,
          ),
        );
      } else {
        probes.add(
          _Ac3Probe(
            component.id,
            component.terminals
                .map(
                  (Terminal terminal) => topology.terminalToNode[terminal.id]!,
                )
                .toList(growable: false),
          ),
        );
      }
      continue;
    }

    final ComponentPhysicsContract? physics =
        CoreComponentPhysicsContracts.resolve(component.modelType);
    final ComponentModelContract? structural =
        CoreComponentModelContracts.registry.resolve(component.modelType);
    if (physics == null ||
        structural == null ||
        !structural.supportsMode(ElectricalMode.ac3) ||
        physics.electricalLaw == ComponentElectricalLaw.unsupported) {
      diagnostics.add(
        Ac3SolverDiagnostic(
          code: Ac3DiagnosticCode.unsupportedComponentModel,
          severity: Ac3DiagnosticSeverity.error,
          message:
              'Unsupported canonical AC3 component model ${component.modelType}.',
          componentId: component.id,
        ),
      );
      continue;
    }

    if (physics.electricalLaw == ComponentElectricalLaw.motorThreePhase &&
        component.condition == ComponentCondition.normal) {
      final MotorThreePhaseCouplingAssessment coupling =
          MotorThreePhaseCouplingEvaluator.evaluate(circuit, component);
      if (!coupling.isValid) {
        diagnostics.add(
          Ac3SolverDiagnostic(
            code: Ac3DiagnosticCode.invalidMotorCoupling,
            severity: Ac3DiagnosticSeverity.warning,
            message: coupling.message,
            componentId: component.id,
          ),
        );
      }
    }

    final List<TopologyBranch> topologyBranches = topology.branchesForComponent(
      component.id,
    );
    if (_compileFeedThroughAc3(
      component: component,
      branches: topologyBranches,
      elements: elements,
      diagnostics: diagnostics,
    )) {
      continue;
    }
    if (_compileMultipoleSwitchAc3(
      component: component,
      branches: topologyBranches,
      elements: elements,
      diagnostics: diagnostics,
    )) {
      continue;
    }
    if (_compileThreePhaseImpedanceDeviceAc3(
      component: component,
      branches: topologyBranches,
      frequencyHz: frequencyHz,
      elements: elements,
      diagnostics: diagnostics,
    )) {
      continue;
    }
    if (_compileThreePoleProtectionAc3(
      component: component,
      branches: topologyBranches,
      elements: elements,
      diagnostics: diagnostics,
    )) {
      continue;
    }
    if (_compileElectromechanicalAc3(
      component: component,
      branches: topologyBranches,
      frequencyHz: frequencyHz,
      elements: elements,
      diagnostics: diagnostics,
    )) {
      continue;
    }
    if (topologyBranches.length != 1) {
      diagnostics.add(
        Ac3SolverDiagnostic(
          code: Ac3DiagnosticCode.invalidTerminalCount,
          severity: Ac3DiagnosticSeverity.error,
          message:
              'Canonical AC3 component ${component.id.value} must expose exactly one topology branch.',
          componentId: component.id,
        ),
      );
      continue;
    }
    final TopologyBranch topologyBranch = topologyBranches.single;
    final String fromNode = topologyBranch.fromNodeId;
    final String toNode = topologyBranch.toNodeId;
    final PhaseTag? phase = _singlePhase(component.terminals);

    void addOpen() {
      elements.add(
        _Ac3Element(
          id: 'component:${component.id.value}',
          modelType: component.modelType,
          kind: _Ac3ElementKind.impedance,
          branchKind: Ac3BranchKind.openCircuit,
          fromNodeId: fromNode,
          toNodeId: toNode,
          value: const AcComplex(1e300, 0.0),
          isOpen: true,
          phase: phase,
        ),
      );
    }

    if (component.condition == ComponentCondition.openCircuit ||
        component.condition == ComponentCondition.disabled) {
      addOpen();
      continue;
    }
    if (component.condition == ComponentCondition.shortCircuit) {
      elements.add(
        _Ac3Element(
          id: 'component:${component.id.value}',
          modelType: component.modelType,
          kind: _Ac3ElementKind.idealVoltage,
          branchKind: Ac3BranchKind.idealShort,
          fromNodeId: fromNode,
          toNodeId: toNode,
          value: AcComplex.zero,
          phase: phase,
        ),
      );
      continue;
    }
    if (component.condition != ComponentCondition.normal) {
      diagnostics.add(
        Ac3SolverDiagnostic(
          code: Ac3DiagnosticCode.unsupportedComponentCondition,
          severity: Ac3DiagnosticSeverity.error,
          message: 'Unsupported AC3 condition ${component.condition.name}.',
          componentId: component.id,
        ),
      );
      continue;
    }

    switch (physics.electricalLaw) {
      case ComponentElectricalLaw.binarySwitch:
        final bool? closed = _closedFromControlLawAc3(
          component,
          physics.controlLaw,
        );
        if (closed == null) {
          diagnostics.add(
            Ac3SolverDiagnostic(
              code: Ac3DiagnosticCode.invalidParameter,
              severity: Ac3DiagnosticSeverity.error,
              message:
                  'AC3 switching component ${component.id.value} has invalid canonical control state.',
              componentId: component.id,
            ),
          );
        } else if (closed) {
          elements.add(
            _Ac3Element(
              id: 'component:${component.id.value}',
              modelType: component.modelType,
              kind: _Ac3ElementKind.idealVoltage,
              branchKind: Ac3BranchKind.idealSwitch,
              fromNodeId: fromNode,
              toNodeId: toNode,
              value: AcComplex.zero,
              phase: phase,
            ),
          );
        } else {
          addOpen();
        }
      case ComponentElectricalLaw.protectionSwitch:
        final Object? rawRating =
            component.parameters[ProtectionRating.ratedCurrentKey];
        final Object? rawClosed = component.controlState['closed'];
        final Object? rawTripped = component.controlState['tripped'];
        if (rawRating is! num ||
            !rawRating.toDouble().isFinite ||
            rawRating.toDouble() <= 0.0 ||
            (rawClosed != null && rawClosed is! bool) ||
            (rawTripped != null && rawTripped is! bool)) {
          diagnostics.add(
            Ac3SolverDiagnostic(
              code: Ac3DiagnosticCode.invalidParameter,
              severity: Ac3DiagnosticSeverity.error,
              message:
                  'AC3 protection requires a valid canonical calibre and boolean control state.',
              componentId: component.id,
            ),
          );
          continue;
        }
        final bool closed = (rawClosed as bool?) ?? true;
        final bool tripped = (rawTripped as bool?) ?? false;
        if (closed && !tripped) {
          elements.add(
            _Ac3Element(
              id: 'component:${component.id.value}',
              modelType: component.modelType,
              kind: _Ac3ElementKind.idealVoltage,
              branchKind: Ac3BranchKind.idealProtection,
              fromNodeId: fromNode,
              toNodeId: toNode,
              value: AcComplex.zero,
              phase: phase,
            ),
          );
        } else {
          addOpen();
        }
      case ComponentElectricalLaw.resistive:
      case ComponentElectricalLaw.capacitor:
      case ComponentElectricalLaw.inductor:
      case ComponentElectricalLaw.acImpedance:
        final AcComplex? impedance = _componentImpedance(
          component,
          physics,
          frequencyHz,
          diagnostics,
        );
        if (impedance == null) {
          continue;
        }
        if (impedance.magnitude <= 1e-15) {
          elements.add(
            _Ac3Element(
              id: 'component:${component.id.value}',
              modelType: component.modelType,
              kind: _Ac3ElementKind.idealVoltage,
              branchKind: Ac3BranchKind.idealShort,
              fromNodeId: fromNode,
              toNodeId: toNode,
              value: AcComplex.zero,
              phase: phase,
            ),
          );
          continue;
        }
        elements.add(
          _Ac3Element(
            id: 'component:${component.id.value}',
            modelType: component.modelType,
            kind: _Ac3ElementKind.impedance,
            branchKind: _branchKindForPhysics(physics),
            fromNodeId: fromNode,
            toNodeId: toNode,
            value: impedance,
            phase: phase,
          ),
        );
      case ComponentElectricalLaw.feedThrough:
      case ComponentElectricalLaw.motorDc:
      case ComponentElectricalLaw.motorThreePhase:
      case ComponentElectricalLaw.loadWyeThreePhase:
      case ComponentElectricalLaw.loadDeltaThreePhase:
        diagnostics.add(
          Ac3SolverDiagnostic(
            code: Ac3DiagnosticCode.unsupportedComponentModel,
            severity: Ac3DiagnosticSeverity.error,
            message:
                'Canonical AC3 multi-branch law ${physics.electricalLaw.name} was not compiled by its topology handler.',
            componentId: component.id,
          ),
        );
      case ComponentElectricalLaw.diode:
      case ComponentElectricalLaw.converter:
      case ComponentElectricalLaw.storage:
      case ComponentElectricalLaw.unsupported:
        diagnostics.add(
          Ac3SolverDiagnostic(
            code: Ac3DiagnosticCode.unsupportedComponentModel,
            severity: Ac3DiagnosticSeverity.error,
            message:
                'Electrical law ${physics.electricalLaw.name} is not supported by SolverAC3.',
            componentId: component.id,
          ),
        );
    }
  }

  for (final SourceInstance source in circuit.sources) {
    if (!source.enabled) {
      continue;
    }

    if (source.modelType == 'ac3_voltage_source') {
      if (source.terminals.length != 4) {
        diagnostics.add(
          Ac3SolverDiagnostic(
            code: Ac3DiagnosticCode.invalidTerminalCount,
            severity: Ac3DiagnosticSeverity.error,
            message:
                'AC3 four-wire source ${source.id.value} must expose L1/L2/L3/N.',
            sourceId: source.id,
          ),
        );
        continue;
      }
      Terminal? neutral;
      final Map<PhaseTag, Terminal> phaseTerminals = <PhaseTag, Terminal>{};
      for (final Terminal terminal in source.terminals) {
        if (terminal.phase == PhaseTag.neutral) {
          neutral = terminal;
        } else if (_isLinePhase(terminal.phase)) {
          phaseTerminals[terminal.phase] = terminal;
        }
      }
      if (neutral == null || phaseTerminals.length != 3) {
        diagnostics.add(
          Ac3SolverDiagnostic(
            code: Ac3DiagnosticCode.missingSourcePhaseTag,
            severity: Ac3DiagnosticSeverity.error,
            message:
                'AC3 four-wire source must identify L1, L2, L3 and neutral terminals.',
            sourceId: source.id,
          ),
        );
        continue;
      }
      final Object? rawMagnitude =
          source.parameters['phaseVoltageRmsV'] ??
          source.parameters['voltageRmsV'];
      if (rawMagnitude is! num ||
          !rawMagnitude.toDouble().isFinite ||
          rawMagnitude.toDouble() < 0.0) {
        diagnostics.add(
          Ac3SolverDiagnostic(
            code: Ac3DiagnosticCode.invalidParameter,
            severity: Ac3DiagnosticSeverity.error,
            message:
                'AC3 four-wire source requires finite phaseVoltageRmsV >= 0.',
            sourceId: source.id,
          ),
        );
        continue;
      }
      final double magnitude = rawMagnitude.toDouble();
      final String neutralNode = topology.terminalToNode[neutral.id]!;
      for (final PhaseTag phase in <PhaseTag>[
        PhaseTag.l1,
        PhaseTag.l2,
        PhaseTag.l3,
      ]) {
        final Terminal terminal = phaseTerminals[phase]!;
        sourcePhases.add(phase);
        if (!voltageSourcePhases.add(phase)) {
          diagnostics.add(
            Ac3SolverDiagnostic(
              code: Ac3DiagnosticCode.duplicatePhaseSource,
              severity: Ac3DiagnosticSeverity.warning,
              message:
                  'Multiple enabled AC voltage sources are tagged ${phase.name}.',
              sourceId: source.id,
              phase: phase,
            ),
          );
        }
        final double angleDeg = _defaultPhaseDegrees(phase);
        elements.add(
          _Ac3Element(
            id: 'source:${source.id.value}:${phase.name}',
            modelType: source.modelType,
            kind: _Ac3ElementKind.idealVoltage,
            branchKind: Ac3BranchKind.voltageSource,
            fromNodeId: topology.terminalToNode[terminal.id]!,
            toNodeId: neutralNode,
            value: AcComplex.polar(magnitude, angleDeg * math.pi / 180.0),
            phase: phase,
            isSource: true,
          ),
        );
      }
      continue;
    }

    if (source.terminals.length != 2) {
      diagnostics.add(
        Ac3SolverDiagnostic(
          code: Ac3DiagnosticCode.invalidTerminalCount,
          severity: Ac3DiagnosticSeverity.error,
          message:
              'AC3 source ${source.id.value} must expose exactly two terminals.',
          sourceId: source.id,
        ),
      );
      continue;
    }
    final int phaseTerminalIndex = source.terminals.indexWhere(
      (Terminal terminal) => _isLinePhase(terminal.phase),
    );
    if (phaseTerminalIndex < 0) {
      diagnostics.add(
        Ac3SolverDiagnostic(
          code: Ac3DiagnosticCode.missingSourcePhaseTag,
          severity: Ac3DiagnosticSeverity.error,
          message:
              'AC3 source ${source.id.value} must identify L1, L2 or L3 on a terminal.',
          sourceId: source.id,
        ),
      );
      continue;
    }
    final PhaseTag phase = source.terminals[phaseTerminalIndex].phase;
    sourcePhases.add(phase);
    final int returnTerminalIndex = phaseTerminalIndex == 0 ? 1 : 0;
    final String fromNode =
        topology.terminalToNode[source.terminals[phaseTerminalIndex].id]!;
    final String toNode =
        topology.terminalToNode[source.terminals[returnTerminalIndex].id]!;
    switch (source.modelType) {
      case 'ac_voltage_source':
        if (!voltageSourcePhases.add(phase)) {
          diagnostics.add(
            Ac3SolverDiagnostic(
              code: Ac3DiagnosticCode.duplicatePhaseSource,
              severity: Ac3DiagnosticSeverity.warning,
              message:
                  'Multiple enabled AC voltage sources are tagged ${phase.name}.',
              sourceId: source.id,
              phase: phase,
            ),
          );
        }
        final AcComplex? phasor = _phasorParameter(
          source.parameters,
          magnitudeKey: 'voltageRmsV',
          defaultPhaseDeg: _defaultPhaseDegrees(phase),
          diagnostics: diagnostics,
          sourceId: source.id,
        );
        if (phasor != null) {
          elements.add(
            _Ac3Element(
              id: 'source:${source.id.value}',
              modelType: source.modelType,
              kind: _Ac3ElementKind.idealVoltage,
              branchKind: Ac3BranchKind.voltageSource,
              fromNodeId: fromNode,
              toNodeId: toNode,
              value: phasor,
              phase: phase,
              isSource: true,
            ),
          );
        }
      case 'ac_current_source':
        final AcComplex? phasor = _phasorParameter(
          source.parameters,
          magnitudeKey: 'currentRmsA',
          defaultPhaseDeg: _defaultPhaseDegrees(phase),
          diagnostics: diagnostics,
          sourceId: source.id,
        );
        if (phasor != null) {
          elements.add(
            _Ac3Element(
              id: 'source:${source.id.value}',
              modelType: source.modelType,
              kind: _Ac3ElementKind.currentSource,
              branchKind: Ac3BranchKind.currentSource,
              fromNodeId: fromNode,
              toNodeId: toNode,
              value: phasor,
              phase: phase,
              isSource: true,
            ),
          );
        }
      default:
        diagnostics.add(
          Ac3SolverDiagnostic(
            code: Ac3DiagnosticCode.unsupportedSourceModel,
            severity: Ac3DiagnosticSeverity.error,
            message: 'Unsupported AC3 source model ${source.modelType}.',
            sourceId: source.id,
          ),
        );
    }
  }

  return _CompiledAc3Model(
    elements,
    probes,
    sourcePhases,
    diagnostics.any(_isError),
  );
}

bool _compileFeedThroughAc3({
  required ComponentInstance component,
  required List<TopologyBranch> branches,
  required List<_Ac3Element> elements,
  required List<Ac3SolverDiagnostic> diagnostics,
}) {
  final ComponentPhysicsContract physics =
      CoreComponentPhysicsContracts.resolveComponent(component);
  if (physics.electricalLaw != ComponentElectricalLaw.feedThrough) {
    return false;
  }
  final ComponentModelContract? structural =
      CoreComponentModelContracts.registry.resolve(component.modelType);
  final int expectedBranches = structural?.branches.length ?? branches.length;
  if (branches.length != expectedBranches) {
    diagnostics.add(
      Ac3SolverDiagnostic(
        code: Ac3DiagnosticCode.invalidTerminalCount,
        severity: Ac3DiagnosticSeverity.error,
        message:
            '${component.modelType} must expose exactly $expectedBranches canonical feed-through branches.',
        componentId: component.id,
      ),
    );
    return true;
  }
  final bool open =
      component.condition == ComponentCondition.openCircuit ||
      component.condition == ComponentCondition.disabled;
  for (final TopologyBranch branch in branches) {
    elements.add(
      _Ac3Element(
        id: _componentBranchElementIdAc3(component, branch, branches.length),
        modelType: component.modelType,
        kind: open ? _Ac3ElementKind.impedance : _Ac3ElementKind.idealVoltage,
        branchKind: open ? Ac3BranchKind.openCircuit : Ac3BranchKind.idealShort,
        fromNodeId: branch.fromNodeId,
        toNodeId: branch.toNodeId,
        value: open ? const AcComplex(1e300, 0.0) : AcComplex.zero,
        isOpen: open,
        phase: _phaseForBranch(component, branch),
      ),
    );
  }
  return true;
}

bool _compileMultipoleSwitchAc3({
  required ComponentInstance component,
  required List<TopologyBranch> branches,
  required List<_Ac3Element> elements,
  required List<Ac3SolverDiagnostic> diagnostics,
}) {
  final ComponentPhysicsContract physics =
      CoreComponentPhysicsContracts.resolveComponent(component);
  if (physics.electricalLaw != ComponentElectricalLaw.binarySwitch ||
      physics.controlLaw != ComponentControlLaw.maintainedSwitch) {
    return false;
  }
  final ComponentModelContract? structural =
      CoreComponentModelContracts.registry.resolve(component.modelType);
  final int expectedPoles =
      structural?.branches
          .where(
            (ComponentBranchDefinition branch) =>
                branch.role == ElectricalBranchRole.powerPole,
          )
          .length ??
      0;
  if (expectedPoles <= 1) return false;
  if (branches.length != expectedPoles ||
      branches.any(
        (TopologyBranch branch) =>
            branch.role != ElectricalBranchRole.powerPole,
      )) {
    diagnostics.add(
      Ac3SolverDiagnostic(
        code: Ac3DiagnosticCode.invalidTerminalCount,
        severity: Ac3DiagnosticSeverity.error,
        message:
            '${component.modelType} must expose exactly $expectedPoles canonical power poles.',
        componentId: component.id,
      ),
    );
    return true;
  }

  final Object? rawClosed = component.controlState['closed'];
  if (rawClosed != null && rawClosed is! bool) {
    diagnostics.add(
      Ac3SolverDiagnostic(
        code: Ac3DiagnosticCode.invalidParameter,
        severity: Ac3DiagnosticSeverity.error,
        message:
            'Canonical multipole switch controlState.closed must be boolean.',
        componentId: component.id,
      ),
    );
    return true;
  }
  final bool forcedOpen =
      component.condition == ComponentCondition.openCircuit ||
      component.condition == ComponentCondition.disabled;
  final bool closed = (rawClosed as bool?) ?? true;
  final bool conducting = !forcedOpen && closed;

  for (final TopologyBranch branch in branches) {
    elements.add(
      _Ac3Element(
        id: _componentBranchElementIdAc3(component, branch, branches.length),
        modelType: component.modelType,
        kind: conducting
            ? _Ac3ElementKind.idealVoltage
            : _Ac3ElementKind.impedance,
        branchKind: conducting
            ? Ac3BranchKind.idealSwitch
            : Ac3BranchKind.openCircuit,
        fromNodeId: branch.fromNodeId,
        toNodeId: branch.toNodeId,
        value: conducting ? AcComplex.zero : const AcComplex(1e300, 0.0),
        isOpen: !conducting,
        phase: _phaseForBranch(component, branch),
      ),
    );
  }
  return true;
}

bool _compileThreePhaseImpedanceDeviceAc3({
  required ComponentInstance component,
  required List<TopologyBranch> branches,
  required double frequencyHz,
  required List<_Ac3Element> elements,
  required List<Ac3SolverDiagnostic> diagnostics,
}) {
  final ComponentPhysicsContract physics =
      CoreComponentPhysicsContracts.resolveComponent(component);
  final bool supported =
      physics.electricalLaw == ComponentElectricalLaw.motorThreePhase ||
      physics.electricalLaw == ComponentElectricalLaw.loadWyeThreePhase ||
      physics.electricalLaw == ComponentElectricalLaw.loadDeltaThreePhase;
  if (!supported) return false;

  final ComponentModelContract? structural =
      CoreComponentModelContracts.registry.resolve(component.modelType);
  final int expectedBranches = structural?.branches.length ?? 3;
  if (branches.length != expectedBranches) {
    diagnostics.add(
      Ac3SolverDiagnostic(
        code: Ac3DiagnosticCode.invalidTerminalCount,
        severity: Ac3DiagnosticSeverity.error,
        message:
            '${component.modelType} must expose exactly $expectedBranches canonical electrical branches.',
        componentId: component.id,
      ),
    );
    return true;
  }

  if (component.condition != ComponentCondition.normal &&
      component.condition != ComponentCondition.openCircuit &&
      component.condition != ComponentCondition.shortCircuit &&
      component.condition != ComponentCondition.disabled) {
    diagnostics.add(
      Ac3SolverDiagnostic(
        code: Ac3DiagnosticCode.unsupportedComponentCondition,
        severity: Ac3DiagnosticSeverity.error,
        message:
            'Unsupported AC3 three-phase device condition ${component.condition.name}.',
        componentId: component.id,
      ),
    );
    return true;
  }

  final double? resistance = _positiveParameter(
    component.parameters,
    ComponentParameterKeys.resistanceOhm,
  );
  final Object? rawInductance =
      component.parameters[ComponentParameterKeys.inductanceH];
  final double inductance = rawInductance == null
      ? 0.0
      : rawInductance is num
      ? rawInductance.toDouble()
      : double.nan;
  if (resistance == null || !inductance.isFinite || inductance < 0.0) {
    diagnostics.add(
      Ac3SolverDiagnostic(
        code: Ac3DiagnosticCode.invalidParameter,
        severity: Ac3DiagnosticSeverity.error,
        message:
            '${component.modelType} requires canonical resistance > 0 and optional inductance >= 0.',
        componentId: component.id,
      ),
    );
    return true;
  }

  final bool open =
      component.condition == ComponentCondition.openCircuit ||
      component.condition == ComponentCondition.disabled;
  final bool shorted = component.condition == ComponentCondition.shortCircuit;
  final AcComplex impedance = AcComplex(
    resistance,
    2.0 * math.pi * frequencyHz * inductance,
  );

  for (final TopologyBranch branch in branches) {
    final String id = _componentBranchElementIdAc3(
      component,
      branch,
      branches.length,
    );
    if (open) {
      elements.add(
        _Ac3Element(
          id: id,
          modelType: component.modelType,
          kind: _Ac3ElementKind.impedance,
          branchKind: Ac3BranchKind.openCircuit,
          fromNodeId: branch.fromNodeId,
          toNodeId: branch.toNodeId,
          value: const AcComplex(1e300, 0.0),
          isOpen: true,
          phase: _phaseForBranch(component, branch),
        ),
      );
      continue;
    }
    if (shorted) {
      elements.add(
        _Ac3Element(
          id: id,
          modelType: component.modelType,
          kind: _Ac3ElementKind.idealVoltage,
          branchKind: Ac3BranchKind.idealShort,
          fromNodeId: branch.fromNodeId,
          toNodeId: branch.toNodeId,
          value: AcComplex.zero,
          phase: _phaseForBranch(component, branch),
        ),
      );
      continue;
    }
    elements.add(
      _Ac3Element(
        id: id,
        modelType: component.modelType,
        kind: _Ac3ElementKind.impedance,
        branchKind: Ac3BranchKind.impedance,
        fromNodeId: branch.fromNodeId,
        toNodeId: branch.toNodeId,
        value: impedance,
        phase: _phaseForBranch(component, branch),
      ),
    );
  }
  return true;
}

bool _compileThreePoleProtectionAc3({
  required ComponentInstance component,
  required List<TopologyBranch> branches,
  required List<_Ac3Element> elements,
  required List<Ac3SolverDiagnostic> diagnostics,
}) {
  final ComponentPhysicsContract physics =
      CoreComponentPhysicsContracts.resolveComponent(component);
  if (physics.electricalLaw != ComponentElectricalLaw.protectionSwitch) {
    return false;
  }

  final ComponentModelContract? structural =
      CoreComponentModelContracts.registry.resolve(component.modelType);
  final int expectedPoles =
      structural?.branches
          .where(
            (ComponentBranchDefinition branch) =>
                branch.role == ElectricalBranchRole.powerPole,
          )
          .length ??
      0;
  if (expectedPoles <= 1) return false;
  if (branches.length != expectedPoles ||
      branches.any(
        (TopologyBranch branch) =>
            branch.role != ElectricalBranchRole.powerPole,
      )) {
    diagnostics.add(
      Ac3SolverDiagnostic(
        code: Ac3DiagnosticCode.invalidTerminalCount,
        severity: Ac3DiagnosticSeverity.error,
        message:
            '${component.modelType} must expose exactly $expectedPoles canonical power poles.',
        componentId: component.id,
      ),
    );
    return true;
  }

  final Object? rawRating =
      component.parameters[ProtectionRating.ratedCurrentKey];
  if (rawRating is! num ||
      !rawRating.toDouble().isFinite ||
      rawRating.toDouble() <= 0.0) {
    diagnostics.add(
      Ac3SolverDiagnostic(
        code: Ac3DiagnosticCode.invalidParameter,
        severity: Ac3DiagnosticSeverity.error,
        message:
            '${component.modelType} requires finite ${ProtectionRating.ratedCurrentKey} > 0.',
        componentId: component.id,
      ),
    );
    return true;
  }

  final Object? rawClosed = component.controlState['closed'];
  final Object? rawTripped = component.controlState['tripped'];
  if ((rawClosed != null && rawClosed is! bool) ||
      (rawTripped != null && rawTripped is! bool)) {
    diagnostics.add(
      Ac3SolverDiagnostic(
        code: Ac3DiagnosticCode.invalidParameter,
        severity: Ac3DiagnosticSeverity.error,
        message:
            'AC3 protection controlState.closed/tripped must be boolean when provided.',
        componentId: component.id,
      ),
    );
    return true;
  }

  if (component.condition != ComponentCondition.normal &&
      component.condition != ComponentCondition.openCircuit &&
      component.condition != ComponentCondition.disabled) {
    diagnostics.add(
      Ac3SolverDiagnostic(
        code: Ac3DiagnosticCode.unsupportedComponentCondition,
        severity: Ac3DiagnosticSeverity.error,
        message:
            'Unsupported AC3 protection condition ${component.condition.name}.',
        componentId: component.id,
      ),
    );
    return true;
  }

  final bool closed = (rawClosed as bool?) ?? true;
  final bool tripped = (rawTripped as bool?) ?? false;
  final bool conducting =
      component.condition == ComponentCondition.normal && closed && !tripped;

  for (final TopologyBranch branch in branches) {
    elements.add(
      _Ac3Element(
        id: _componentBranchElementIdAc3(component, branch, branches.length),
        modelType: component.modelType,
        kind: conducting
            ? _Ac3ElementKind.idealVoltage
            : _Ac3ElementKind.impedance,
        branchKind: conducting
            ? Ac3BranchKind.idealProtection
            : Ac3BranchKind.openCircuit,
        fromNodeId: branch.fromNodeId,
        toNodeId: branch.toNodeId,
        value: conducting ? AcComplex.zero : const AcComplex(1e300, 0.0),
        isOpen: !conducting,
        phase: _phaseForBranch(component, branch),
      ),
    );
  }
  return true;
}

bool _compileElectromechanicalAc3({
  required ComponentInstance component,
  required List<TopologyBranch> branches,
  required double frequencyHz,
  required List<_Ac3Element> elements,
  required List<Ac3SolverDiagnostic> diagnostics,
}) {
  final ComponentPhysicsContract physics =
      CoreComponentPhysicsContracts.resolveComponent(component);
  final bool isPowerContactor =
      physics.controlLaw == ComponentControlLaw.electromagneticCoil &&
      branches.any(
        (TopologyBranch branch) =>
            branch.role == ElectricalBranchRole.controlCoil,
      ) &&
      branches.any(
        (TopologyBranch branch) =>
            branch.role == ElectricalBranchRole.powerPole,
      );
  final bool isAuxNo =
      physics.controlLaw == ComponentControlLaw.relayNormallyOpen;
  final bool isAuxNc =
      physics.controlLaw == ComponentControlLaw.relayNormallyClosed;
  if (!isPowerContactor && !isAuxNo && !isAuxNc) {
    return false;
  }

  final Object? rawActuated = component.controlState['actuated'];
  if (rawActuated != null && rawActuated is! bool) {
    diagnostics.add(
      Ac3SolverDiagnostic(
        code: Ac3DiagnosticCode.invalidParameter,
        severity: Ac3DiagnosticSeverity.error,
        message:
            'Electromechanical controlState.actuated must be boolean when provided.',
        componentId: component.id,
      ),
    );
    return true;
  }
  final bool actuated = (rawActuated as bool?) ?? false;

  if (component.condition != ComponentCondition.normal &&
      component.condition != ComponentCondition.openCircuit &&
      component.condition != ComponentCondition.disabled) {
    diagnostics.add(
      Ac3SolverDiagnostic(
        code: Ac3DiagnosticCode.unsupportedComponentCondition,
        severity: Ac3DiagnosticSeverity.error,
        message:
            'Unsupported AC3 electromechanical condition ${component.condition.name}.',
        componentId: component.id,
      ),
    );
    return true;
  }

  if (isAuxNo || isAuxNc) {
    if (branches.length != 1) {
      diagnostics.add(
        Ac3SolverDiagnostic(
          code: Ac3DiagnosticCode.invalidTerminalCount,
          severity: Ac3DiagnosticSeverity.error,
          message:
              'Auxiliary contact ${component.id.value} must expose one topology branch.',
          componentId: component.id,
        ),
      );
      return true;
    }
    final TopologyBranch branch = branches.single;
    final bool forcedOpen =
        component.condition == ComponentCondition.openCircuit ||
        component.condition == ComponentCondition.disabled;
    final bool closed = !forcedOpen && (isAuxNo ? actuated : !actuated);
    elements.add(
      _Ac3Element(
        id: _componentBranchElementIdAc3(component, branch, branches.length),
        modelType: component.modelType,
        kind: closed ? _Ac3ElementKind.idealVoltage : _Ac3ElementKind.impedance,
        branchKind: Ac3BranchKind.contactorContact,
        fromNodeId: branch.fromNodeId,
        toNodeId: branch.toNodeId,
        value: closed ? AcComplex.zero : const AcComplex(1e300, 0.0),
        isOpen: !closed,
        phase: _phaseForBranch(component, branch),
      ),
    );
    return true;
  }

  final TopologyBranch? coil = _branchWithRoleAc3(
    branches,
    ElectricalBranchRole.controlCoil,
  );
  final List<TopologyBranch> powerPoles = branches
      .where(
        (TopologyBranch branch) =>
            branch.role == ElectricalBranchRole.powerPole,
      )
      .toList(growable: false);
  final ComponentModelContract? structural =
      CoreComponentModelContracts.registry.resolve(component.modelType);
  final int expectedPowerPoles =
      structural?.branches
          .where(
            (ComponentBranchDefinition branch) =>
                branch.role == ElectricalBranchRole.powerPole,
          )
          .length ??
      powerPoles.length;
  if (coil == null ||
      powerPoles.length != expectedPowerPoles ||
      branches.length != expectedPowerPoles + 1) {
    diagnostics.add(
      Ac3SolverDiagnostic(
        code: Ac3DiagnosticCode.invalidTerminalCount,
        severity: Ac3DiagnosticSeverity.error,
        message:
            'Electromagnetic AC3 component must expose its canonical power poles and one control coil.',
        componentId: component.id,
      ),
    );
    return true;
  }

  final double? coilResistance = _positiveParameter(
    component.parameters,
    ComponentParameterKeys.coilResistanceOhm,
  );
  final Object? inductanceRaw =
      component.parameters[ComponentParameterKeys.coilInductanceH];
  final double coilInductance = inductanceRaw == null
      ? 0.0
      : inductanceRaw is num
      ? inductanceRaw.toDouble()
      : double.nan;
  if (coilResistance == null ||
      !coilInductance.isFinite ||
      coilInductance < 0.0) {
    diagnostics.add(
      Ac3SolverDiagnostic(
        code: Ac3DiagnosticCode.invalidParameter,
        severity: Ac3DiagnosticSeverity.error,
        message:
            'Electromagnetic AC3 component requires canonical coil resistance > 0 and optional coil inductance >= 0.',
        componentId: component.id,
      ),
    );
    return true;
  }

  final bool forcedOpen =
      component.condition == ComponentCondition.openCircuit ||
      component.condition == ComponentCondition.disabled;
  final double omega = 2.0 * math.pi * frequencyHz;
  elements.add(
    _Ac3Element(
      id: _componentBranchElementIdAc3(component, coil, branches.length),
      modelType: component.modelType,
      kind: _Ac3ElementKind.impedance,
      branchKind: Ac3BranchKind.controlCoil,
      fromNodeId: coil.fromNodeId,
      toNodeId: coil.toNodeId,
      value: forcedOpen
          ? const AcComplex(1e300, 0.0)
          : AcComplex(coilResistance, omega * coilInductance),
      isOpen: forcedOpen,
      phase: _phaseForBranch(component, coil),
    ),
  );

  for (final TopologyBranch pole in powerPoles) {
    final bool poleClosed = actuated && !forcedOpen;
    elements.add(
      _Ac3Element(
        id: _componentBranchElementIdAc3(component, pole, branches.length),
        modelType: component.modelType,
        kind: poleClosed
            ? _Ac3ElementKind.idealVoltage
            : _Ac3ElementKind.impedance,
        branchKind: Ac3BranchKind.contactorContact,
        fromNodeId: pole.fromNodeId,
        toNodeId: pole.toNodeId,
        value: poleClosed ? AcComplex.zero : const AcComplex(1e300, 0.0),
        isOpen: !poleClosed,
        phase: _phaseForBranch(component, pole),
      ),
    );
  }
  return true;
}

TopologyBranch? _branchWithRoleAc3(
  Iterable<TopologyBranch> branches,
  ElectricalBranchRole role,
) {
  for (final TopologyBranch branch in branches) {
    if (branch.role == role) return branch;
  }
  return null;
}

PhaseTag? _phaseForBranch(ComponentInstance component, TopologyBranch branch) {
  final List<Terminal> terminals = component.terminals
      .where(
        (Terminal terminal) =>
            terminal.id == branch.fromTerminalId ||
            terminal.id == branch.toTerminalId,
      )
      .toList(growable: false);
  return _singlePhase(terminals);
}

String _componentBranchElementIdAc3(
  ComponentInstance component,
  TopologyBranch branch,
  int branchCount,
) => branchCount == 1
    ? 'component:${component.id.value}'
    : 'component:${component.id.value}:${branch.branchId}';

bool? _closedFromControlLawAc3(
  ComponentInstance component,
  ComponentControlLaw controlLaw,
) {
  switch (controlLaw) {
    case ComponentControlLaw.maintainedSwitch:
      final Object? rawClosed = component.controlState['closed'];
      return rawClosed is bool ? rawClosed : null;
    case ComponentControlLaw.momentaryNormallyOpen:
      final Object? rawPressed = component.controlState['pressed'];
      return rawPressed is bool ? rawPressed : null;
    case ComponentControlLaw.momentaryNormallyClosed:
      final Object? rawPressed = component.controlState['pressed'];
      return rawPressed is bool ? !rawPressed : null;
    case ComponentControlLaw.relayNormallyOpen:
      final Object? rawActuated = component.controlState['actuated'];
      return rawActuated is bool ? rawActuated : null;
    case ComponentControlLaw.relayNormallyClosed:
      final Object? rawActuated = component.controlState['actuated'];
      return rawActuated is bool ? !rawActuated : null;
    case ComponentControlLaw.none:
    case ComponentControlLaw.electromagneticCoil:
    case ComponentControlLaw.protection:
      return null;
  }
}

AcComplex? _componentImpedance(
  ComponentInstance component,
  ComponentPhysicsContract physics,
  double frequencyHz,
  List<Ac3SolverDiagnostic> diagnostics,
) {
  final double omega = 2.0 * math.pi * frequencyHz;

  AcComplex? invalid() {
    diagnostics.add(
      Ac3SolverDiagnostic(
        code: Ac3DiagnosticCode.invalidParameter,
        severity: Ac3DiagnosticSeverity.error,
        message:
            'Invalid canonical parameters for AC3 component ${component.id.value}.',
        componentId: component.id,
      ),
    );
    return null;
  }

  switch (physics.electricalLaw) {
    case ComponentElectricalLaw.resistive:
      final double? resistance = _positiveParameter(
        component.parameters,
        ComponentParameterKeys.resistanceOhm,
      );
      return resistance == null ? invalid() : AcComplex.real(resistance);
    case ComponentElectricalLaw.inductor:
      final double? inductance = _positiveParameter(
        component.parameters,
        ComponentParameterKeys.inductanceH,
      );
      return inductance == null
          ? invalid()
          : AcComplex(0.0, omega * inductance);
    case ComponentElectricalLaw.capacitor:
      final double? capacitance = _positiveParameter(
        component.parameters,
        ComponentParameterKeys.capacitanceF,
      );
      return capacitance == null
          ? invalid()
          : AcComplex(0.0, -1.0 / (omega * capacitance));
    case ComponentElectricalLaw.acImpedance:
      final Object? rRaw =
          component.parameters[ComponentParameterKeys.resistanceOhm];
      final Object? xRaw =
          component.parameters[ComponentParameterKeys.reactanceOhm];
      if (rRaw is num && xRaw is num) {
        final double resistance = rRaw.toDouble();
        final double reactance = xRaw.toDouble();
        if (resistance.isFinite &&
            reactance.isFinite &&
            resistance >= 0.0 &&
            (resistance != 0.0 || reactance != 0.0)) {
          return AcComplex(resistance, reactance);
        }
      }
      return invalid();
    case ComponentElectricalLaw.binarySwitch:
    case ComponentElectricalLaw.protectionSwitch:
    case ComponentElectricalLaw.feedThrough:
    case ComponentElectricalLaw.diode:
    case ComponentElectricalLaw.motorDc:
      case ComponentElectricalLaw.motorThreePhase:
    case ComponentElectricalLaw.loadWyeThreePhase:
    case ComponentElectricalLaw.loadDeltaThreePhase:
    case ComponentElectricalLaw.converter:
    case ComponentElectricalLaw.storage:
    case ComponentElectricalLaw.unsupported:
      diagnostics.add(
        Ac3SolverDiagnostic(
          code: Ac3DiagnosticCode.unsupportedComponentModel,
          severity: Ac3DiagnosticSeverity.error,
          message:
              'Electrical law ${physics.electricalLaw.name} has no AC3 single-branch impedance representation.',
          componentId: component.id,
        ),
      );
      return null;
  }
}

double? _positiveParameter(Map<String, Object?> parameters, String key) {
  final Object? raw = parameters[key];
  if (raw is! num) {
    return null;
  }
  final double value = raw.toDouble();
  return value.isFinite && value > 0.0 ? value : null;
}

AcComplex? _phasorParameter(
  Map<String, Object?> parameters, {
  required String magnitudeKey,
  required double defaultPhaseDeg,
  required List<Ac3SolverDiagnostic> diagnostics,
  required SourceId sourceId,
}) {
  final Object? magnitudeRaw = parameters[magnitudeKey];
  final Object? phaseRaw = parameters['phaseDeg'] ?? defaultPhaseDeg;
  if (magnitudeRaw is! num || phaseRaw is! num) {
    diagnostics.add(
      Ac3SolverDiagnostic(
        code: Ac3DiagnosticCode.invalidParameter,
        severity: Ac3DiagnosticSeverity.error,
        message: 'Invalid AC3 phasor parameters on source ${sourceId.value}.',
        sourceId: sourceId,
      ),
    );
    return null;
  }
  final double magnitude = magnitudeRaw.toDouble();
  final double phaseDeg = phaseRaw.toDouble();
  if (!magnitude.isFinite || magnitude < 0.0 || !phaseDeg.isFinite) {
    diagnostics.add(
      Ac3SolverDiagnostic(
        code: Ac3DiagnosticCode.invalidParameter,
        severity: Ac3DiagnosticSeverity.error,
        message:
            'AC3 phasor magnitude/phase must be finite and magnitude non-negative.',
        sourceId: sourceId,
      ),
    );
    return null;
  }
  return AcComplex.polar(magnitude, phaseDeg * math.pi / 180.0);
}

Ac3BranchKind _branchKindForPhysics(ComponentPhysicsContract physics) {
  switch (physics.electricalLaw) {
    case ComponentElectricalLaw.resistive:
      return Ac3BranchKind.resistor;
    case ComponentElectricalLaw.inductor:
      return Ac3BranchKind.inductor;
    case ComponentElectricalLaw.capacitor:
      return Ac3BranchKind.capacitor;
    case ComponentElectricalLaw.acImpedance:
    case ComponentElectricalLaw.binarySwitch:
    case ComponentElectricalLaw.protectionSwitch:
    case ComponentElectricalLaw.feedThrough:
    case ComponentElectricalLaw.diode:
    case ComponentElectricalLaw.motorDc:
      case ComponentElectricalLaw.motorThreePhase:
    case ComponentElectricalLaw.loadWyeThreePhase:
    case ComponentElectricalLaw.loadDeltaThreePhase:
    case ComponentElectricalLaw.converter:
    case ComponentElectricalLaw.storage:
    case ComponentElectricalLaw.unsupported:
      return Ac3BranchKind.impedance;
  }
}

PhaseTag? _singlePhase(Iterable<Terminal> terminals) {
  final Set<PhaseTag> phases = terminals
      .map((Terminal terminal) => terminal.phase)
      .where(_isLinePhase)
      .toSet();
  return phases.length == 1 ? phases.single : null;
}

bool _isLinePhase(PhaseTag phase) =>
    phase == PhaseTag.l1 || phase == PhaseTag.l2 || phase == PhaseTag.l3;

double _defaultPhaseDegrees(PhaseTag phase) {
  switch (phase) {
    case PhaseTag.l1:
      return 0.0;
    case PhaseTag.l2:
      return -120.0;
    case PhaseTag.l3:
      return 120.0;
    default:
      return 0.0;
  }
}

String _selectReferenceNode(CircuitState circuit, TopologyGraph topology) {
  for (final SourceInstance source in circuit.sources) {
    for (final Terminal terminal in source.terminals) {
      if (terminal.phase == PhaseTag.neutral ||
          terminal.role == TerminalRole.neutral) {
        final String? node = topology.terminalToNode[terminal.id];
        if (node != null) {
          return node;
        }
      }
    }
  }
  final List<String> ids =
      topology.nodes.map((TopologyNode node) => node.id).toList(growable: false)
        ..sort();
  return ids.first;
}

bool _neutralConnected(
  CircuitState circuit,
  TopologyGraph topology,
  String referenceNodeId,
) {
  for (final ComponentInstance component in circuit.components) {
    for (final Terminal terminal in component.terminals) {
      if ((terminal.phase == PhaseTag.neutral ||
              terminal.role == TerminalRole.neutral) &&
          topology.terminalToNode[terminal.id] == referenceNodeId) {
        return true;
      }
    }
  }
  return false;
}

List<String> _findFloatingNodes(
  Iterable<String> allNodes,
  String referenceNodeId,
  Iterable<_Ac3Element> elements,
) {
  final Map<String, Set<String>> adjacency = <String, Set<String>>{
    for (final String node in allNodes) node: <String>{},
  };
  for (final _Ac3Element element in elements) {
    if (element.isOpen) {
      continue;
    }
    adjacency[element.fromNodeId]!.add(element.toNodeId);
    adjacency[element.toNodeId]!.add(element.fromNodeId);
  }
  final Set<String> reached = <String>{referenceNodeId};
  final List<String> pending = <String>[referenceNodeId];
  while (pending.isNotEmpty) {
    final String current = pending.removeLast();
    for (final String next in adjacency[current]!) {
      if (reached.add(next)) {
        pending.add(next);
      }
    }
  }
  final List<String> result =
      adjacency.keys
          .where((String node) => !reached.contains(node))
          .toList(growable: false)
        ..sort();
  return result;
}

void _stampAdmittance(
  List<List<AcComplex>> matrix,
  Map<String, int> nodeIndex,
  String referenceNode,
  String from,
  String to,
  AcComplex admittance,
) {
  final int? a = from == referenceNode ? null : nodeIndex[from];
  final int? b = to == referenceNode ? null : nodeIndex[to];
  if (a != null) {
    matrix[a][a] = matrix[a][a] + admittance;
  }
  if (b != null) {
    matrix[b][b] = matrix[b][b] + admittance;
  }
  if (a != null && b != null) {
    matrix[a][b] = matrix[a][b] - admittance;
    matrix[b][a] = matrix[b][a] - admittance;
  }
}

void _stampCurrentSource(
  List<AcComplex> rhs,
  Map<String, int> nodeIndex,
  String referenceNode,
  String from,
  String to,
  AcComplex current,
) {
  final int? a = from == referenceNode ? null : nodeIndex[from];
  final int? b = to == referenceNode ? null : nodeIndex[to];
  if (a != null) {
    rhs[a] = rhs[a] - current;
  }
  if (b != null) {
    rhs[b] = rhs[b] + current;
  }
}

void _stampIdealVoltage(
  List<List<AcComplex>> matrix,
  List<AcComplex> rhs,
  Map<String, int> nodeIndex,
  String referenceNode,
  int equationIndex,
  String from,
  String to,
  AcComplex voltage,
) {
  final int? a = from == referenceNode ? null : nodeIndex[from];
  final int? b = to == referenceNode ? null : nodeIndex[to];
  if (a != null) {
    matrix[a][equationIndex] = matrix[a][equationIndex] + AcComplex.one;
    matrix[equationIndex][a] = matrix[equationIndex][a] + AcComplex.one;
  }
  if (b != null) {
    matrix[b][equationIndex] = matrix[b][equationIndex] - AcComplex.one;
    matrix[equationIndex][b] = matrix[equationIndex][b] - AcComplex.one;
  }
  rhs[equationIndex] = rhs[equationIndex] + voltage;
}

_Ac3LinearSolveOutcome _solveLinearSystem(
  List<List<AcComplex>> matrix,
  List<AcComplex> rhs,
  double pivotTolerance,
) {
  final int n = rhs.length;
  if (n == 0) {
    return const _Ac3LinearSolveOutcome(<AcComplex>[]);
  }
  final List<List<AcComplex>> a = <List<AcComplex>>[
    for (var r = 0; r < n; r++) <AcComplex>[...matrix[r], rhs[r]],
  ];
  for (var col = 0; col < n; col++) {
    var pivot = col;
    var best = a[col][col].magnitude;
    for (var row = col + 1; row < n; row++) {
      final double candidate = a[row][col].magnitude;
      if (candidate > best) {
        best = candidate;
        pivot = row;
      }
    }
    if (!best.isFinite || best <= pivotTolerance) {
      return const _Ac3LinearSolveOutcome(null);
    }
    if (pivot != col) {
      final List<AcComplex> tmp = a[pivot];
      a[pivot] = a[col];
      a[col] = tmp;
    }
    final AcComplex pivotValue = a[col][col];
    for (var c = col; c <= n; c++) {
      a[col][c] = a[col][c] / pivotValue;
    }
    for (var row = 0; row < n; row++) {
      if (row == col) {
        continue;
      }
      final AcComplex factor = a[row][col];
      if (factor.magnitude <= pivotTolerance) {
        continue;
      }
      for (var c = col; c <= n; c++) {
        a[row][c] = a[row][c] - (factor * a[col][c]);
      }
    }
  }
  return _Ac3LinearSolveOutcome(<AcComplex>[
    for (var r = 0; r < n; r++) a[r][n],
  ]);
}

double _maxMatrixResidual(
  List<List<AcComplex>> matrix,
  List<AcComplex> solution,
  List<AcComplex> rhs,
) {
  var maximum = 0.0;
  for (var row = 0; row < rhs.length; row++) {
    var calculated = AcComplex.zero;
    for (var col = 0; col < solution.length; col++) {
      calculated = calculated + (matrix[row][col] * solution[col]);
    }
    maximum = math.max(maximum, (calculated - rhs[row]).magnitude);
  }
  return maximum;
}

Map<String, AcComplex> _lineToLine(Map<PhaseTag, AcComplex> phaseVoltages) {
  final Map<String, AcComplex> result = <String, AcComplex>{};
  final AcComplex? l1 = phaseVoltages[PhaseTag.l1];
  final AcComplex? l2 = phaseVoltages[PhaseTag.l2];
  final AcComplex? l3 = phaseVoltages[PhaseTag.l3];
  if (l1 != null && l2 != null) {
    result['L1-L2'] = l1 - l2;
  }
  if (l2 != null && l3 != null) {
    result['L2-L3'] = l2 - l3;
  }
  if (l3 != null && l1 != null) {
    result['L3-L1'] = l3 - l1;
  }
  return result;
}

Ac3PhaseSequence _sequence(List<AcComplex?> values, double toleranceDegrees) {
  if (values.length != 3 ||
      values.any(
        (AcComplex? value) => value == null || value.magnitude <= 1e-12,
      )) {
    return Ac3PhaseSequence.indeterminate;
  }
  final double d12 = _normalizeAngle(
    values[1]!.angleDegrees - values[0]!.angleDegrees,
  );
  final double d23 = _normalizeAngle(
    values[2]!.angleDegrees - values[1]!.angleDegrees,
  );
  if (_angleClose(d12, -120.0, toleranceDegrees) &&
      _angleClose(d23, -120.0, toleranceDegrees)) {
    return Ac3PhaseSequence.positive;
  }
  if (_angleClose(d12, 120.0, toleranceDegrees) &&
      _angleClose(d23, 120.0, toleranceDegrees)) {
    return Ac3PhaseSequence.negative;
  }
  return Ac3PhaseSequence.indeterminate;
}

double _normalizeAngle(double value) {
  var result = value % 360.0;
  if (result > 180.0) {
    result -= 360.0;
  }
  if (result <= -180.0) {
    result += 360.0;
  }
  return result;
}

bool _angleClose(double actual, double expected, double tolerance) =>
    _normalizeAngle(actual - expected).abs() <= tolerance;

bool _balancedMagnitudes(List<AcComplex?> values, double relativeTolerance) {
  if (values.length != 3 || values.any((AcComplex? value) => value == null)) {
    return false;
  }
  final List<double> magnitudes = values
      .cast<AcComplex>()
      .map((AcComplex value) => value.magnitude)
      .toList(growable: false);
  final double maximum = magnitudes.reduce(
    math.max,
  );
  final double minimum = magnitudes.reduce(
    math.min,
  );
  if (maximum <= 1e-15) {
    return true;
  }
  return (maximum - minimum) / maximum <= relativeTolerance;
}

bool _isError(Ac3SolverDiagnostic diagnostic) =>
    diagnostic.severity == Ac3DiagnosticSeverity.error;

Ac3SolveResult _failure(
  CircuitState circuit,
  Ac3SolveStatus status,
  List<Ac3SolverDiagnostic> diagnostics, {
  double? frequencyHz,
  String? referenceNodeId,
  Iterable<PhaseTag> missingPhases = const <PhaseTag>[],
}) => Ac3SolveResult(
  circuitId: circuit.circuitId,
  circuitRevision: circuit.revision,
  engineVersion: SolverAC3.engineVersion,
  status: status,
  frequencyHz: frequencyHz,
  referenceNodeId: referenceNodeId,
  nodeVoltages: const <String, AcComplex>{},
  branchResults: const <Ac3BranchResult>[],
  diagnostics: diagnostics,
  maxMatrixResidual: null,
  kclResiduals: const <String, double>{},
  phaseVoltages: const <PhaseTag, AcComplex>{},
  lineCurrents: const <PhaseTag, AcComplex>{},
  lineToLineVoltages: const <String, AcComplex>{},
  neutralCurrent: AcComplex.zero,
  missingPhases: missingPhases,
  sourceSequence: Ac3PhaseSequence.indeterminate,
  voltageBalanced: false,
  currentBalanced: false,
  neutralConnected: false,
  phaseOrderObservations: const <Ac3PhaseOrderObservation>[],
);

enum _Ac3ElementKind { impedance, currentSource, idealVoltage }

final class _Ac3Element {
  const _Ac3Element({
    required this.id,
    required this.modelType,
    required this.kind,
    required this.branchKind,
    required this.fromNodeId,
    required this.toNodeId,
    required this.value,
    this.isOpen = false,
    this.phase,
    this.isSource = false,
  });

  final String id;
  final String modelType;
  final _Ac3ElementKind kind;
  final Ac3BranchKind branchKind;
  final String fromNodeId;
  final String toNodeId;
  final AcComplex value;
  final bool isOpen;
  final PhaseTag? phase;
  final bool isSource;
}

final class _Ac3Probe {
  const _Ac3Probe(this.componentId, this.nodeIds);

  final ComponentId componentId;
  final List<String> nodeIds;
}

final class _CompiledAc3Model {
  const _CompiledAc3Model(
    this.allElements,
    this.probes,
    this.presentSourcePhases,
    this.hasErrors,
  );

  final List<_Ac3Element> allElements;
  final List<_Ac3Probe> probes;
  final Set<PhaseTag> presentSourcePhases;
  final bool hasErrors;

  Iterable<_Ac3Element> get activeElements =>
      allElements.where((_Ac3Element element) => !element.isOpen);
}

final class _Ac3LinearSolveOutcome {
  const _Ac3LinearSolveOutcome(this.solution);

  final List<AcComplex>? solution;
}
