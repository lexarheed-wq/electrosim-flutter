import 'package:electrosim_scenarios/electrosim_scenarios.dart';
import 'package:test/test.dart';

void main() {
  group('CORE-UNIFY product libraries', () {
    final V2ProductLibrary library = buildV2ProductLibrary();

    test('old product fixtures are removed and library restarts empty', () {
      expect(library.version, '3.0.0-core-unify');
      expect(library.schemas, isEmpty);
      expect(library.faultScenarios, isEmpty);
      expect(library.allValidated, isTrue);
      expect(library.allNativeV2, isTrue);
    });
  });
}
