import 'package:electrosim_scenarios/electrosim_scenarios.dart';
import 'package:test/test.dart';

void main() {
  group('F10 ExampleRepository', () {
    final ExampleRepository repository = buildF10ExampleRepository();

    test('starts deliberately small with three healthy examples', () {
      expect(repository.all, hasLength(3));
      expect(
        repository.all.map((ExampleDefinition e) => e.id.value).toSet(),
        hasLength(3),
      );
    });

    test('validator is 100 percent green', () {
      final results = repository.validateAll();
      expect(results, hasLength(repository.all.length));
      expect(results.every((r) => r.isValid), isTrue);
    });

    test(
      'every published example carries a deterministic validation stamp',
      () {
        for (final ExampleDefinition example in repository.all) {
          expect(example.validationStamp, isNotNull);
          expect(
            example.validationStamp!.validatorVersion,
            ExampleValidator.validatorVersion,
          );
          expect(
            example.validationStamp!.contentDigestFnv1a64,
            matches(RegExp(r'^[0-9a-f]{16}$')),
          );
        }
      },
    );

    test('findById resolves only repository examples', () {
      expect(repository.findById(CircuitTemplateId('EX-DC-001')), isNotNull);
      expect(repository.findById(CircuitTemplateId('EX-DC-999')), isNull);
    });
  });
}
