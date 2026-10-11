import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';
import 'package:test/test.dart';

void main() {
  test('R6/N native isolate executes canonical physics and preserves mass',
      () async {
    final IsothermalAirNetwork network = IsothermalAirNetwork(
      chambers: <FixedAirChamber>[
        FixedAirChamber.fromPressure(
          id: 'a', volumeM3: .002, pressureAbsPa: 220000,
        ),
        FixedAirChamber.fromPressure(
          id: 'b', volumeM3: .002, pressureAbsPa: 120000,
        ),
      ],
      passages: <AirPassage>[
        AirPassage(
          id: 'tube',
          firstChamberId: 'a',
          secondChamberId: 'b',
          orifice: IsentropicOrifice(
            effectiveAreaM2: 1e-7,
            dischargeCoefficient: .8,
          ),
        ),
      ],
    );
    final R6NetworkJob job = R6NetworkJob(
      projectRevision: 3,
      requestId: 7,
      engineVersion: 'r6n-v1',
      network: network,
      before: network.initialSnapshot,
      durationS: .04,
      maxStepS: .004,
    );
    final R6Worker worker = await createR6Worker();
    try {
      final R6NetworkOutcome actual = await worker.solve(job);
      final IsothermalAirSnapshot direct = job.execute().snapshot;
      expect(actual.requestId, 7);
      expect(actual.projectRevision, 3);
      expect(actual.snapshot.timeS, .04);
      expect(actual.snapshot.totalMassKg, closeTo(direct.totalMassKg, 1e-12));
      expect(actual.snapshot.chambers['a']!.massKg,
          closeTo(direct.chambers['a']!.massKg, 1e-12));
    } finally {
      await worker.close();
    }
    expect(() => worker.solve(job), throwsStateError);
  });

  test('R6/N serialized job cannot accept NaN and invalid solver input', () {
    final IsothermalAirNetwork network = IsothermalAirNetwork(
      chambers: <FixedAirChamber>[
        FixedAirChamber.fromPressure(
          id: 'a', volumeM3: .01, pressureAbsPa: 100000,
        ),
      ],
      passages: <AirPassage>[],
    );
    expect(
      () => R6NetworkJob(
        projectRevision: 0,
        requestId: 1,
        engineVersion: 'r6n-v1',
        network: network,
        before: network.initialSnapshot,
        durationS: double.nan,
        maxStepS: .01,
      ),
      throwsArgumentError,
    );
  });
}
