import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';
import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';
import 'package:test/test.dart';

PneumaticDevice source(String id, PneumaticDeviceKind kind, double pressure) =>
    PneumaticDevice(
      id: id,
      kind: kind,
      ports: <PneumaticPort>[
        PneumaticPort(
          id: PneumaticPortId('$id.1'),
          deviceId: id,
          role: kind == PneumaticDeviceKind.idealSource
              ? PneumaticPortRole.supply
              : PneumaticPortRole.exhaust,
        ),
      ],
      parametersSi: <String, double>{'pressureAbsPa': pressure},
    );

PneumaticDevice valve52(double energized) => PneumaticDevice(
  id: 'v52',
  kind: PneumaticDeviceKind.valve52,
  ports: <PneumaticPort>[
    for (final (String name, PneumaticPortRole role)
        in <(String, PneumaticPortRole)>[
      ('P', PneumaticPortRole.supply),
      ('A', PneumaticPortRole.work),
      ('B', PneumaticPortRole.work),
      ('R', PneumaticPortRole.exhaust),
      ('S', PneumaticPortRole.exhaust),
    ])
      PneumaticPort(
        id: PneumaticPortId('v52.$name'),
        deviceId: 'v52',
        role: role,
      ),
  ],
  parametersSi: <String, double>{
    'portDeadVolumeM3': .00001,
    'pressureAbsPa': 101325,
    'valveEffectiveAreaM2': .000004,
    'valveCd': .8,
    'energized': energized,
  },
);

PneumaticDevice cylinder({
  double positionM = 0,
  double pressureA = 101325,
  double pressureB = 101325,
  double strokeM = .06,
  double load = 0,
}) => PneumaticDevice(
  id: 'c1',
  kind: PneumaticDeviceKind.doubleActingCylinder,
  ports: <PneumaticPort>[
    for (final String name in <String>['A', 'B'])
      PneumaticPort(
        id: PneumaticPortId('c1.$name'),
        deviceId: 'c1',
        role: PneumaticPortRole.work,
      ),
  ],
  parametersSi: <String, double>{
    'pistonDiameterM': .032,
    'rodDiameterM': .012,
    'strokeM': strokeM,
    'deadVolumeAM3': .00001,
    'deadVolumeBM3': .00001,
    'initialPositionM': positionM,
    'initialPressureAAbsPa': pressureA,
    'initialPressureBAbsPa': pressureB,
    'movingMassKg': .5,
    'externalLoadN': load,
  },
);

PneumaticPipe hose(String name, String from, String to) => PneumaticPipe(
  id: name,
  fromPortId: PneumaticPortId(from),
  toPortId: PneumaticPortId(to),
  lengthM: .2,
  innerDiameterM: .003,
  lossCoefficient: 1.5,
);

PneumaticNetwork assembled({required double energized}) => PneumaticNetwork(
  devices: <PneumaticDevice>[
    source('supply', PneumaticDeviceKind.idealSource, 701325),
    source('ventR', PneumaticDeviceKind.silencer, 101325),
    source('ventS', PneumaticDeviceKind.silencer, 101325),
    valve52(energized),
    cylinder(),
  ],
  pipes: <PneumaticPipe>[
    hose('P', 'supply.1', 'v52.P'),
    hose('A', 'v52.A', 'c1.A'),
    hose('B', 'v52.B', 'c1.B'),
    hose('R', 'v52.R', 'ventR.1'),
    hose('S', 'v52.S', 'ventS.1'),
  ],
);

void main() {
  const WorkshopClosedAirCompiler compiler =
      WorkshopClosedAirCompiler(dischargeCoefficient: .8);

  test('R6/I real hoses valve and moving piston share mass and clock', () {
    final CoupledMovingCylinderAirNetwork solver =
        compiler.compileWithMovingCylinder(assembled(energized: 1));
    final CoupledCylinderNetworkSnapshot initial = solver.initialSnapshot;
    expect(initial.positionM, 0);
    expect(initial.timeS, 0);
    expect(initial.air.chambers, hasLength(7));
    final CoupledCylinderNetworkSnapshot next = solver.advance(
      initial,
      durationS: .06,
      maxStepS: .00005,
    );
    expect(next.timeS, closeTo(.06, 1e-11));
    expect(next.positionM, greaterThan(0));
    expect(next.positionM, lessThanOrEqualTo(.06));
    expect(next.mechanicalSubsteps, greaterThan(0));
    expect(next.air.acceptedSubsteps, greaterThan(0));
    expect(next.air.externalMassAddedKg, greaterThan(0));
    expect(
      solver.massBalanceResidualKg(next).abs(),
      lessThan(initial.air.totalMassKg * 1e-8),
    );
    expect(
      next.air.chambers['c1.A']!.volumeM3,
      greaterThan(initial.air.chambers['c1.A']!.volumeM3),
    );
    expect(
      next.air.chambers['c1.B']!.volumeM3,
      lessThan(initial.air.chambers['c1.B']!.volumeM3),
    );
    expect(initial.air.chambers['c1.A']!.pressureAbsPa, closeTo(101325, 1e-7));
    final CoupledCylinderNetworkSnapshot repeated = solver.advance(
      initial,
      durationS: .06,
      maxStepS: .00005,
    );
    expect(repeated.positionM, next.positionM);
    expect(repeated.air.externalMassAddedKg, next.air.externalMassAddedKg);
  });

  test('R6/I physically stopped piston localizes impact without mass loss', () {
    final PneumaticNetwork physical = PneumaticNetwork(
      devices: <PneumaticDevice>[
        cylinder(
          positionM: .001,
          pressureA: 701325,
          pressureB: 101325,
          strokeM: .015,
        ),
      ],
    );
    final CoupledMovingCylinderAirNetwork solver =
        compiler.compileWithMovingCylinder(physical);
    final CoupledCylinderNetworkSnapshot initial = solver.initialSnapshot;
    expect(solver.resultantForceN(initial), closeTo(482.55, .5));
    final CoupledCylinderNetworkSnapshot stopped = solver.advance(
      initial,
      durationS: .08,
      maxStepS: .00005,
      stopAtFirstImpact: true,
    );
    expect(stopped.positionM, closeTo(.015, 1e-12));
    expect(stopped.velocityMPerS, 0);
    expect(stopped.timeS, lessThan(.08));
    expect(stopped.stopEvents, hasLength(1));
    expect(stopped.stopEvents.single.stop, CylinderStop.extended);
    expect(
      solver.massBalanceResidualKg(stopped).abs(),
      lessThan(initial.air.totalMassKg * 1e-9),
    );
    final CoupledCylinderNetworkSnapshot resumed = solver.advance(
      stopped,
      durationS: .005,
    );
    expect(resumed.positionM, closeTo(.015, 1e-9));
    expect(resumed.timeS, greaterThan(stopped.timeS));
  });

  test('R6/I reverse force and heavy load can prevent extension', () {
    final PneumaticNetwork physical = PneumaticNetwork(
      devices: <PneumaticDevice>[
        cylinder(pressureA: 101325, pressureB: 701325, positionM: .04),
      ],
    );
    final CoupledMovingCylinderAirNetwork solver =
        compiler.compileWithMovingCylinder(physical);
    expect(solver.resultantForceN(solver.initialSnapshot), lessThan(0));
    final CoupledCylinderNetworkSnapshot later = solver.advance(
      solver.initialSnapshot,
      durationS: .001,
      maxStepS: .00001,
    );
    expect(later.positionM, lessThan(.04));
    expect(solver.massBalanceResidualKg(later).abs(), lessThan(1e-12));
  });

  test('R6/I invalid or missing physical cylinder parameters reject', () {
    expect(
      () => compiler.compileWithMovingCylinder(
        PneumaticNetwork(devices: <PneumaticDevice>[valve52(0)]),
      ),
      throwsA(
        isA<PneumaticPhysicsException>().having(
          (e) => e.code,
          'code',
          'unsupported_cylinder_count',
        ),
      ),
    );
    final PneumaticDevice missing = PneumaticDevice(
      id: 'bad',
      kind: PneumaticDeviceKind.doubleActingCylinder,
      ports: <PneumaticPort>[
        PneumaticPort(
          id: PneumaticPortId('bad.A'),
          deviceId: 'bad',
          role: PneumaticPortRole.work,
        ),
        PneumaticPort(
          id: PneumaticPortId('bad.B'),
          deviceId: 'bad',
          role: PneumaticPortRole.work,
        ),
      ],
    );
    expect(
      () => compiler.compileWithMovingCylinder(
        PneumaticNetwork(devices: <PneumaticDevice>[missing]),
      ),
      throwsA(
        isA<PneumaticPhysicsException>().having(
          (e) => e.code,
          'code',
          'missing_cylinder_calibration',
        ),
      ),
    );
  });
}
