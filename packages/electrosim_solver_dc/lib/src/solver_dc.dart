import 'dart:math' as math;

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_topology/electrosim_topology.dart';

import 'dc_diagnostic.dart';
import 'dc_result.dart';
import 'dc_solver_options.dart';

final class SolverDC {
  const SolverDC({this.options = const DcSolverOptions()});

  static const String engineVersion = 'solver-dc/0.2.0';

  final DcSolverOptions options;

  DcSolveResult solve(CircuitState circuit, TopologyGraph topology) {
    final List<DcSolverDiagnostic> diagnostics = <DcSolverDiagnostic>[];
    if (circuit.mode != ElectricalMode.dc || topology.mode != ElectricalMode.dc) {
      diagnostics.add(
        DcSolverDiagnostic(
          code: DcDiagnosticCode.wrongElectricalMode,
          severity: DcDiagnosticSeverity.error,
          message: 'SolverDC accepts DC circuits only.',
        ),
      );
      return _failure(circuit, DcSolveStatus.invalid, diagnostics);
    }
    if (circuit.circuitId != topology.circuitId || circuit.revision != topology.circuitRevision) {
      diagnostics.add(
        DcSolverDiagnostic(
          code: DcDiagnosticCode.topologyIdentityMismatch,
          severity: DcDiagnosticSeverity.error,
          message: 'TopologyGraph does not match the CircuitState identity/revision.',
        ),
      );
      return _failure(circuit, DcSolveStatus.invalid, diagnostics);
    }
    if (topology.nodes.isEmpty) {
      diagnostics.add(
        DcSolverDiagnostic(
          code: DcDiagnosticCode.emptyCircuit,
          severity: DcDiagnosticSeverity.error,
          message: 'DC circuit contains no electrical nodes.',
        ),
      );
      return _failure(circuit, DcSolveStatus.invalid, diagnostics);
    }

    for (final TopologyFinding finding in topology.findings) {
      if (finding.severity == TopologyFindingSeverity.error) {
        diagnostics.add(
          DcSolverDiagnostic(
            code: DcDiagnosticCode.topologyError,
            severity: DcDiagnosticSeverity.error,
            message: finding.message,
            componentId: finding.componentId,
            sourceId: finding.sourceId,
            nodeIds: <String>[if (finding.nodeId != null) finding.nodeId!],
          ),
        );
      }
    }

    final _CompiledModel compiled = _compileModel(circuit, topology, diagnostics);
    if (compiled.hasErrors || diagnostics.any(_isError)) {
      return _failure(circuit, DcSolveStatus.invalid, diagnostics);
    }

    final String referenceNodeId = _selectReferenceNode(circuit, topology);
    final List<String> floatingNodes = _findFloatingNodes(
      topology.nodes.map((TopologyNode node) => node.id),
      referenceNodeId,
      compiled.activeElements,
    );
    if (floatingNodes.isNotEmpty) {
      diagnostics.add(
        DcSolverDiagnostic(
          code: DcDiagnosticCode.floatingElectricalIsland,
          severity: DcDiagnosticSeverity.error,
          message: 'Electrical island is not connected to the reference node.',
          nodeIds: floatingNodes,
        ),
      );
      return _failure(
        circuit,
        DcSolveStatus.singular,
        diagnostics,
        referenceNodeId: referenceNodeId,
      );
    }

    var activeElements = List<_Element>.from(compiled.activeElements);
    _MnaSolveOutcome? network;
    var currentLimitIteration = 0;
    while (true) {
      network = _solveActiveElements(
        topology.nodes.map((TopologyNode node) => node.id),
        referenceNodeId,
        activeElements,
      );
      if (network == null) {
        diagnostics.add(
          DcSolverDiagnostic(
            code: DcDiagnosticCode.singularMatrix,
            severity: DcDiagnosticSeverity.error,
            message: 'MNA matrix is singular or numerically rank-deficient.',
          ),
        );
        return _failure(
          circuit,
          DcSolveStatus.singular,
          diagnostics,
          referenceNodeId: referenceNodeId,
        );
      }
      if (!network.maxResidual.isFinite ||
          network.maxResidual > options.residualTolerance) {
        diagnostics.add(
          DcSolverDiagnostic(
            code: DcDiagnosticCode.numericalResidualExceeded,
            severity: DcDiagnosticSeverity.error,
            message: 'MNA numerical residual exceeds configured tolerance.',
          ),
        );
        return _failure(
          circuit,
          DcSolveStatus.invalid,
          diagnostics,
          referenceNodeId: referenceNodeId,
          maxMatrixResidual: network.maxResidual,
        );
      }

      final List<_Element> violations = <_Element>[];
      for (final _Element element in activeElements) {
        if (element.kind != _ElementKind.idealVoltage ||
            element.currentLimitA == null ||
            element.redundant) {
          continue;
        }
        final double? current = network.idealCurrentA(element.id);
        if (current != null &&
            current.abs() > element.currentLimitA! + options.residualTolerance) {
          violations.add(element);
        }
      }
      if (violations.isEmpty) {
        break;
      }
      if (currentLimitIteration >= options.maxCurrentLimitIterations) {
        diagnostics.add(
          DcSolverDiagnostic(
            code: DcDiagnosticCode.currentLimitIterationExceeded,
            severity: DcDiagnosticSeverity.error,
            message: 'DC source current-limit active set did not converge within the configured bound.',
          ),
        );
        return _failure(
          circuit,
          DcSolveStatus.invalid,
          diagnostics,
          referenceNodeId: referenceNodeId,
          maxMatrixResidual: network.maxResidual,
        );
      }

      final Map<String, double> clampedCurrentById = <String, double>{};
      for (final _Element element in violations) {
        final double current = network.idealCurrentA(element.id)!;
        final double limit = element.currentLimitA!;
        final double clamped = current.isNegative ? -limit : limit;
        clampedCurrentById[element.id] = clamped;
        diagnostics.add(
          DcSolverDiagnostic(
            code: DcDiagnosticCode.sourceCurrentLimited,
            severity: DcDiagnosticSeverity.warning,
            message: 'DC voltage source entered current-limited regulation at ${limit} A.',
            sourceId: element.sourceId,
            nodeIds: <String>[element.fromNodeId, element.toNodeId],
          ),
        );
      }
      activeElements = <_Element>[
        for (final _Element element in activeElements)
          if (clampedCurrentById.containsKey(element.id))
            element.asCurrentLimited(clampedCurrentById[element.id]!)
          else
            element,
      ];
      currentLimitIteration++;
    }

    final List<double> solution = network!.solution;
    final int nodeCount = network.nodeCount;
    final Map<String, int> idealIndex = network.idealIndex;
    final double maxResidual = network.maxResidual;
    final Map<String, double> nodeVoltages = network.nodeVoltages;

    final List<DcBranchResult> branches = <DcBranchResult>[];
    for (final _Element element in activeElements) {
      final double voltage = _clean(
        nodeVoltages[element.fromNodeId]! - nodeVoltages[element.toNodeId]!,
        options.residualTolerance,
      );
      double? current;
      switch (element.kind) {
        case _ElementKind.resistor:
          current = voltage / element.value;
        case _ElementKind.currentSource:
          current = element.value;
        case _ElementKind.idealVoltage:
          current = element.redundant
              ? null
              : solution[nodeCount + idealIndex[element.id]!];
      }
      if (current != null) {
        current = _clean(current, options.residualTolerance);
      }
      branches.add(
        DcBranchResult(
          id: element.id,
          modelType: element.modelType,
          kind: element.publicKind,
          fromNodeId: element.fromNodeId,
          toNodeId: element.toNodeId,
          voltageV: voltage,
          currentA: current,
          powerW: current == null ? null : _clean(voltage * current, options.residualTolerance),
        ),
      );
    }
    for (final _InactiveElement element in compiled.inactiveElements) {
      final double voltage = _clean(
        nodeVoltages[element.fromNodeId]! - nodeVoltages[element.toNodeId]!,
        options.residualTolerance,
      );
      branches.add(
        DcBranchResult(
          id: element.id,
          modelType: element.modelType,
          kind: DcBranchKind.openCircuit,
          fromNodeId: element.fromNodeId,
          toNodeId: element.toNodeId,
          voltageV: voltage,
          currentA: 0.0,
          powerW: 0.0,
        ),
      );
    }
    branches.sort((DcBranchResult a, DcBranchResult b) => a.id.compareTo(b.id));

    final Map<String, double> kclResiduals = _calculateKclResiduals(
      topology.nodes.map((TopologyNode node) => node.id),
      branches,
      options.residualTolerance,
    );
    final Map<String, double> kvlResiduals = _calculateKvlResiduals(
      nodeVoltages,
      branches.where((DcBranchResult branch) => branch.kind != DcBranchKind.openCircuit),
      options.residualTolerance,
    );

    return DcSolveResult(
      circuitId: circuit.circuitId,
      circuitRevision: circuit.revision,
      engineVersion: engineVersion,
      status: DcSolveStatus.solved,
      referenceNodeId: referenceNodeId,
      nodeVoltages: nodeVoltages,
      branchResults: branches,
      diagnostics: diagnostics,
      maxMatrixResidual: maxResidual,
      kclResiduals: kclResiduals,
      kvlResiduals: kvlResiduals,
    );
  }

  _CompiledModel _compileModel(
    CircuitState circuit,
    TopologyGraph topology,
    List<DcSolverDiagnostic> diagnostics,
  ) {
    final List<_Element> active = <_Element>[];
    final List<_InactiveElement> inactive = <_InactiveElement>[];
    final List<ComponentInstance> components = circuit.components.toList(growable: false)
      ..sort((ComponentInstance a, ComponentInstance b) => a.id.value.compareTo(b.id.value));
    for (final ComponentInstance component in components) {
      if (!_supportedDcComponentModels.contains(component.modelType)) {
        diagnostics.add(
          DcSolverDiagnostic(
            code: DcDiagnosticCode.unsupportedComponentModel,
            severity: DcDiagnosticSeverity.error,
            message: 'Unsupported M3 DC component model: ${component.modelType}.',
            componentId: component.id,
          ),
        );
        continue;
      }

      final List<TopologyBranch> topologyBranches = topology.branchesForComponent(component.id);
      if (topologyBranches.length != 1) {
        diagnostics.add(
          DcSolverDiagnostic(
            code: DcDiagnosticCode.invalidTerminalCount,
            severity: DcDiagnosticSeverity.error,
            message: 'Canonical DC component ${component.id.value} must expose exactly one topology branch.',
            componentId: component.id,
          ),
        );
        continue;
      }
      final TopologyBranch topologyBranch = topologyBranches.single;
      final String fromNode = topologyBranch.fromNodeId;
      final String toNode = topologyBranch.toNodeId;

      if (component.condition == ComponentCondition.openCircuit ||
          component.condition == ComponentCondition.disabled) {
        inactive.add(
          _InactiveElement(
            id: 'component:${component.id.value}',
            modelType: component.modelType,
            fromNodeId: fromNode,
            toNodeId: toNode,
          ),
        );
        continue;
      }
      if (component.condition == ComponentCondition.degraded) {
        diagnostics.add(
          DcSolverDiagnostic(
            code: DcDiagnosticCode.unsupportedComponentCondition,
            severity: DcDiagnosticSeverity.error,
            message: 'Degraded component condition is not modeled in M3A.',
            componentId: component.id,
          ),
        );
        continue;
      }
      if (component.condition == ComponentCondition.shortCircuit) {
        active.add(
          _Element.idealVoltage(
            id: 'component:${component.id.value}',
            modelType: component.modelType,
            publicKind: DcBranchKind.idealShort,
            fromNodeId: fromNode,
            toNodeId: toNode,
            voltageV: 0.0,
            redundant: fromNode == toNode,
          ),
        );
        continue;
      }

      switch (component.modelType) {
        case 'resistor':
        case 'lamp':
          final double? resistance = _positiveParameter(component.parameters, 'resistanceOhm');
          if (resistance == null) {
            diagnostics.add(
              DcSolverDiagnostic(
                code: DcDiagnosticCode.invalidParameter,
                severity: DcDiagnosticSeverity.error,
                message: 'Resistive DC receiver requires finite resistanceOhm > 0.',
                componentId: component.id,
              ),
            );
          } else {
            active.add(
              _Element.resistor(
                id: 'component:${component.id.value}',
                modelType: component.modelType,
                fromNodeId: fromNode,
                toNodeId: toNode,
                resistanceOhm: resistance,
              ),
            );
          }
        case 'switch':
        case 'switch_spst':
          final Object? rawClosed = component.controlState['closed'];
          if (rawClosed is! bool) {
            diagnostics.add(
              DcSolverDiagnostic(
                code: DcDiagnosticCode.invalidParameter,
                severity: DcDiagnosticSeverity.error,
                message: 'Switch requires boolean controlState.closed.',
                componentId: component.id,
              ),
            );
          } else if (rawClosed) {
            active.add(
              _Element.idealVoltage(
                id: 'component:${component.id.value}',
                modelType: component.modelType,
                publicKind: DcBranchKind.idealSwitch,
                fromNodeId: fromNode,
                toNodeId: toNode,
                voltageV: 0.0,
                redundant: fromNode == toNode,
              ),
            );
          } else {
            inactive.add(
              _InactiveElement(
                id: 'component:${component.id.value}',
                modelType: component.modelType,
                fromNodeId: fromNode,
                toNodeId: toNode,
              ),
            );
          }
        case 'breaker_dc':
        case 'fuse_dc':
          final double? ratedCurrent =
              _positiveParameter(component.parameters, ProtectionRating.ratedCurrentKey);
          if (ratedCurrent == null) {
            diagnostics.add(
              DcSolverDiagnostic(
                code: DcDiagnosticCode.invalidParameter,
                severity: DcDiagnosticSeverity.error,
                message: 'DC protection requires finite ${ProtectionRating.ratedCurrentKey} > 0.',
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
              DcSolverDiagnostic(
                code: DcDiagnosticCode.invalidParameter,
                severity: DcDiagnosticSeverity.error,
                message: 'DC protection controlState.closed/tripped must be boolean when provided.',
                componentId: component.id,
              ),
            );
            continue;
          }
          final bool closed = (rawClosed as bool?) ?? true;
          final bool tripped = (rawTripped as bool?) ?? false;
          if (closed && !tripped) {
            active.add(
              _Element.idealVoltage(
                id: 'component:${component.id.value}',
                modelType: component.modelType,
                publicKind: DcBranchKind.idealProtection,
                fromNodeId: fromNode,
                toNodeId: toNode,
                voltageV: 0.0,
                redundant: fromNode == toNode,
              ),
            );
          } else {
            inactive.add(
              _InactiveElement(
                id: 'component:${component.id.value}',
                modelType: component.modelType,
                fromNodeId: fromNode,
                toNodeId: toNode,
              ),
            );
          }
      }
    }

    final List<SourceInstance> sources = circuit.sources.toList(growable: false)
      ..sort((SourceInstance a, SourceInstance b) => a.id.value.compareTo(b.id.value));
    for (final SourceInstance source in sources) {
      if (source.terminals.length != 2) {
        diagnostics.add(
          DcSolverDiagnostic(
            code: DcDiagnosticCode.invalidTerminalCount,
            severity: DcDiagnosticSeverity.error,
            message: 'DC source ${source.id.value} must expose exactly two terminals.',
            sourceId: source.id,
          ),
        );
        continue;
      }
      final String fromNode = topology.terminalToNode[source.terminals[0].id]!;
      final String toNode = topology.terminalToNode[source.terminals[1].id]!;
      if (!source.enabled) {
        inactive.add(
          _InactiveElement(
            id: 'source:${source.id.value}',
            modelType: source.modelType,
            fromNodeId: fromNode,
            toNodeId: toNode,
          ),
        );
        continue;
      }
      switch (source.modelType) {
        case 'dc_voltage_source':
        case 'voltage_source':
          final double? voltage = _finiteParameter(source.parameters, 'voltageV');
          if (voltage == null) {
            diagnostics.add(
              DcSolverDiagnostic(
                code: DcDiagnosticCode.invalidParameter,
                severity: DcDiagnosticSeverity.error,
                message: 'Voltage source requires finite voltageV.',
                sourceId: source.id,
              ),
            );
            continue;
          }
          double? currentLimitA;
          if (source.parameters.containsKey('currentLimitA')) {
            currentLimitA = _positiveParameter(source.parameters, 'currentLimitA');
            if (currentLimitA == null) {
              diagnostics.add(
                DcSolverDiagnostic(
                  code: DcDiagnosticCode.invalidParameter,
                  severity: DcDiagnosticSeverity.error,
                  message: 'DC voltage source currentLimitA must be finite and greater than zero.',
                  sourceId: source.id,
                ),
              );
              continue;
            }
          }
          if (fromNode == toNode && voltage.abs() > options.residualTolerance) {
            diagnostics.add(
              DcSolverDiagnostic(
                code: DcDiagnosticCode.contradictoryIdealSource,
                severity: DcDiagnosticSeverity.error,
                message: 'Non-zero ideal voltage source is shorted onto one topology node.',
                sourceId: source.id,
                nodeIds: <String>[fromNode],
              ),
            );
            continue;
          }
          final bool redundant = fromNode == toNode;
          if (redundant) {
            diagnostics.add(
              DcSolverDiagnostic(
                code: DcDiagnosticCode.redundantIdealConstraint,
                severity: DcDiagnosticSeverity.warning,
                message: 'Zero-volt ideal source constraint is redundant; branch current is indeterminate.',
                sourceId: source.id,
                nodeIds: <String>[fromNode],
              ),
            );
          }
          active.add(
            _Element.idealVoltage(
              id: 'source:${source.id.value}',
              modelType: source.modelType,
              publicKind: DcBranchKind.voltageSource,
              fromNodeId: fromNode,
              toNodeId: toNode,
              voltageV: voltage,
              redundant: redundant,
              currentLimitA: currentLimitA,
              sourceId: source.id,
            ),
          );
        case 'dc_current_source':
        case 'current_source':
          final double? current = _finiteParameter(source.parameters, 'currentA');
          if (current == null) {
            diagnostics.add(
              DcSolverDiagnostic(
                code: DcDiagnosticCode.invalidParameter,
                severity: DcDiagnosticSeverity.error,
                message: 'Current source requires finite currentA.',
                sourceId: source.id,
              ),
            );
          } else {
            active.add(
              _Element.currentSource(
                id: 'source:${source.id.value}',
                modelType: source.modelType,
                fromNodeId: fromNode,
                toNodeId: toNode,
                currentA: current,
              ),
            );
          }
        default:
          diagnostics.add(
            DcSolverDiagnostic(
              code: DcDiagnosticCode.unsupportedSourceModel,
              severity: DcDiagnosticSeverity.error,
              message: 'Unsupported F3 DC source model: ${source.modelType}.',
              sourceId: source.id,
            ),
          );
      }
    }

    return _CompiledModel(
      activeElements: active,
      inactiveElements: inactive,
      hasErrors: diagnostics.any(_isError),
    );
  }

  String _selectReferenceNode(CircuitState circuit, TopologyGraph topology) {
    final List<String> preferred = <String>[];
    for (final SourceInstance source in circuit.sources) {
      for (final Terminal terminal in source.terminals) {
        if (terminal.role == TerminalRole.negative ||
            terminal.role == TerminalRole.neutral ||
            terminal.phase == PhaseTag.dcNegative ||
            terminal.phase == PhaseTag.neutral) {
          preferred.add(topology.terminalToNode[terminal.id]!);
        }
      }
    }
    if (preferred.isNotEmpty) {
      preferred.sort();
      return preferred.first;
    }
    final List<String> nodes = topology.nodes.map((TopologyNode node) => node.id).toList()
      ..sort();
    return nodes.first;
  }

  List<String> _findFloatingNodes(
    Iterable<String> allNodes,
    String referenceNode,
    Iterable<_Element> elements,
  ) {
    final Map<String, Set<String>> adjacency = <String, Set<String>>{
      for (final String node in allNodes) node: <String>{},
    };
    for (final _Element element in elements) {
      if (element.fromNodeId == element.toNodeId) {
        continue;
      }
      adjacency[element.fromNodeId]!.add(element.toNodeId);
      adjacency[element.toNodeId]!.add(element.fromNodeId);
    }
    final Set<String> visited = <String>{referenceNode};
    final List<String> queue = <String>[referenceNode];
    for (var index = 0; index < queue.length; index++) {
      final String node = queue[index];
      final List<String> next = adjacency[node]!.toList()..sort();
      for (final String candidate in next) {
        if (visited.add(candidate)) {
          queue.add(candidate);
        }
      }
    }
    final List<String> floating = adjacency.keys.where((String node) => !visited.contains(node)).toList()
      ..sort();
    return floating;
  }

  _MnaSolveOutcome? _solveActiveElements(
    Iterable<String> allNodeIds,
    String referenceNodeId,
    List<_Element> activeElements,
  ) {
    final List<String> unknownNodes = allNodeIds
        .where((String nodeId) => nodeId != referenceNodeId)
        .toList(growable: false)
      ..sort();
    final Map<String, int> nodeIndex = <String, int>{
      for (var i = 0; i < unknownNodes.length; i++) unknownNodes[i]: i,
    };
    final List<_Element> idealConstraints = activeElements
        .where((_Element element) => element.kind == _ElementKind.idealVoltage && !element.redundant)
        .toList(growable: false)
      ..sort((_Element a, _Element b) => a.id.compareTo(b.id));
    final Map<String, int> idealIndex = <String, int>{
      for (var i = 0; i < idealConstraints.length; i++) idealConstraints[i].id: i,
    };

    final int nodeCount = unknownNodes.length;
    final int size = nodeCount + idealConstraints.length;
    final List<List<double>> matrix = List<List<double>>.generate(
      size,
      (_) => List<double>.filled(size, 0.0),
      growable: false,
    );
    final List<double> rhs = List<double>.filled(size, 0.0);

    for (final _Element element in activeElements) {
      switch (element.kind) {
        case _ElementKind.resistor:
          _stampConductance(
            matrix,
            nodeIndex,
            referenceNodeId,
            element.fromNodeId,
            element.toNodeId,
            1.0 / element.value,
          );
        case _ElementKind.currentSource:
          _stampCurrentSource(
            rhs,
            nodeIndex,
            referenceNodeId,
            element.fromNodeId,
            element.toNodeId,
            element.value,
          );
        case _ElementKind.idealVoltage:
          if (!element.redundant) {
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
    }

    final _LinearSolveOutcome outcome = _solveLinearSystem(
      matrix,
      rhs,
      options.pivotTolerance,
    );
    if (outcome.solution == null) {
      return null;
    }
    final List<double> solution = outcome.solution!;
    final double maxResidual = _maxMatrixResidual(matrix, solution, rhs);
    final Map<String, double> nodeVoltages = <String, double>{
      referenceNodeId: 0.0,
    };
    for (final MapEntry<String, int> entry in nodeIndex.entries) {
      nodeVoltages[entry.key] = _clean(
        solution[entry.value],
        options.residualTolerance,
      );
    }

    return _MnaSolveOutcome(
      solution: solution,
      nodeCount: nodeCount,
      idealIndex: idealIndex,
      nodeVoltages: nodeVoltages,
      maxResidual: maxResidual,
    );
  }

  DcSolveResult _failure(
    CircuitState circuit,
    DcSolveStatus status,
    List<DcSolverDiagnostic> diagnostics, {
    String? referenceNodeId,
    double? maxMatrixResidual,
  }) => DcSolveResult(
    circuitId: circuit.circuitId,
    circuitRevision: circuit.revision,
    engineVersion: engineVersion,
    status: status,
    referenceNodeId: referenceNodeId,
    nodeVoltages: const <String, double>{},
    branchResults: const <DcBranchResult>[],
    diagnostics: diagnostics,
    maxMatrixResidual: maxMatrixResidual,
    kclResiduals: const <String, double>{},
    kvlResiduals: const <String, double>{},
  );
}

const Set<String> _supportedDcComponentModels = <String>{
  'resistor',
  'lamp',
  'switch',
  'switch_spst',
  'breaker_dc',
  'fuse_dc',
};

bool _isError(DcSolverDiagnostic diagnostic) => diagnostic.severity == DcDiagnosticSeverity.error;

double? _finiteParameter(Map<String, Object?> parameters, String key) {
  final Object? raw = parameters[key];
  if (raw is! num) {
    return null;
  }
  final double value = raw.toDouble();
  return value.isFinite ? value : null;
}

double? _positiveParameter(Map<String, Object?> parameters, String key) {
  final double? value = _finiteParameter(parameters, key);
  return value != null && value > 0 ? value : null;
}

void _stampConductance(
  List<List<double>> matrix,
  Map<String, int> nodeIndex,
  String reference,
  String a,
  String b,
  double conductance,
) {
  final int? ai = a == reference ? null : nodeIndex[a];
  final int? bi = b == reference ? null : nodeIndex[b];
  if (ai != null) {
    matrix[ai][ai] += conductance;
  }
  if (bi != null) {
    matrix[bi][bi] += conductance;
  }
  if (ai != null && bi != null) {
    matrix[ai][bi] -= conductance;
    matrix[bi][ai] -= conductance;
  }
}

void _stampCurrentSource(
  List<double> rhs,
  Map<String, int> nodeIndex,
  String reference,
  String from,
  String to,
  double current,
) {
  final int? fromIndex = from == reference ? null : nodeIndex[from];
  final int? toIndex = to == reference ? null : nodeIndex[to];
  if (fromIndex != null) {
    rhs[fromIndex] -= current;
  }
  if (toIndex != null) {
    rhs[toIndex] += current;
  }
}

void _stampIdealVoltage(
  List<List<double>> matrix,
  List<double> rhs,
  Map<String, int> nodeIndex,
  String reference,
  int sourceIndex,
  String positive,
  String negative,
  double voltage,
) {
  final int? positiveIndex = positive == reference ? null : nodeIndex[positive];
  final int? negativeIndex = negative == reference ? null : nodeIndex[negative];
  if (positiveIndex != null) {
    matrix[positiveIndex][sourceIndex] += 1.0;
    matrix[sourceIndex][positiveIndex] += 1.0;
  }
  if (negativeIndex != null) {
    matrix[negativeIndex][sourceIndex] -= 1.0;
    matrix[sourceIndex][negativeIndex] -= 1.0;
  }
  rhs[sourceIndex] += voltage;
}

_LinearSolveOutcome _solveLinearSystem(
  List<List<double>> inputMatrix,
  List<double> inputRhs,
  double pivotTolerance,
) {
  final int n = inputRhs.length;
  if (n == 0) {
    return const _LinearSolveOutcome(<double>[]);
  }
  final List<List<double>> a = List<List<double>>.generate(
    n,
    (int row) => List<double>.from(inputMatrix[row]),
    growable: false,
  );
  final List<double> b = List<double>.from(inputRhs);

  for (var column = 0; column < n; column++) {
    var pivotRow = column;
    var pivotMagnitude = a[column][column].abs();
    for (var row = column + 1; row < n; row++) {
      final double magnitude = a[row][column].abs();
      if (magnitude > pivotMagnitude) {
        pivotMagnitude = magnitude;
        pivotRow = row;
      }
    }
    if (!pivotMagnitude.isFinite || pivotMagnitude <= pivotTolerance) {
      return const _LinearSolveOutcome(null);
    }
    if (pivotRow != column) {
      final List<double> row = a[column];
      a[column] = a[pivotRow];
      a[pivotRow] = row;
      final double rhs = b[column];
      b[column] = b[pivotRow];
      b[pivotRow] = rhs;
    }
    final double pivot = a[column][column];
    for (var row = column + 1; row < n; row++) {
      final double factor = a[row][column] / pivot;
      if (factor == 0.0) {
        continue;
      }
      a[row][column] = 0.0;
      for (var c = column + 1; c < n; c++) {
        a[row][c] -= factor * a[column][c];
      }
      b[row] -= factor * b[column];
    }
  }

  final List<double> x = List<double>.filled(n, 0.0);
  for (var row = n - 1; row >= 0; row--) {
    var sum = b[row];
    for (var column = row + 1; column < n; column++) {
      sum -= a[row][column] * x[column];
    }
    final double pivot = a[row][row];
    if (!pivot.isFinite || pivot.abs() <= pivotTolerance) {
      return const _LinearSolveOutcome(null);
    }
    x[row] = sum / pivot;
    if (!x[row].isFinite) {
      return const _LinearSolveOutcome(null);
    }
  }
  return _LinearSolveOutcome(x);
}

double _maxMatrixResidual(
  List<List<double>> matrix,
  List<double> solution,
  List<double> rhs,
) {
  var maximum = 0.0;
  for (var row = 0; row < rhs.length; row++) {
    var actual = 0.0;
    for (var column = 0; column < solution.length; column++) {
      actual += matrix[row][column] * solution[column];
    }
    maximum = math.max(maximum, (actual - rhs[row]).abs());
  }
  return maximum;
}

Map<String, double> _calculateKclResiduals(
  Iterable<String> nodeIds,
  Iterable<DcBranchResult> branches,
  double tolerance,
) {
  final Map<String, double> residuals = <String, double>{for (final String id in nodeIds) id: 0.0};
  for (final DcBranchResult branch in branches) {
    final double? current = branch.currentA;
    if (current == null) {
      continue;
    }
    residuals[branch.fromNodeId] = residuals[branch.fromNodeId]! + current;
    residuals[branch.toNodeId] = residuals[branch.toNodeId]! - current;
  }
  return <String, double>{
    for (final MapEntry<String, double> entry in residuals.entries) entry.key: _clean(entry.value, tolerance),
  };
}

Map<String, double> _calculateKvlResiduals(
  Map<String, double> nodeVoltages,
  Iterable<DcBranchResult> inputBranches,
  double tolerance,
) {
  final List<DcBranchResult> branches = inputBranches
      .where((DcBranchResult branch) => branch.fromNodeId != branch.toNodeId)
      .toList(growable: false)
    ..sort((DcBranchResult a, DcBranchResult b) => a.id.compareTo(b.id));
  final _StringUnionFind union = _StringUnionFind(nodeVoltages.keys);
  final Map<String, List<String>> tree = <String, List<String>>{
    for (final String node in nodeVoltages.keys) node: <String>[],
  };
  final List<DcBranchResult> chords = <DcBranchResult>[];
  for (final DcBranchResult branch in branches) {
    if (union.find(branch.fromNodeId) != union.find(branch.toNodeId)) {
      union.union(branch.fromNodeId, branch.toNodeId);
      tree[branch.fromNodeId]!.add(branch.toNodeId);
      tree[branch.toNodeId]!.add(branch.fromNodeId);
    } else {
      chords.add(branch);
    }
  }
  final Map<String, double> result = <String, double>{};
  for (final DcBranchResult chord in chords) {
    final List<String>? path = _treePath(tree, chord.toNodeId, chord.fromNodeId);
    if (path == null) {
      continue;
    }
    var sum = chord.voltageV;
    for (var i = 0; i + 1 < path.length; i++) {
      sum += nodeVoltages[path[i]]! - nodeVoltages[path[i + 1]]!;
    }
    result['cycle:${chord.id}'] = _clean(sum, tolerance);
  }
  return result;
}

List<String>? _treePath(Map<String, List<String>> tree, String start, String target) {
  final Map<String, String?> parent = <String, String?>{start: null};
  final List<String> queue = <String>[start];
  for (var index = 0; index < queue.length; index++) {
    final String node = queue[index];
    if (node == target) {
      final List<String> path = <String>[];
      String? current = target;
      while (current != null) {
        path.add(current);
        current = parent[current];
      }
      return path.reversed.toList(growable: false);
    }
    final List<String> neighbours = List<String>.from(tree[node]!)..sort();
    for (final String neighbour in neighbours) {
      if (!parent.containsKey(neighbour)) {
        parent[neighbour] = node;
        queue.add(neighbour);
      }
    }
  }
  return null;
}

double _clean(double value, double tolerance) => value.abs() <= tolerance ? 0.0 : value;

enum _ElementKind { resistor, idealVoltage, currentSource }

final class _Element {
  const _Element._({
    required this.id,
    required this.modelType,
    required this.kind,
    required this.publicKind,
    required this.fromNodeId,
    required this.toNodeId,
    required this.value,
    required this.redundant,
    this.currentLimitA,
    this.sourceId,
  });

  factory _Element.resistor({
    required String id,
    required String modelType,
    required String fromNodeId,
    required String toNodeId,
    required double resistanceOhm,
  }) => _Element._(
    id: id,
    modelType: modelType,
    kind: _ElementKind.resistor,
    publicKind: DcBranchKind.resistor,
    fromNodeId: fromNodeId,
    toNodeId: toNodeId,
    value: resistanceOhm,
    redundant: false,
  );

  factory _Element.currentSource({
    required String id,
    required String modelType,
    required String fromNodeId,
    required String toNodeId,
    required double currentA,
    DcBranchKind publicKind = DcBranchKind.currentSource,
    SourceId? sourceId,
  }) => _Element._(
    id: id,
    modelType: modelType,
    kind: _ElementKind.currentSource,
    publicKind: publicKind,
    fromNodeId: fromNodeId,
    toNodeId: toNodeId,
    value: currentA,
    redundant: false,
    sourceId: sourceId,
  );

  factory _Element.idealVoltage({
    required String id,
    required String modelType,
    required DcBranchKind publicKind,
    required String fromNodeId,
    required String toNodeId,
    required double voltageV,
    required bool redundant,
    double? currentLimitA,
    SourceId? sourceId,
  }) => _Element._(
    id: id,
    modelType: modelType,
    kind: _ElementKind.idealVoltage,
    publicKind: publicKind,
    fromNodeId: fromNodeId,
    toNodeId: toNodeId,
    value: voltageV,
    redundant: redundant,
    currentLimitA: currentLimitA,
    sourceId: sourceId,
  );

  final String id;
  final String modelType;
  final _ElementKind kind;
  final DcBranchKind publicKind;
  final String fromNodeId;
  final String toNodeId;
  final double value;
  final bool redundant;
  final double? currentLimitA;
  final SourceId? sourceId;

  _Element asCurrentLimited(double currentA) {
    if (kind != _ElementKind.idealVoltage || currentLimitA == null) {
      throw StateError('Only a current-limited ideal voltage source can enter current regulation.');
    }
    return _Element.currentSource(
      id: id,
      modelType: modelType,
      fromNodeId: fromNodeId,
      toNodeId: toNodeId,
      currentA: currentA,
      publicKind: publicKind,
      sourceId: sourceId,
    );
  }
}

final class _InactiveElement {
  const _InactiveElement({
    required this.id,
    required this.modelType,
    required this.fromNodeId,
    required this.toNodeId,
  });

  final String id;
  final String modelType;
  final String fromNodeId;
  final String toNodeId;
}

final class _CompiledModel {
  const _CompiledModel({
    required this.activeElements,
    required this.inactiveElements,
    required this.hasErrors,
  });

  final List<_Element> activeElements;
  final List<_InactiveElement> inactiveElements;
  final bool hasErrors;
}

final class _MnaSolveOutcome {
  const _MnaSolveOutcome({
    required this.solution,
    required this.nodeCount,
    required this.idealIndex,
    required this.nodeVoltages,
    required this.maxResidual,
  });

  final List<double> solution;
  final int nodeCount;
  final Map<String, int> idealIndex;
  final Map<String, double> nodeVoltages;
  final double maxResidual;

  double? idealCurrentA(String elementId) {
    final int? index = idealIndex[elementId];
    return index == null ? null : solution[nodeCount + index];
  }
}

final class _LinearSolveOutcome {
  const _LinearSolveOutcome(this.solution);

  final List<double>? solution;
}

final class _StringUnionFind {
  _StringUnionFind(Iterable<String> ids)
    : _parent = <String, String>{for (final String id in ids) id: id};

  final Map<String, String> _parent;

  String find(String id) {
    final String parent = _parent[id]!;
    if (parent == id) {
      return id;
    }
    final String root = find(parent);
    _parent[id] = root;
    return root;
  }

  void union(String a, String b) {
    final String rootA = find(a);
    final String rootB = find(b);
    if (rootA == rootB) {
      return;
    }
    if (rootA.compareTo(rootB) <= 0) {
      _parent[rootB] = rootA;
    } else {
      _parent[rootA] = rootB;
    }
  }
}
