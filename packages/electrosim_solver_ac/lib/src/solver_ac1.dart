import 'dart:math' as math;

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_topology/electrosim_topology.dart';

import 'ac1_complex.dart';
import 'ac1_diagnostic.dart';
import 'ac1_result.dart';
import 'ac1_solver_options.dart';

final class SolverAC1 {
  const SolverAC1({this.options = const Ac1SolverOptions()});

  static const String engineVersion = 'solver-ac1/0.3.2';

  final Ac1SolverOptions options;

  Ac1SolveResult solve(CircuitState circuit, TopologyGraph topology) {
    final List<Ac1SolverDiagnostic> diagnostics = <Ac1SolverDiagnostic>[];
    if (circuit.mode != ElectricalMode.ac1 ||
        topology.mode != ElectricalMode.ac1) {
      diagnostics.add(
        Ac1SolverDiagnostic(
          code: Ac1DiagnosticCode.wrongElectricalMode,
          severity: Ac1DiagnosticSeverity.error,
          message: 'SolverAC1 accepts AC single-phase circuits only.',
        ),
      );
      return _failure(circuit, Ac1SolveStatus.invalid, diagnostics);
    }
    if (circuit.circuitId != topology.circuitId ||
        circuit.revision != topology.circuitRevision) {
      diagnostics.add(
        Ac1SolverDiagnostic(
          code: Ac1DiagnosticCode.topologyIdentityMismatch,
          severity: Ac1DiagnosticSeverity.error,
          message:
              'TopologyGraph does not match the CircuitState identity/revision.',
        ),
      );
      return _failure(circuit, Ac1SolveStatus.invalid, diagnostics);
    }
    if (topology.nodes.isEmpty) {
      diagnostics.add(
        Ac1SolverDiagnostic(
          code: Ac1DiagnosticCode.emptyCircuit,
          severity: Ac1DiagnosticSeverity.error,
          message: 'AC1 circuit contains no electrical nodes.',
        ),
      );
      return _failure(circuit, Ac1SolveStatus.invalid, diagnostics);
    }

    for (final TopologyFinding finding in topology.findings) {
      if (finding.severity == TopologyFindingSeverity.error) {
        diagnostics.add(
          Ac1SolverDiagnostic(
            code: Ac1DiagnosticCode.topologyError,
            severity: Ac1DiagnosticSeverity.error,
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
        Ac1SolveStatus.invalid,
        diagnostics,
        frequencyHz: frequencyHz,
      );
    }

    final _CompiledAc1Model compiled = _compileModel(
      circuit,
      topology,
      frequencyHz,
      diagnostics,
    );
    if (compiled.hasErrors || diagnostics.any(_isError)) {
      return _failure(
        circuit,
        Ac1SolveStatus.invalid,
        diagnostics,
        frequencyHz: frequencyHz,
      );
    }

    final String referenceNodeId = _selectReferenceNode(circuit, topology);
    final Set<String> participatingNodes = _participatingAc1Nodes(
      compiled.activeElements,
    )..add(referenceNodeId);
    final List<String> floatingNodes = _findFloatingNodes(
      participatingNodes,
      referenceNodeId,
      compiled.activeElements,
    );
    if (floatingNodes.isNotEmpty) {
      diagnostics.add(
        Ac1SolverDiagnostic(
          code: Ac1DiagnosticCode.floatingElectricalIsland,
          severity: Ac1DiagnosticSeverity.error,
          message: 'Electrical island is not connected to the reference node.',
          nodeIds: floatingNodes,
        ),
      );
      return _failure(
        circuit,
        Ac1SolveStatus.singular,
        diagnostics,
        frequencyHz: frequencyHz,
        referenceNodeId: referenceNodeId,
      );
    }

    final List<String> unknownNodes =
        participatingNodes
            .where((String nodeId) => nodeId != referenceNodeId)
            .toList(growable: false)
          ..sort();
    final Map<String, int> nodeIndex = <String, int>{
      for (var i = 0; i < unknownNodes.length; i++) unknownNodes[i]: i,
    };
    final List<_Ac1Element> idealConstraints =
        compiled.activeElements
            .where(
              (_Ac1Element element) =>
                  element.kind == _Ac1ElementKind.idealVoltage,
            )
            .toList(growable: false)
          ..sort((_Ac1Element a, _Ac1Element b) => a.id.compareTo(b.id));
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

    for (final _Ac1Element element in compiled.activeElements) {
      switch (element.kind) {
        case _Ac1ElementKind.impedance:
          final AcComplex admittance = AcComplex.one / element.value;
          _stampAdmittance(
            matrix,
            nodeIndex,
            referenceNodeId,
            element.fromNodeId,
            element.toNodeId,
            admittance,
          );
        case _Ac1ElementKind.currentSource:
          _stampCurrentSource(
            rhs,
            nodeIndex,
            referenceNodeId,
            element.fromNodeId,
            element.toNodeId,
            element.value,
          );
        case _Ac1ElementKind.idealVoltage:
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

    final _Ac1LinearSolveOutcome outcome = _solveLinearSystem(
      matrix,
      rhs,
      options.pivotTolerance,
    );
    if (outcome.solution == null) {
      diagnostics.add(
        Ac1SolverDiagnostic(
          code: Ac1DiagnosticCode.singularMatrix,
          severity: Ac1DiagnosticSeverity.error,
          message:
              'Complex MNA matrix is singular or numerically rank-deficient.',
        ),
      );
      return _failure(
        circuit,
        Ac1SolveStatus.singular,
        diagnostics,
        frequencyHz: frequencyHz,
        referenceNodeId: referenceNodeId,
      );
    }

    final List<AcComplex> solution = outcome.solution!;
    final double maxResidual = _maxMatrixResidual(matrix, solution, rhs);
    if (!maxResidual.isFinite || maxResidual > options.residualTolerance) {
      diagnostics.add(
        Ac1SolverDiagnostic(
          code: Ac1DiagnosticCode.numericalResidualExceeded,
          severity: Ac1DiagnosticSeverity.error,
          message:
              'Complex MNA numerical residual exceeds configured tolerance.',
        ),
      );
      return _failure(
        circuit,
        Ac1SolveStatus.invalid,
        diagnostics,
        frequencyHz: frequencyHz,
        referenceNodeId: referenceNodeId,
      );
    }

    final Map<String, AcComplex> nodeVoltages = <String, AcComplex>{
      for (final TopologyNode node in topology.nodes) node.id: AcComplex.zero,
      referenceNodeId: AcComplex.zero,
    };
    for (final MapEntry<String, int> entry in nodeIndex.entries) {
      nodeVoltages[entry.key] = solution[entry.value];
    }

    final List<Ac1BranchResult> branches = <Ac1BranchResult>[];
    final Map<String, AcComplex> nodeCurrentBalance = <String, AcComplex>{
      for (final TopologyNode node in topology.nodes) node.id: AcComplex.zero,
    };
    for (final _Ac1Element element in compiled.allElements) {
      final AcComplex voltage =
          nodeVoltages[element.fromNodeId]! - nodeVoltages[element.toNodeId]!;
      AcComplex? current;
      switch (element.kind) {
        case _Ac1ElementKind.impedance:
          current = element.isOpen ? AcComplex.zero : voltage / element.value;
        case _Ac1ElementKind.currentSource:
          current = element.value;
        case _Ac1ElementKind.idealVoltage:
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
        Ac1BranchResult(
          id: element.id,
          modelType: element.modelType,
          kind: element.branchKind,
          fromNodeId: element.fromNodeId,
          toNodeId: element.toNodeId,
          voltage: voltage,
          current: current,
        ),
      );
    }
    branches.sort(
      (Ac1BranchResult a, Ac1BranchResult b) => a.id.compareTo(b.id),
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
        Ac1SolverDiagnostic(
          code: Ac1DiagnosticCode.numericalResidualExceeded,
          severity: Ac1DiagnosticSeverity.error,
          message: 'AC1 KCL residual exceeds configured tolerance.',
        ),
      );
      return _failure(
        circuit,
        Ac1SolveStatus.invalid,
        diagnostics,
        frequencyHz: frequencyHz,
        referenceNodeId: referenceNodeId,
      );
    }

    return Ac1SolveResult(
      circuitId: circuit.circuitId,
      circuitRevision: circuit.revision,
      engineVersion: engineVersion,
      status: Ac1SolveStatus.solved,
      frequencyHz: frequencyHz,
      referenceNodeId: referenceNodeId,
      nodeVoltages: nodeVoltages,
      branchResults: branches,
      diagnostics: diagnostics,
      maxMatrixResidual: maxResidual,
      kclResiduals: kclResiduals,
    );
  }
}

double? _frequency(
  CircuitState circuit,
  List<Ac1SolverDiagnostic> diagnostics,
) {
  final Object? raw = circuit.settings['frequencyHz'];
  if (raw == null) {
    diagnostics.add(
      Ac1SolverDiagnostic(
        code: Ac1DiagnosticCode.missingFrequency,
        severity: Ac1DiagnosticSeverity.error,
        message: 'AC1 circuit settings must define frequencyHz.',
      ),
    );
    return null;
  }
  if (raw is! num) {
    diagnostics.add(
      Ac1SolverDiagnostic(
        code: Ac1DiagnosticCode.invalidFrequency,
        severity: Ac1DiagnosticSeverity.error,
        message: 'frequencyHz must be numeric.',
      ),
    );
    return null;
  }
  final double value = raw.toDouble();
  if (!value.isFinite || value <= 0.0) {
    diagnostics.add(
      Ac1SolverDiagnostic(
        code: Ac1DiagnosticCode.invalidFrequency,
        severity: Ac1DiagnosticSeverity.error,
        message: 'frequencyHz must be finite and greater than zero.',
      ),
    );
    return null;
  }
  return value;
}

_CompiledAc1Model _compileModel(
  CircuitState circuit,
  TopologyGraph topology,
  double frequencyHz,
  List<Ac1SolverDiagnostic> diagnostics,
) {
  final List<_Ac1Element> elements = <_Ac1Element>[];
  final List<ComponentInstance> components =
      circuit.components.toList(growable: false)..sort(
        (ComponentInstance a, ComponentInstance b) =>
            a.id.value.compareTo(b.id.value),
      );
  for (final ComponentInstance component in components) {
    final ComponentPhysicsContract? physics =
        CoreComponentPhysicsContracts.resolve(component.modelType);
    final ComponentModelContract? structural =
        CoreComponentModelContracts.registry.resolve(component.modelType);
    if (physics == null ||
        structural == null ||
        !structural.supportsMode(ElectricalMode.ac1) ||
        physics.electricalLaw == ComponentElectricalLaw.unsupported) {
      diagnostics.add(
        Ac1SolverDiagnostic(
          code: Ac1DiagnosticCode.unsupportedComponentModel,
          severity: Ac1DiagnosticSeverity.error,
          message:
              'Unsupported canonical AC1 component model ${component.modelType}.',
          componentId: component.id,
        ),
      );
      continue;
    }

    final List<TopologyBranch> topologyBranches = topology.branchesForComponent(
      component.id,
    );
    if (_compileElectromechanicalAc1(
      component: component,
      branches: topologyBranches,
      frequencyHz: frequencyHz,
      elements: elements,
      diagnostics: diagnostics,
    )) {
      continue;
    }
    if (physics.electricalLaw == ComponentElectricalLaw.feedThrough) {
      if (topologyBranches.length != structural.branches.length) {
        diagnostics.add(
          Ac1SolverDiagnostic(
            code: Ac1DiagnosticCode.invalidTerminalCount,
            severity: Ac1DiagnosticSeverity.error,
            message:
                '${component.modelType} must expose ${structural.branches.length} canonical feed-through branches.',
            componentId: component.id,
          ),
        );
      } else {
        final bool open =
            component.condition == ComponentCondition.openCircuit ||
            component.condition == ComponentCondition.disabled;
        for (final TopologyBranch branch in topologyBranches) {
          elements.add(
            _Ac1Element(
              id: 'component:${component.id.value}:${branch.branchId}',
              modelType: component.modelType,
              kind: open
                  ? _Ac1ElementKind.impedance
                  : _Ac1ElementKind.idealVoltage,
              branchKind: open
                  ? Ac1BranchKind.openCircuit
                  : Ac1BranchKind.idealShort,
              fromNodeId: branch.fromNodeId,
              toNodeId: branch.toNodeId,
              value: open ? const AcComplex(1e300, 0.0) : AcComplex.zero,
              isOpen: open,
            ),
          );
        }
      }
      continue;
    }
    if (topologyBranches.length != 1) {
      diagnostics.add(
        Ac1SolverDiagnostic(
          code: Ac1DiagnosticCode.invalidTerminalCount,
          severity: Ac1DiagnosticSeverity.error,
          message:
              'Canonical AC1 component ${component.id.value} must expose exactly one topology branch.',
          componentId: component.id,
        ),
      );
      continue;
    }
    final TopologyBranch topologyBranch = topologyBranches.single;
    final String fromNode = topologyBranch.fromNodeId;
    final String toNode = topologyBranch.toNodeId;

    void addOpen() {
      elements.add(
        _Ac1Element(
          id: 'component:${component.id.value}',
          modelType: component.modelType,
          kind: _Ac1ElementKind.impedance,
          branchKind: Ac1BranchKind.openCircuit,
          fromNodeId: fromNode,
          toNodeId: toNode,
          value: const AcComplex(1e300, 0.0),
          isOpen: true,
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
        _Ac1Element(
          id: 'component:${component.id.value}',
          modelType: component.modelType,
          kind: _Ac1ElementKind.idealVoltage,
          branchKind: Ac1BranchKind.idealShort,
          fromNodeId: fromNode,
          toNodeId: toNode,
          value: AcComplex.zero,
        ),
      );
      continue;
    }
    if (component.condition != ComponentCondition.normal) {
      diagnostics.add(
        Ac1SolverDiagnostic(
          code: Ac1DiagnosticCode.unsupportedComponentCondition,
          severity: Ac1DiagnosticSeverity.error,
          message: 'Unsupported AC1 condition ${component.condition.name}.',
          componentId: component.id,
        ),
      );
      continue;
    }

    switch (physics.electricalLaw) {
      case ComponentElectricalLaw.binarySwitch:
        final bool? closed = _closedFromControlLawAc1(
          component,
          physics.controlLaw,
        );
        if (closed == null) {
          diagnostics.add(
            Ac1SolverDiagnostic(
              code: Ac1DiagnosticCode.invalidParameter,
              severity: Ac1DiagnosticSeverity.error,
              message:
                  'AC1 switching component ${component.id.value} has invalid canonical control state.',
              componentId: component.id,
            ),
          );
        } else if (closed) {
          elements.add(
            _Ac1Element(
              id: 'component:${component.id.value}',
              modelType: component.modelType,
              kind: _Ac1ElementKind.idealVoltage,
              branchKind: Ac1BranchKind.idealSwitch,
              fromNodeId: fromNode,
              toNodeId: toNode,
              value: AcComplex.zero,
            ),
          );
        } else {
          addOpen();
        }
      case ComponentElectricalLaw.protectionSwitch:
        final double? ratedCurrent = _positiveParameter(
          component.parameters,
          ProtectionRating.ratedCurrentKey,
        );
        if (ratedCurrent == null) {
          diagnostics.add(
            Ac1SolverDiagnostic(
              code: Ac1DiagnosticCode.invalidParameter,
              severity: Ac1DiagnosticSeverity.error,
              message:
                  'AC1 protection requires finite ${ProtectionRating.ratedCurrentKey} > 0.',
              componentId: component.id,
            ),
          );
          continue;
        }
        final Object? rawClosed = component.controlState['closed'];
        final Object? rawTripped = component.controlState['tripped'];
        if ((rawClosed != null && rawClosed is! bool) ||
            (rawTripped != null && rawTripped is! bool)) {
          diagnostics.add(
            Ac1SolverDiagnostic(
              code: Ac1DiagnosticCode.invalidParameter,
              severity: Ac1DiagnosticSeverity.error,
              message:
                  'AC1 protection controlState.closed/tripped must be boolean when provided.',
              componentId: component.id,
            ),
          );
          continue;
        }
        final bool closed = (rawClosed as bool?) ?? true;
        final bool tripped = (rawTripped as bool?) ?? false;
        if (closed && !tripped) {
          elements.add(
            _Ac1Element(
              id: 'component:${component.id.value}',
              modelType: component.modelType,
              kind: _Ac1ElementKind.idealVoltage,
              branchKind: Ac1BranchKind.idealProtection,
              fromNodeId: fromNode,
              toNodeId: toNode,
              value: AcComplex.zero,
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
            _Ac1Element(
              id: 'component:${component.id.value}',
              modelType: component.modelType,
              kind: _Ac1ElementKind.idealVoltage,
              branchKind: Ac1BranchKind.idealShort,
              fromNodeId: fromNode,
              toNodeId: toNode,
              value: AcComplex.zero,
            ),
          );
          continue;
        }
        elements.add(
          _Ac1Element(
            id: 'component:${component.id.value}',
            modelType: component.modelType,
            kind: _Ac1ElementKind.impedance,
            branchKind: _branchKindForPhysics(physics),
            fromNodeId: fromNode,
            toNodeId: toNode,
            value: impedance,
          ),
        );
      case ComponentElectricalLaw.feedThrough:
        throw StateError(
          'Feed-through components are handled before single-branch AC1 compilation.',
        );
      case ComponentElectricalLaw.diode:
      case ComponentElectricalLaw.motorThreePhase:
      case ComponentElectricalLaw.loadWyeThreePhase:
      case ComponentElectricalLaw.loadDeltaThreePhase:
      case ComponentElectricalLaw.converter:
      case ComponentElectricalLaw.storage:
      case ComponentElectricalLaw.unsupported:
        diagnostics.add(
          Ac1SolverDiagnostic(
            code: Ac1DiagnosticCode.unsupportedComponentModel,
            severity: Ac1DiagnosticSeverity.error,
            message:
                'Electrical law ${physics.electricalLaw.name} is not supported by SolverAC1.',
            componentId: component.id,
          ),
        );
    }
  }

  for (final SourceInstance source in circuit.sources) {
    if (!source.enabled) {
      continue;
    }
    if (source.terminals.length != 2) {
      diagnostics.add(
        Ac1SolverDiagnostic(
          code: Ac1DiagnosticCode.invalidTerminalCount,
          severity: Ac1DiagnosticSeverity.error,
          message:
              'AC1 source ${source.id.value} must expose exactly two terminals.',
          sourceId: source.id,
        ),
      );
      continue;
    }
    final String fromNode = topology.terminalToNode[source.terminals[0].id]!;
    final String toNode = topology.terminalToNode[source.terminals[1].id]!;
    switch (source.modelType) {
      case 'ac_voltage_source':
        final AcComplex? phasor = _phasorParameter(
          source.parameters,
          magnitudeKey: 'voltageRmsV',
          diagnostics: diagnostics,
          sourceId: source.id,
        );
        if (phasor != null) {
          elements.add(
            _Ac1Element(
              id: 'source:${source.id.value}',
              modelType: source.modelType,
              kind: _Ac1ElementKind.idealVoltage,
              branchKind: Ac1BranchKind.voltageSource,
              fromNodeId: fromNode,
              toNodeId: toNode,
              value: phasor,
            ),
          );
        }
      case 'ac_current_source':
        final AcComplex? phasor = _phasorParameter(
          source.parameters,
          magnitudeKey: 'currentRmsA',
          diagnostics: diagnostics,
          sourceId: source.id,
        );
        if (phasor != null) {
          elements.add(
            _Ac1Element(
              id: 'source:${source.id.value}',
              modelType: source.modelType,
              kind: _Ac1ElementKind.currentSource,
              branchKind: Ac1BranchKind.currentSource,
              fromNodeId: fromNode,
              toNodeId: toNode,
              value: phasor,
            ),
          );
        }
      default:
        diagnostics.add(
          Ac1SolverDiagnostic(
            code: Ac1DiagnosticCode.unsupportedSourceModel,
            severity: Ac1DiagnosticSeverity.error,
            message: 'Unsupported AC1 source model ${source.modelType}.',
            sourceId: source.id,
          ),
        );
    }
  }

  return _CompiledAc1Model(
    _suppressRedundantAc1ControlConstraints(elements),
    diagnostics.any(_isError),
  );
}

bool _compileElectromechanicalAc1({
  required ComponentInstance component,
  required List<TopologyBranch> branches,
  required double frequencyHz,
  required List<_Ac1Element> elements,
  required List<Ac1SolverDiagnostic> diagnostics,
}) {
  final bool isContactor = component.modelType == 'contactor_ac1';
  final bool isAuxNo = component.modelType == 'contactor_aux_no';
  final bool isAuxNc = component.modelType == 'contactor_aux_nc';
  if (!isContactor && !isAuxNo && !isAuxNc) {
    return false;
  }

  final Object? rawActuated = component.controlState['actuated'];
  if (rawActuated != null && rawActuated is! bool) {
    diagnostics.add(
      Ac1SolverDiagnostic(
        code: Ac1DiagnosticCode.invalidParameter,
        severity: Ac1DiagnosticSeverity.error,
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
      Ac1SolverDiagnostic(
        code: Ac1DiagnosticCode.unsupportedComponentCondition,
        severity: Ac1DiagnosticSeverity.error,
        message:
            'Unsupported AC1 electromechanical condition ${component.condition.name}.',
        componentId: component.id,
      ),
    );
    return true;
  }

  if (isAuxNo || isAuxNc) {
    if (branches.length != 1) {
      diagnostics.add(
        Ac1SolverDiagnostic(
          code: Ac1DiagnosticCode.invalidTerminalCount,
          severity: Ac1DiagnosticSeverity.error,
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
      _Ac1Element(
        id: _componentBranchElementId(component, branch, branches.length),
        modelType: component.modelType,
        kind: closed ? _Ac1ElementKind.idealVoltage : _Ac1ElementKind.impedance,
        branchKind: Ac1BranchKind.contactorContact,
        fromNodeId: branch.fromNodeId,
        toNodeId: branch.toNodeId,
        value: closed ? AcComplex.zero : const AcComplex(1e300, 0.0),
        isOpen: !closed,
      ),
    );
    return true;
  }

  final TopologyBranch? coil = _branchWithRole(
    branches,
    ElectricalBranchRole.controlCoil,
  );
  final List<TopologyBranch> powerPoles = branches
      .where(
        (TopologyBranch branch) =>
            branch.role == ElectricalBranchRole.powerPole,
      )
      .toList(growable: false);
  if (coil == null || powerPoles.length != 1 || branches.length != 2) {
    diagnostics.add(
      Ac1SolverDiagnostic(
        code: Ac1DiagnosticCode.invalidTerminalCount,
        severity: Ac1DiagnosticSeverity.error,
        message:
            'contactor_ac1 must expose one power pole and one control coil.',
        componentId: component.id,
      ),
    );
    return true;
  }

  final double? coilResistance = _positiveParameter(
    component.parameters,
    'coilResistanceOhm',
  );
  final Object? inductanceRaw = component.parameters['coilInductanceH'];
  final double coilInductance = inductanceRaw == null
      ? 0.0
      : inductanceRaw is num
      ? inductanceRaw.toDouble()
      : double.nan;
  if (coilResistance == null ||
      !coilInductance.isFinite ||
      coilInductance < 0.0) {
    diagnostics.add(
      Ac1SolverDiagnostic(
        code: Ac1DiagnosticCode.invalidParameter,
        severity: Ac1DiagnosticSeverity.error,
        message:
            'contactor_ac1 requires coilResistanceOhm > 0 and optional coilInductanceH >= 0.',
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
    _Ac1Element(
      id: _componentBranchElementId(component, coil, branches.length),
      modelType: component.modelType,
      kind: _Ac1ElementKind.impedance,
      branchKind: Ac1BranchKind.controlCoil,
      fromNodeId: coil.fromNodeId,
      toNodeId: coil.toNodeId,
      value: forcedOpen
          ? const AcComplex(1e300, 0.0)
          : AcComplex(coilResistance, omega * coilInductance),
      isOpen: forcedOpen,
    ),
  );

  final TopologyBranch pole = powerPoles.single;
  final bool poleClosed = actuated && !forcedOpen;
  elements.add(
    _Ac1Element(
      id: _componentBranchElementId(component, pole, branches.length),
      modelType: component.modelType,
      kind: poleClosed
          ? _Ac1ElementKind.idealVoltage
          : _Ac1ElementKind.impedance,
      branchKind: Ac1BranchKind.contactorContact,
      fromNodeId: pole.fromNodeId,
      toNodeId: pole.toNodeId,
      value: poleClosed ? AcComplex.zero : const AcComplex(1e300, 0.0),
      isOpen: !poleClosed,
    ),
  );
  return true;
}

TopologyBranch? _branchWithRole(
  Iterable<TopologyBranch> branches,
  ElectricalBranchRole role,
) {
  for (final TopologyBranch branch in branches) {
    if (branch.role == role) return branch;
  }
  return null;
}

String _componentBranchElementId(
  ComponentInstance component,
  TopologyBranch branch,
  int branchCount,
) => branchCount == 1
    ? 'component:${component.id.value}'
    : 'component:${component.id.value}:${branch.branchId}';

AcComplex? _componentImpedance(
  ComponentInstance component,
  double frequencyHz,
  List<Ac1SolverDiagnostic> diagnostics,
) {
  final double omega = 2.0 * math.pi * frequencyHz;
  switch (component.modelType) {
    case 'resistor':
    case 'lamp':
      final double? resistance = _positiveParameter(
        component.parameters,
        'resistanceOhm',
      );
      if (resistance != null) {
        return AcComplex.real(resistance);
      }
    case 'inductor':
      final double? inductance = _positiveParameter(
        component.parameters,
        'inductanceH',
      );
      if (inductance != null) {
        return AcComplex(0.0, omega * inductance);
      }
    case 'capacitor':
      final double? capacitance = _positiveParameter(
        component.parameters,
        'capacitanceF',
      );
      if (capacitance != null) {
        return AcComplex(0.0, -1.0 / (omega * capacitance));
      }
    case 'impedance':
      final Object? rRaw = component.parameters['resistanceOhm'];
      final Object? xRaw = component.parameters['reactanceOhm'];
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
    default:
      diagnostics.add(
        Ac1SolverDiagnostic(
          code: Ac1DiagnosticCode.unsupportedComponentModel,
          severity: Ac1DiagnosticSeverity.error,
          message: 'Unsupported AC1 component model ${component.modelType}.',
          componentId: component.id,
        ),
      );
      return null;
  }
  diagnostics.add(
    Ac1SolverDiagnostic(
      code: Ac1DiagnosticCode.invalidParameter,
      severity: Ac1DiagnosticSeverity.error,
      message: 'Invalid parameters for AC1 component ${component.id.value}.',
      componentId: component.id,
    ),
  );
  return null;
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
  required List<Ac1SolverDiagnostic> diagnostics,
  required SourceId sourceId,
}) {
  final Object? magnitudeRaw = parameters[magnitudeKey];
  final Object? phaseRaw = parameters['phaseDeg'] ?? 0.0;
  if (magnitudeRaw is! num || phaseRaw is! num) {
    diagnostics.add(
      Ac1SolverDiagnostic(
        code: Ac1DiagnosticCode.invalidParameter,
        severity: Ac1DiagnosticSeverity.error,
        message: 'Invalid AC1 phasor parameters on source ${sourceId.value}.',
        sourceId: sourceId,
      ),
    );
    return null;
  }
  final double magnitude = magnitudeRaw.toDouble();
  final double phaseDeg = phaseRaw.toDouble();
  if (!magnitude.isFinite || magnitude < 0.0 || !phaseDeg.isFinite) {
    diagnostics.add(
      Ac1SolverDiagnostic(
        code: Ac1DiagnosticCode.invalidParameter,
        severity: Ac1DiagnosticSeverity.error,
        message:
            'AC1 phasor magnitude/phase must be finite and magnitude non-negative.',
        sourceId: sourceId,
      ),
    );
    return null;
  }
  return AcComplex.polar(magnitude, phaseDeg * math.pi / 180.0);
}

Ac1BranchKind _branchKindForModel(String modelType) {
  switch (modelType) {
    case 'resistor':
      return Ac1BranchKind.resistor;
    case 'inductor':
      return Ac1BranchKind.inductor;
    case 'capacitor':
      return Ac1BranchKind.capacitor;
    default:
      return Ac1BranchKind.impedance;
  }
}

String _selectReferenceNode(CircuitState circuit, TopologyGraph topology) {
  for (final SourceInstance source in circuit.sources) {
    if (source.terminals.length >= 2) {
      final Terminal second = source.terminals[1];
      final String? node = topology.terminalToNode[second.id];
      if (node != null) {
        return node;
      }
    }
  }
  final List<String> ids =
      topology.nodes.map((TopologyNode node) => node.id).toList(growable: false)
        ..sort();
  return ids.first;
}

Set<String> _participatingAc1Nodes(Iterable<_Ac1Element> elements) {
  final Set<String> nodes = <String>{};
  for (final _Ac1Element element in elements) {
    nodes
      ..add(element.fromNodeId)
      ..add(element.toNodeId);
  }
  return nodes;
}

List<String> _findFloatingNodes(
  Iterable<String> allNodes,
  String referenceNodeId,
  Iterable<_Ac1Element> elements,
) {
  final Map<String, Set<String>> adjacency = <String, Set<String>>{
    for (final String node in allNodes) node: <String>{},
  };
  for (final _Ac1Element element in elements) {
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

_Ac1LinearSolveOutcome _solveLinearSystem(
  List<List<AcComplex>> matrix,
  List<AcComplex> rhs,
  double pivotTolerance,
) {
  final int n = rhs.length;
  if (n == 0) {
    return const _Ac1LinearSolveOutcome(<AcComplex>[]);
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
      return const _Ac1LinearSolveOutcome(null);
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
  return _Ac1LinearSolveOutcome(<AcComplex>[
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

List<_Ac1Element> _suppressRedundantAc1ControlConstraints(
  List<_Ac1Element> elements,
) {
  final Set<String> constrainedPairs = <String>{};
  final List<_Ac1Element> result = <_Ac1Element>[];

  for (final _Ac1Element element in elements) {
    final bool eligible =
        !element.isOpen &&
        element.kind == _Ac1ElementKind.idealVoltage &&
        element.value.magnitude <= 1e-15 &&
        (element.branchKind == Ac1BranchKind.idealSwitch ||
            element.branchKind == Ac1BranchKind.contactorContact ||
            element.branchKind == Ac1BranchKind.idealProtection);

    if (!eligible) {
      result.add(element);
      continue;
    }

    final String first = element.fromNodeId.compareTo(element.toNodeId) <= 0
        ? element.fromNodeId
        : element.toNodeId;
    final String second = first == element.fromNodeId
        ? element.toNodeId
        : element.fromNodeId;
    final String key = '$first|$second';

    if (constrainedPairs.add(key)) {
      result.add(element);
    } else {
      result.add(element.copyWith(excludeFromMna: true));
    }
  }
  return result;
}

const Set<String> _supportedAc1ComponentModels = <String>{
  'resistor',
  'lamp',
  'inductor',
  'capacitor',
  'impedance',
  'switch',
  'switch_spst',
  'push_button_no',
  'push_button_nc',
  'breaker_ac1',
  'fuse_ac1',
  'contactor_ac1',
  'contactor_aux_no',
  'contactor_aux_nc',
  'terminal_block_5',
};

bool _isError(Ac1SolverDiagnostic diagnostic) =>
    diagnostic.severity == Ac1DiagnosticSeverity.error;

Ac1SolveResult _failure(
  CircuitState circuit,
  Ac1SolveStatus status,
  List<Ac1SolverDiagnostic> diagnostics, {
  double? frequencyHz,
  String? referenceNodeId,
}) => Ac1SolveResult(
  circuitId: circuit.circuitId,
  circuitRevision: circuit.revision,
  engineVersion: SolverAC1.engineVersion,
  status: status,
  frequencyHz: frequencyHz,
  referenceNodeId: referenceNodeId,
  nodeVoltages: const <String, AcComplex>{},
  branchResults: const <Ac1BranchResult>[],
  diagnostics: diagnostics,
  maxMatrixResidual: null,
  kclResiduals: const <String, double>{},
);

enum _Ac1ElementKind { impedance, currentSource, idealVoltage }

final class _Ac1Element {
  const _Ac1Element({
    required this.id,
    required this.modelType,
    required this.kind,
    required this.branchKind,
    required this.fromNodeId,
    required this.toNodeId,
    required this.value,
    this.isOpen = false,
    this.excludeFromMna = false,
  });

  final String id;
  final String modelType;
  final _Ac1ElementKind kind;
  final Ac1BranchKind branchKind;
  final String fromNodeId;
  final String toNodeId;
  final AcComplex value;
  final bool isOpen;
  final bool excludeFromMna;

  _Ac1Element copyWith({bool? isOpen, bool? excludeFromMna}) => _Ac1Element(
    id: id,
    modelType: modelType,
    kind: kind,
    branchKind: branchKind,
    fromNodeId: fromNodeId,
    toNodeId: toNodeId,
    value: value,
    isOpen: isOpen ?? this.isOpen,
    excludeFromMna: excludeFromMna ?? this.excludeFromMna,
  );
}

final class _CompiledAc1Model {
  const _CompiledAc1Model(this.allElements, this.hasErrors);

  final List<_Ac1Element> allElements;
  final bool hasErrors;

  Iterable<_Ac1Element> get activeElements => allElements.where(
    (_Ac1Element element) => !element.isOpen && !element.excludeFromMna,
  );
}

final class _Ac1LinearSolveOutcome {
  const _Ac1LinearSolveOutcome(this.solution);

  final List<AcComplex>? solution;
}
