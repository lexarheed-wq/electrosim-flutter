import 'package:electrosim_electropneumatic/electrosim_electropneumatic.dart';
import 'package:test/test.dart';

void main() {
  test(
    'R6/C example uses exactly one real DC circuit and its measured 5/2',
    () {
      final PneumaticReferenceCycle reference = PneumaticReferenceCycle.build();
      final String unchanged = reference.project.electricalCircuit
          .toJsonString();
      final SelfHoldValve52Snapshot initial = reference.initial();
      final PneumaticCylinderTelemetry begin = reference.read(initial);
      expect(begin.timeS, 0);
      expect(begin.positionMm, 5);
      expect(reference.project.pneumaticNetwork.devices, hasLength(3));
      expect(reference.project.links, hasLength(2));

      final SelfHoldValve52Snapshot started = reference.cycle.advance(
        initial,
        durationS: 0,
        startPressed: true,
      );
      expect(started.electrical!.relay.energized, isTrue);
      expect(started.electrical!.valveReading.voltageV, closeTo(24, 1e-9));
      SelfHoldValve52Snapshot running = reference.cycle.advance(
        started,
        durationS: .025,
        startPressed: false,
      );
      expect(running.spool, ValveSpoolSide.coilSide);
      expect(reference.read(running).positionMm, greaterThan(begin.positionMm));
      bool sensed = false;
      for (int i = 0; i < 140; i++) {
        final SelfHoldValve52Snapshot next = reference.cycle.advance(
          running,
          durationS: .005,
          startPressed: false,
        );
        expect(next.timeS, greaterThan(running.timeS));
        expect(reference.read(next).massResidualKg.abs(), lessThan(1e-8));
        running = next;
        if (running.endStopActuated) {
          sensed = true;
          expect(running.electrical!.relay.energized, isFalse);
          break;
        }
      }
      expect(sensed, isTrue);
      expect(reference.project.electricalCircuit.toJsonString(), unchanged);
      expect(initial.timeS, 0);
      final SelfHoldValve52Snapshot paused = reference.cycle.advance(
        running,
        durationS: .5,
        startPressed: false,
        paused: true,
      );
      expect(identical(paused, running), isTrue);
    },
  );

  test('R6/C rejects false source/stroke calibration', () {
    expect(
      () => PneumaticReferenceCycle.build(supplyVoltageV: -1),
      throwsArgumentError,
    );
    expect(
      () => PneumaticReferenceCycle.build(pressureAbsPa: 100000),
      throwsArgumentError,
    );
    expect(
      () => PneumaticReferenceCycle.build(strokeM: 0),
      throwsArgumentError,
    );
  });
}
