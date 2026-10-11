import 'package:test/test.dart';

import '../benchmark/r6_scale_fixture.dart';

void main() {
  group('R6 performance fixtures are physical, reproducible and safe', () {
    for (final int count in <int>[30, 100, 200, 400]) {
      test('$count calibrated gas volumes with closed mass ledger', () {
        final R6PhysicalScaleCase fixture = R6PhysicalScaleCase(count);
        expect(fixture.solver.initialSnapshot.chambers, hasLength(count));
        expect(fixture.solver.passages, hasLength(count - 1));
        final initial = fixture.solver.initialSnapshot;
        final accepted = fixture.simulate();
        final repeated = fixture.simulate();
        expect(accepted.chambers.keys.toSet(), initial.chambers.keys.toSet());
        expect(accepted.acceptedSubsteps, greaterThan(0));
        expect(accepted.totalMassKg,
            closeTo(initial.totalMassKg, initial.totalMassKg * 1e-9));
        expect(accepted.totalMassKg, repeated.totalMassKg);
        expect(accepted.timeS, .04);
        expect(initial.timeS, 0);
        expect(initial.acceptedSubsteps, 0);
        expect(initial.chambers['fitting.0']!.pressureAbsPa, closeTo(200000, 1e-8));
      });
    }

    test('Invalid physical size rejected without building partial graph', () {
      expect(() => R6PhysicalScaleCase(1), throwsArgumentError);
      expect(() => R6PhysicalScaleCase(10001), throwsArgumentError);
    });
  });
}
