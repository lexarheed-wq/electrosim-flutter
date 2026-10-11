import 'dart:math' as math;

import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';
import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';
import 'package:test/test.dart';

PneumaticDevice _fitting(String id, String port) => PneumaticDevice(
  id: id,
  kind: PneumaticDeviceKind.manifold,
  ports: <PneumaticPort>[
    PneumaticPort(
      id: PneumaticPortId(port),
      deviceId: id,
      role: PneumaticPortRole.work,
    ),
  ],
);

PneumaticNetwork _twoFittings({
  PneumaticPipeFault fault = PneumaticPipeFault.none,
  PneumaticPipeLossModel lossModel = PneumaticPipeLossModel.effectiveOrifice,
}) => PneumaticNetwork(
  devices: <PneumaticDevice>[_fitting('a', 'a-P'), _fitting('b', 'b-P')],
  pipes: <PneumaticPipe>[
    PneumaticPipe(
      id: 'hose1',
      fromPortId: PneumaticPortId('a-P'),
      toPortId: PneumaticPortId('b-P'),
      lengthM: .5,
      innerDiameterM: .004,
      fault: fault,
      lossModel: lossModel,
    ),
  ],
);

final IsentropicOrifice _orifice = IsentropicOrifice(
  effectiveAreaM2: 1e-6,
  dischargeCoefficient: .8,
);

Map<String, RigidFittingCalibration>
_fittings() => <String, RigidFittingCalibration>{
  'a': RigidFittingCalibration(volumeM3: .002, initialPressureAbsPa: 701325),
  'b': RigidFittingCalibration(volumeM3: .002, initialPressureAbsPa: 101325),
};

Map<String, HoseVolumeCalibration> _hoses() => <String, HoseVolumeCalibration>{
  'hose1': HoseVolumeCalibration(
    firstEndOrifice: _orifice,
    secondEndOrifice: _orifice,
    initialPressureAbsPa: 101325,
  ),
};

void main() {
  group('R2/B physical identity bridge', () {
    test('PHY-02: canonical port IDs preserve mass including hose volume', () {
      final CanonicalClosedNetwork compiled =
          ClosedPneumaticNetworkCompiler.compile(
            network: _twoFittings(),
            fittings: _fittings(),
            hoses: _hoses(),
          );
      expect(compiled.portToChamberId[PneumaticPortId('a-P')], 'a');
      expect(compiled.portToChamberId[PneumaticPortId('b-P')], 'b');
      expect(compiled.hoseToChamberId['hose1'], 'pipe.hose1');
      expect(compiled.solver.passages.length, 2);
      final before = compiled.solver.initialSnapshot;
      expect(before.chambers.length, 3);
      final double expectedHoseVolume = math.pi * .004 * .004 * .5 / 4;
      expect(
        before.chambers['pipe.hose1']!.volumeM3,
        closeTo(expectedHoseVolume, 1e-16),
      );
      final after = compiled.solver.advance(before, durationS: 1);
      expect(
        after.totalMassKg,
        closeTo(before.totalMassKg, before.totalMassKg * 1e-8),
      );
      expect(
        after.chambers['a']!.pressureAbsPa,
        lessThan(before.chambers['a']!.pressureAbsPa),
      );
      expect(
        after.chambers['b']!.pressureAbsPa,
        greaterThan(before.chambers['b']!.pressureAbsPa),
      );
      expect(before.timeS, 0);
      expect(after.timeS, 1);
    });

    test('ERR-02: reject missing hose calibration instead of inventing Cd', () {
      expect(
        () => ClosedPneumaticNetworkCompiler.compile(
          network: _twoFittings(),
          fittings: _fittings(),
          hoses: <String, HoseVolumeCalibration>{},
        ),
        throwsA(
          isA<PneumaticPhysicsException>().having(
            (e) => e.code,
            'code',
            'missing_hose_calibration',
          ),
        ),
      );
    });

    test('ERR-03: unsupported valve cannot silently behave like a tank', () {
      final PneumaticNetwork network = PneumaticNetwork(
        devices: <PneumaticDevice>[
          PneumaticDevice(
            id: 'v1',
            kind: PneumaticDeviceKind.valve52,
            ports: <PneumaticPort>[
              PneumaticPort(
                id: PneumaticPortId('P'),
                deviceId: 'v1',
                role: PneumaticPortRole.supply,
              ),
            ],
          ),
        ],
      );
      expect(
        () => ClosedPneumaticNetworkCompiler.compile(
          network: network,
          fittings: <String, RigidFittingCalibration>{
            'v1': RigidFittingCalibration(
              volumeM3: 1e-4,
              initialPressureAbsPa: 701325,
            ),
          },
          hoses: <String, HoseVolumeCalibration>{},
        ),
        throwsA(
          isA<PneumaticPhysicsException>().having(
            (e) => e.code,
            'code',
            'unsupported_r2b_device',
          ),
        ),
      );
    });

    test('ERR-04: unknown loss physics and fault are not hidden', () {
      for (final PneumaticNetwork network in <PneumaticNetwork>[
        _twoFittings(fault: PneumaticPipeFault.leaking),
        _twoFittings(lossModel: PneumaticPipeLossModel.distributedDarcy),
      ]) {
        expect(
          () => ClosedPneumaticNetworkCompiler.compile(
            network: network,
            fittings: _fittings(),
            hoses: _hoses(),
          ),
          throwsA(
            isA<PneumaticPhysicsException>().having(
              (e) => e.code,
              'code',
              'unsupported_r2b_hose',
            ),
          ),
        );
      }
    });

    test('ERR-05: reject unknown fitting calibration and ID collisions', () {
      final Map<String, RigidFittingCalibration> extra = _fittings();
      extra['unknown'] = RigidFittingCalibration(
        volumeM3: 1e-3,
        initialPressureAbsPa: 101325,
      );
      expect(
        () => ClosedPneumaticNetworkCompiler.compile(
          network: _twoFittings(),
          fittings: extra,
          hoses: _hoses(),
        ),
        throwsA(
          isA<PneumaticPhysicsException>().having(
            (e) => e.code,
            'code',
            'missing_fitting_calibration',
          ),
        ),
      );
      final PneumaticNetwork colliding = PneumaticNetwork(
        devices: <PneumaticDevice>[
          _fitting('pipe.hose1', 'a-P'),
          _fitting('b', 'b-P'),
        ],
        pipes: _twoFittings().pipes,
      );
      final Map<String, RigidFittingCalibration> conflicting = _fittings();
      conflicting['pipe.hose1'] = conflicting.remove('a')!;
      expect(
        () => ClosedPneumaticNetworkCompiler.compile(
          network: colliding,
          fittings: conflicting,
          hoses: _hoses(),
        ),
        throwsA(
          isA<PneumaticPhysicsException>().having(
            (e) => e.code,
            'code',
            'chamber_id_collision',
          ),
        ),
      );
    });

    test('R2/B: empty network remains exactly empty and side-effect free', () {
      final CanonicalClosedNetwork compiled =
          ClosedPneumaticNetworkCompiler.compile(
            network: PneumaticNetwork(),
            fittings: <String, RigidFittingCalibration>{},
            hoses: <String, HoseVolumeCalibration>{},
          );
      expect(compiled.solver.initialSnapshot.totalMassKg, 0);
      expect(compiled.portToChamberId, isEmpty);
      expect(compiled.hoseToChamberId, isEmpty);
    });
  });
}
