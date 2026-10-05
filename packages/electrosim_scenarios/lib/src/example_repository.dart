import 'example_definition.dart';
import 'example_validator.dart';

final class ExampleRepository {
  ExampleRepository({
    required List<ExampleDefinition> examples,
    ExampleValidator validator = const ExampleValidator(),
  }) : _validator = validator,
       _examples = _prepare(examples, validator);

  final ExampleValidator _validator;
  final List<ExampleDefinition> _examples;

  List<ExampleDefinition> get all => _examples;

  ExampleDefinition? findById(CircuitTemplateId id) {
    for (final ExampleDefinition example in _examples) {
      if (example.id == id) return example;
    }
    return null;
  }

  List<ExampleValidationResult> validateAll() =>
      _examples.map<ExampleValidationResult>(_validator.validate).toList(growable: false);

  static List<ExampleDefinition> _prepare(
    List<ExampleDefinition> examples,
    ExampleValidator validator,
  ) {
    final Set<CircuitTemplateId> ids = <CircuitTemplateId>{};
    final List<ExampleDefinition> validated = <ExampleDefinition>[];
    for (final ExampleDefinition example in examples) {
      if (!ids.add(example.id)) {
        throw ArgumentError('Duplicate example ID: ${example.id.value}.');
      }
      final ExampleValidationResult result = validator.validate(example);
      if (!result.isValid) {
        final String details = result.issues.map((ExampleValidationIssue issue) => issue.code).join(', ');
        throw ArgumentError('Invalid example ${example.id.value}: $details');
      }
      validated.add(example.withValidationStamp(result.stamp));
    }
    return List<ExampleDefinition>.unmodifiable(validated);
  }
}
