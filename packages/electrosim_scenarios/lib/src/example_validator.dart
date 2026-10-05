import 'dart:convert';

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';

import 'example_definition.dart';

final class ExampleValidationIssue {
  const ExampleValidationIssue(this.code, this.message);
  final String code;
  final String message;
}

final class ExampleValidationResult {
  const ExampleValidationResult({
    required this.templateId,
    required this.issues,
    required this.stamp,
  });

  final CircuitTemplateId templateId;
  final List<ExampleValidationIssue> issues;
  final ExampleValidationStamp stamp;
  bool get isValid => issues.isEmpty;
}

final class ExampleValidator {
  const ExampleValidator({
    TopologyEngine topologyEngine = const TopologyEngine(),
    SolverDC solverDC = const SolverDC(),
  }) : _topologyEngine = topologyEngine,
       _solverDC = solverDC;

  static const String validatorVersion = 'F10-EXAMPLE-VALIDATOR-1';

  final TopologyEngine _topologyEngine;
  final SolverDC _solverDC;

  ExampleValidationResult validate(ExampleDefinition example) {
    final List<ExampleValidationIssue> issues = <ExampleValidationIssue>[];
    final CircuitState circuit = example.circuit;

    if (circuit.components.isEmpty && circuit.sources.isEmpty) {
      issues.add(
        const ExampleValidationIssue(
          'empty-circuit',
          'Example circuit must not be empty.',
        ),
      );
    }
    if (circuit.revision != 0) {
      issues.add(
        const ExampleValidationIssue(
          'revision-not-zero',
          'Published examples must start at revision 0.',
        ),
      );
    }
    if (_containsFaultSemantics(example.metadata) ||
        _containsFaultSemantics(circuit.metadata)) {
      issues.add(
        const ExampleValidationIssue(
          'fault-semantics',
          'Healthy examples must not contain fault semantics.',
        ),
      );
    }
    for (final ComponentInstance component in circuit.components) {
      if (component.condition != ComponentCondition.normal) {
        issues.add(
          ExampleValidationIssue(
            'non-normal-component',
            'Component ${component.id.value} must be normal in a healthy example.',
          ),
        );
      }
    }
    for (final SourceInstance source in circuit.sources) {
      if (!source.enabled) {
        issues.add(
          ExampleValidationIssue(
            'disabled-source',
            'Source ${source.id.value} must be enabled in a healthy example.',
          ),
        );
      }
    }

    if (circuit.mode == ElectricalMode.dc) {
      final DcSolveResult result = _solverDC.solve(
        circuit,
        _topologyEngine.compile(circuit),
      );
      if (result.status != DcSolveStatus.solved) {
        issues.add(
          ExampleValidationIssue(
            'dc-not-solvable',
            'DC example did not solve: ${result.status.name}.',
          ),
        );
      }
    } else {
      issues.add(
        ExampleValidationIssue(
          'unsupported-f10-mode',
          'F10-R1 intentionally publishes only simple DC examples.',
        ),
      );
    }

    return ExampleValidationResult(
      templateId: example.id,
      issues: List<ExampleValidationIssue>.unmodifiable(issues),
      stamp: ExampleValidationStamp(
        validatorVersion: validatorVersion,
        circuitSchemaVersion: CircuitState.currentSchemaVersion,
        contentDigestFnv1a64: _fnv1a64(example.canonicalPayload()),
      ),
    );
  }

  static bool _containsFaultSemantics(Map<String, Object?> metadata) {
    const Set<String> forbidden = <String>{
      'fault',
      'faultId',
      'faultScenario',
      'faultScenarioId',
      'teacherTruth',
    };
    return metadata.keys.any(forbidden.contains);
  }

  static String _fnv1a64(String value) {
    final BigInt offset = BigInt.parse('cbf29ce484222325', radix: 16);
    final BigInt prime = BigInt.parse('100000001b3', radix: 16);
    final BigInt mask = BigInt.parse('ffffffffffffffff', radix: 16);
    BigInt hash = offset;
    for (final int byte in utf8.encode(value)) {
      hash = ((hash ^ BigInt.from(byte)) * prime) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
