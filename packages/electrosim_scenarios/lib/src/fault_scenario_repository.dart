import 'fault_scenario_definition.dart';
import 'fault_scenario_validator.dart';

final class FaultScenarioRepository {
  FaultScenarioRepository({
    required List<FaultScenarioDefinition> scenarios,
    FaultScenarioValidator validator = const FaultScenarioValidator(),
  })  : _validator = validator,
        _scenarios = _prepare(scenarios, validator);

  final FaultScenarioValidator _validator;
  final List<FaultScenarioDefinition> _scenarios;

  List<FaultScenarioDefinition> get all => _scenarios;

  FaultScenarioDefinition? findById(FaultScenarioId id) {
    for (final FaultScenarioDefinition scenario in _scenarios) {
      if (scenario.id == id) return scenario;
    }
    return null;
  }

  List<FaultScenarioValidationResult> validateAll() =>
      _scenarios.map<FaultScenarioValidationResult>(_validator.validate).toList(growable: false);

  static List<FaultScenarioDefinition> _prepare(
    List<FaultScenarioDefinition> scenarios,
    FaultScenarioValidator validator,
  ) {
    final Set<FaultScenarioId> ids = <FaultScenarioId>{};
    final List<FaultScenarioDefinition> validated = <FaultScenarioDefinition>[];
    for (final FaultScenarioDefinition scenario in scenarios) {
      if (!ids.add(scenario.id)) {
        throw ArgumentError('Duplicate fault scenario ID: ${scenario.id.value}.');
      }
      final FaultScenarioValidationResult result = validator.validate(scenario);
      if (!result.isValid) {
        final String details = result.issues.map((FaultScenarioValidationIssue issue) => issue.code).join(', ');
        throw ArgumentError('Invalid fault scenario ${scenario.id.value}: $details');
      }
      validated.add(scenario.withValidationStamp(result.stamp));
    }
    return List<FaultScenarioDefinition>.unmodifiable(validated);
  }
}
