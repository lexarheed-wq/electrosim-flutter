import 'package:electrosim_scenarios/electrosim_scenarios.dart';

void main() {
  final ExampleRepository repository = buildF10ExampleRepository();
  final results = repository.validateAll();
  final failed = results.where((result) => !result.isValid).toList(growable: false);
  if (failed.isNotEmpty) {
    for (final result in failed) {
      print('${result.exampleId.value}: ${result.issues.map((issue) => issue.code).join(',')}');
    }
    throw StateError('F10 example validation failed.');
  }
  print('F10_EXAMPLE_VALIDATOR_PASS ${results.length}/${results.length}');
}
