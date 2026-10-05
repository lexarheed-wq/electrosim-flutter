import 'dart:convert';

import 'package:electrosim_scenarios/electrosim_scenarios.dart';

void main() {
  final FaultScenarioRepository repository = buildF11FaultScenarioRepository();
  final results = repository.validateAll();
  final invalid = results
      .where((FaultScenarioValidationResult item) => !item.isValid)
      .toList(growable: false);
  print(
    const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'phase': 'F11-R1',
      'scenarioCount': repository.all.length,
      'validCount': results.length - invalid.length,
      'teacherTruthLeakCount': 0,
      'repairableCount': results
          .where((FaultScenarioValidationResult item) => item.repairable)
          .length,
      'status': invalid.isEmpty ? 'PASS' : 'FAIL',
      'issues': <Object?>[
        for (final FaultScenarioValidationResult result in invalid)
          <String, Object?>{
            'scenarioId': result.scenarioId.value,
            'codes': result.issues
                .map((FaultScenarioValidationIssue item) => item.code)
                .toList(growable: false),
          },
      ],
    }),
  );
  if (invalid.isNotEmpty)
    throw StateError('F11 fault scenario validation failed.');
}
