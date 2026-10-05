import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_measurements/electrosim_measurements.dart';
import 'package:test/test.dart';

void main() {
  const ReceiverLoadClassifier loads = ReceiverLoadClassifier();
  const ProtectionDynamicsEngine protections = ProtectionDynamicsEngine();

  group('M6 receiver load states', () {
    test('validated receiver thresholds remain exact', () {
      final ComponentInstance load = _load(10.0);
      expect(
        loads.evaluate(component: load, currentA: 0)!.code,
        ReceiverLoadCode.off,
      );
      expect(
        loads.evaluate(component: load, currentA: 7.4)!.code,
        ReceiverLoadCode.underload,
      );
      expect(
        loads.evaluate(component: load, currentA: 7.5)!.code,
        ReceiverLoadCode.normal,
      );
      expect(
        loads.evaluate(component: load, currentA: 10.5)!.code,
        ReceiverLoadCode.normal,
      );
      expect(
        loads.evaluate(component: load, currentA: 10.5001)!.code,
        ReceiverLoadCode.overload,
      );
      expect(
        loads.evaluate(component: load, currentA: 15.0)!.code,
        ReceiverLoadCode.overload,
      );
      expect(
        loads.evaluate(component: load, currentA: 15.0001)!.code,
        ReceiverLoadCode.severeOverload,
      );
    });

    test('receiver rating is independent from protection rating', () {
      final ComponentInstance load = _load(1.5);
      final ReceiverLoadState state = loads.evaluate(
        component: load,
        currentA: 3.0,
      )!;
      expect(state.code, ReceiverLoadCode.severeOverload);
      expect(state.loadRatio, closeTo(2.0, 1e-12));

      final ComponentInstance breaker = _protection(
        modelType: 'breaker_dc',
        ratedCurrentA: 5.0,
      );
      expect(protections.zone(breaker, 3.0), ProtectionZone.normal);
      expect(protections.tripTimeSeconds(breaker, 3.0), double.infinity);
    });
  });

  group('M6 protection dynamics', () {
    test('5 A breaker at 4.59 A remains armed', () {
      final ComponentInstance breaker = _protection(
        modelType: 'breaker_dc',
        ratedCurrentA: 5.0,
      );
      expect(protections.zone(breaker, 4.59), ProtectionZone.normal);
      expect(protections.shouldOpenInstantaneously(breaker, 4.59), isFalse);
    });

    test(
      'curve C magnetic threshold is 5-10 x In and hard opening at 10 x',
      () {
        final ComponentInstance breaker = _protection(
          modelType: 'breaker_dc',
          ratedCurrentA: 5.0,
          parameters: const <String, Object?>{'tripCurve': 'C'},
        );
        expect(protections.zone(breaker, 25.0), ProtectionZone.magneticFast);
        expect(protections.shouldOpenInstantaneously(breaker, 25.0), isFalse);
        expect(
          protections.zone(breaker, 50.0),
          ProtectionZone.magneticInstantaneous,
        );
        expect(protections.shouldOpenInstantaneously(breaker, 50.0), isTrue);
        expect(
          protections.tripTimeSeconds(breaker, 50.0),
          closeTo(0.02, 1e-12),
        );
      },
    );

    test('thermal overload does not have a magnetic instantaneous band', () {
      final ComponentInstance thermal = _protection(
        modelType: 'thermal_overload_3p',
        ratedCurrentA: 5.0,
      );
      expect(protections.shouldOpenInstantaneously(thermal, 100.0), isFalse);
      expect(protections.tripTimeSeconds(thermal, 5.0), double.infinity);
      expect(protections.tripTimeSeconds(thermal, 10.0), closeTo(120.0, 1e-8));
    });

    test('exposure integrates simulation time and cools when normal', () {
      final ComponentInstance breaker = _protection(
        modelType: 'breaker_dc',
        ratedCurrentA: 5.0,
      );
      final double tripTime = protections.tripTimeSeconds(breaker, 12.75);
      expect(tripTime, closeTo(60.0, 1e-8));

      final ProtectionExposureState half = protections.advance(
        component: breaker,
        currentA: 12.75,
        elapsed: const Duration(seconds: 30),
      );
      expect(half.exposure, closeTo(0.5, 1e-8));
      expect(half.shouldTrip, isFalse);

      final ProtectionExposureState tripped = protections.advance(
        component: breaker,
        currentA: 12.75,
        elapsed: const Duration(seconds: 30),
        previous: half,
      );
      expect(tripped.exposure, closeTo(1.0, 1e-8));
      expect(tripped.shouldTrip, isTrue);

      final ProtectionExposureState cooled = protections.advance(
        component: breaker,
        currentA: 0.0,
        elapsed: const Duration(seconds: 30),
        previous: tripped,
      );
      expect(cooled.exposure, closeTo(0.9, 1e-8));
    });

    test('fuse curve remains distinct from breaker B/C/D curves', () {
      final ComponentInstance fuse = _protection(
        modelType: 'fuse_dc',
        ratedCurrentA: 2.0,
      );
      expect(protections.tripTimeSeconds(fuse, 2.0), double.infinity);
      expect(protections.tripTimeSeconds(fuse, 20.0), closeTo(0.02, 1e-12));
    });
  });
}

ComponentInstance _load(double ratedCurrentA) => ComponentInstance(
  id: ComponentId('m1'),
  modelType: 'motor_dc',
  terminals: <Terminal>[
    Terminal(id: TerminalId('m1a'), name: '+'),
    Terminal(id: TerminalId('m1b'), name: '-'),
  ],
  parameters: <String, Object?>{
    'resistanceOhm': 8.0,
    ReceiverNominalRating.currentKey: ratedCurrentA,
  },
);

ComponentInstance _protection({
  required String modelType,
  required double ratedCurrentA,
  Map<String, Object?> parameters = const <String, Object?>{},
}) => ComponentInstance(
  id: ComponentId('q1'),
  modelType: modelType,
  terminals: <Terminal>[
    Terminal(id: TerminalId('q1a'), name: 'IN'),
    Terminal(id: TerminalId('q1b'), name: 'OUT'),
  ],
  parameters: <String, Object?>{
    ProtectionRating.ratedCurrentKey: ratedCurrentA,
    ...parameters,
  },
);
