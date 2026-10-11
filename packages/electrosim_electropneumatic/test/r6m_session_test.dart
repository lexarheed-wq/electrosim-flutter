import 'package:electrosim_electropneumatic/electrosim_electropneumatic.dart';
import 'package:test/test.dart';

import 'r6_authored_network_self_hold_test.dart' as fixture;

void main() {
  test('R6/M pause/resume and reset preserve accepted gas state', () {
    final AuthoredCycleSession session = AuthoredCycleSession(fixture.buildCycle());
    final initial = session.snapshot;
    session.advance(durationS: 0, startPressed: true);
    final atStart = session.snapshot;
    expect(atStart.electrical!.relay.energized, isTrue);
    session.pause();
    expect(
      identical(session.advance(durationS: 0.02, startPressed: false), atStart),
      isTrue,
    );
    session.resume();
    session.advance(durationS: .025, startPressed: false);
    final running = session.snapshot;
    expect(running.timeS, closeTo(.025, 1e-9));
    expect(running.air.air.totalMassKg, isNot(initial.air.air.totalMassKg));
    session.reset();
    expect(session.paused, isTrue);
    expect(session.snapshot.timeS, 0);
    expect(session.snapshot.air.air.totalMassKg, initial.air.air.totalMassKg);
  });

  test('R6/M DC cut uses solved zero source and blocks false restart', () {
    final AuthoredCycleSession session = AuthoredCycleSession(fixture.buildCycle());
    session.advance(durationS: 0, startPressed: true);
    session.advance(durationS: .025, startPressed: false);
    session.setPowerEnabled(false);
    final before = session.snapshot;
    session.advance(durationS: 0, startPressed: true);
    expect(session.snapshot.electrical!.relay.energized, isFalse);
    expect(session.snapshot.electrical!.valveReading.voltageV, closeTo(0, 1e-9));
    expect(session.snapshot.air.air.totalMassKg, before.air.air.totalMassKg);
    expect(session.snapshot.physical.pneumaticAdvances, before.physical.pneumaticAdvances);
    session.advance(durationS: .002, startPressed: true);
    expect(session.snapshot.electrical!.relay.energized, isFalse);
  });

  test('R6/M air isolation preserves chambers and signed mass ledger', () {
    final AuthoredCycleSession session = AuthoredCycleSession(fixture.buildCycle());
    session.advance(durationS: 0, startPressed: true);
    session.advance(durationS: .025, startPressed: false);
    session.setAirSupplyEnabled(false);
    final before = session.snapshot;
    session.advance(durationS: .002, startPressed: false);
    final after = session.snapshot;
    expect(after.timeS, greaterThan(before.timeS));
    expect(after.air.air.chambers.keys, unorderedEquals(before.air.air.chambers.keys));
    expect(session.cycle.massBalanceResidualKg(after).abs(), lessThan(1e-8));
  });

  test('R6/M failed step rolls back without fictitious success', () {
    final AuthoredCycleSession session = AuthoredCycleSession(fixture.buildCycle());
    final before = session.snapshot;
    expect(() => session.advance(durationS: double.nan, startPressed: true),
        throwsArgumentError);
    expect(identical(session.snapshot, before), isTrue);
    expect(identical(session.snapshot, before), isTrue);
    expect(session.lastFailure, isNotNull);
  });
}
