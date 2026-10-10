import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';
import 'package:test/test.dart';

final IsentropicOrifice orifice = IsentropicOrifice(
  effectiveAreaM2: 1e-6,
  dischargeCoefficient: .8,
);

void main() {
  group('R2-A analytical mass flow (independent oracle)', () {
    final Map<String, dynamic> reference =
        jsonDecode(File('test/fixtures/r2_orifice_oracle.json').readAsStringSync())
            as Map<String, dynamic>;
    final Map<String, dynamic> setup =
        reference['assumptions'] as Map<String, dynamic>;
    final double pu = (setup['upstreamPressureAbsPa'] as num).toDouble();
    final double temp = (setup['temperatureK'] as num).toDouble();
    final List<dynamic> vectors = reference['pressureRatioVectors'] as List<dynamic>;

    for (final dynamic data in vectors) {
      final Map<String, dynamic> v = data as Map<String, dynamic>;
      final double ratio = (v['r'] as num).toDouble();
      final double expected = (v['expectedKgPerSecond'] as num).toDouble();
      final double nlmin = (v['expectedNlPerMin'] as num).toDouble();
      test('PHY-04: orifice analytical ratio $ratio, ${v['regime']}', () {
        final double q = orifice.massFlowKgPerS(
          fromPressureAbsPa: pu,
          toPressureAbsPa: pu * ratio,
          temperatureK: temp,
        );
        expect(q, closeTo(expected, 5e-12));
        expect(orifice.normalizedLitresPerMinute(q), closeTo(nlmin, 1e-7));
      });
    }

    test('PHY-04: the critical pressure ratio is computed, not hardcoded', () {
      expect(orifice.criticalDownstreamUpstreamRatio,
          closeTo((setup['chokedPressureRatio'] as num).toDouble(), 1e-12));
    });

    test('PHY-04: reverse gradients invert signed flow', () {
      final double f = orifice.massFlowKgPerS(
        fromPressureAbsPa: pu,
        toPressureAbsPa: pu * .8,
      );
      final double reverse = orifice.massFlowKgPerS(
        fromPressureAbsPa: pu * .8,
        toPressureAbsPa: pu,
      );
      expect(f, greaterThan(0));
      expect(reverse, closeTo(-f, 1e-14));
      expect(orifice.massFlowKgPerS(
        fromPressureAbsPa: pu,
        toPressureAbsPa: pu,
      ), 0);
    });

    test('PHY-04: malformed pressure, temperature, Cd, A and gamma fail', () {
      expect(
        () => orifice.massFlowKgPerS(
          fromPressureAbsPa: double.nan,
          toPressureAbsPa: 101325,
        ),
        throwsA(isA<PneumaticPhysicsException>()),
      );
      expect(
        () => orifice.massFlowKgPerS(
          fromPressureAbsPa: -1,
          toPressureAbsPa: 101325,
        ),
        throwsA(isA<PneumaticPhysicsException>()),
      );
      expect(
        () => IsentropicOrifice(
          effectiveAreaM2: 1,
          dischargeCoefficient: 1.2,
        ),
        throwsA(isA<PneumaticPhysicsException>()),
      );
      expect(
        () => IsentropicOrifice(
          effectiveAreaM2: 0,
          dischargeCoefficient: .8,
        ),
        throwsA(isA<PneumaticPhysicsException>()),
      );
      expect(
        () => IsentropicOrifice(
          effectiveAreaM2: 1e-6,
          dischargeCoefficient: .8,
          gamma: 1,
        ),
        throwsA(isA<PneumaticPhysicsException>()),
      );
    });
  });

  group('R2 rigid isothermal gas chambers', () {
    test('PHY-01: 32 mm piston at 6 barg delivers 482.5486 N', () {
      final cylinder = DoubleActingCylinderGeometry(
        pistonDiameterM: .032,
        rodDiameterM: 0,
        strokeM: .2,
        deadVolumeAM3: 1e-6,
        deadVolumeBM3: 1e-6,
      );
      expect(cylinder.pistonAreaM2,
          closeTo(math.pi * .032 * .032 / 4, 1e-15));
      expect(
        cylinder.theoreticalForceN(
          pressureAAbsPa: 701325,
          pressureBAbsPa: 101325,
        ),
        closeTo(482.5486315913922, .5),
      );
    });

    test('PHY-06/geometry: rod-side annular area and physical volumes', () {
      final cylinder = DoubleActingCylinderGeometry(
        pistonDiameterM: .032,
        rodDiameterM: .012,
        strokeM: .2,
        deadVolumeAM3: 2e-6,
        deadVolumeBM3: 3e-6,
      );
      expect(cylinder.rodSideAreaM2,
          closeTo(math.pi * (.032 * .032 - .012 * .012) / 4, 1e-15));
      expect(cylinder.volumeAM3(0), 2e-6);
      expect(cylinder.volumeBM3(.2), 3e-6);
      expect(cylinder.volumeAM3(.2), greaterThan(cylinder.volumeAM3(0)));
      expect(
        () => cylinder.volumeAM3(.21),
        throwsA(isA<PneumaticPhysicsException>()),
      );
    });

    test('ideal gas law roundtrip uses absolute pressure', () {
      final double mass = IsothermalAir.massKg(
        pressureAbsPa: 701325,
        volumeM3: .001,
      );
      expect(
        IsothermalAir.pressureAbsPa(massKg: mass, volumeM3: .001),
        closeTo(701325, 1e-8),
      );
      expect(IsothermalAir.pressureGaugePa(701325), 600000);
    });

    test('PHY-02: closed 10 second exchange conserves mass', () {
      final net = IsothermalAirNetwork(
        chambers: <FixedAirChamber>[
          FixedAirChamber.fromPressure(
            id: 'a',
            volumeM3: .002,
            pressureAbsPa: 701325,
          ),
          FixedAirChamber.fromPressure(
            id: 'b',
            volumeM3: .002,
            pressureAbsPa: 101325,
          ),
        ],
        passages: <AirPassage>[
          AirPassage(
            id: 'ab',
            firstChamberId: 'a',
            secondChamberId: 'b',
            orifice: orifice,
          ),
        ],
      );
      final before = net.initialSnapshot;
      final after = net.advance(before, durationS: 10);
      expect(after.totalMassKg,
          closeTo(before.totalMassKg, before.totalMassKg * 1e-8));
      expect(after.chambers['a']!.massKg, greaterThan(0));
      expect(after.chambers['b']!.massKg, greaterThan(0));
      expect(after.chambers['a']!.pressureAbsPa,
          closeTo(after.chambers['b']!.pressureAbsPa, 1));
      expect(before.chambers['a']!.pressureAbsPa, closeTo(701325, 1e-8));
      expect(after.timeS, 10);
      expect(after.acceptedSubsteps, greaterThan(1));
    });

    test('PHY-05: one-way check valve blocks reverse pressure gradient', () {
      final net = IsothermalAirNetwork(
        chambers: <FixedAirChamber>[
          FixedAirChamber.fromPressure(
            id: 'a',
            volumeM3: .002,
            pressureAbsPa: 101325,
          ),
          FixedAirChamber.fromPressure(
            id: 'b',
            volumeM3: .002,
            pressureAbsPa: 701325,
          ),
        ],
        passages: <AirPassage>[
          AirPassage(
            id: 'check',
            firstChamberId: 'a',
            secondChamberId: 'b',
            orifice: orifice,
            reverseFlowAllowed: false,
          ),
        ],
      );
      final before = net.initialSnapshot;
      final after = net.advance(before, durationS: .1);
      expect(after.totalMassKg, closeTo(before.totalMassKg, 1e-13));
      expect(after.chambers['a']!.massKg, before.chambers['a']!.massKg);
      expect(after.passageMassFlowKgPerS['check'], 0);
    });

    test('ERR-01: impossible topology and impossible timestep fail explicitly', () {
      expect(
        () => IsothermalAirNetwork(
          chambers: <FixedAirChamber>[
            FixedAirChamber.fromPressure(
              id: 'a', volumeM3: .001, pressureAbsPa: 101325,
            ),
          ],
          passages: <AirPassage>[
            AirPassage(
              id: 'fault',
              firstChamberId: 'a',
              secondChamberId: 'missing',
              orifice: orifice,
            ),
          ],
        ),
        throwsA(isA<PneumaticPhysicsException>()),
      );
      final net = IsothermalAirNetwork(
        chambers: <FixedAirChamber>[
          FixedAirChamber.fromPressure(
            id: 'a', volumeM3: .001, pressureAbsPa: 101325,
          ),
        ],
        passages: <AirPassage>[],
      );
      expect(
        () => net.advance(
          net.initialSnapshot,
          durationS: 10,
          maxStepS: 1e-6,
          maxSubsteps: 1,
        ),
        throwsA(isA<PneumaticPhysicsException>().having(
          (e) => e.code, 'code', 'substep_limit',
        )),
      );
      expect(net.initialSnapshot.timeS, 0);
    });
  });
}
