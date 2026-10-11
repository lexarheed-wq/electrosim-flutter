import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';
import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';
import 'package:test/test.dart';

PneumaticDevice boundary(String id, PneumaticDeviceKind kind, double p) =>
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
      parametersSi: <String, double>{'pressureAbsPa': p},
    );

PneumaticDevice valve32(
  double energized, {
  bool invalidPort = false,
  double? deadVolumeM3 = .00001,
}) => PneumaticDevice(
  id: 'v32',
  kind: PneumaticDeviceKind.valve32,
  ports: <PneumaticPort>[
    for (final (String id, PneumaticPortRole role)
        in <(String, PneumaticPortRole)>[
          ('P', PneumaticPortRole.supply),
          ('A', PneumaticPortRole.work),
          ('R', PneumaticPortRole.exhaust),
        ])
      PneumaticPort(
        id: PneumaticPortId('v32.' + (invalidPort && id == 'R' ? 'X' : id)),
        deviceId: 'v32',
        role: role,
      ),
  ],
  parametersSi: <String, double>{
    if (deadVolumeM3 != null) 'portDeadVolumeM3': deadVolumeM3,
    'pressureAbsPa': 101325,
    'valveEffectiveAreaM2': .000003,
    'valveCd': .8,
    'energized': energized,
  },
);

PneumaticDevice manifold() => PneumaticDevice(
  id: 'ch',
  kind: PneumaticDeviceKind.manifold,
  ports: <PneumaticPort>[
    PneumaticPort(
      id: PneumaticPortId('ch.1'),
      deviceId: 'ch',
      role: PneumaticPortRole.work,
    ),
  ],
  parametersSi: <String, double>{'volumeM3': .0003, 'pressureAbsPa': 201325},
);

PneumaticPipe hose(String id, String from, String to) => PneumaticPipe(
  id: id,
  fromPortId: PneumaticPortId(from),
  toPortId: PneumaticPortId(to),
  lengthM: .25,
  innerDiameterM: .003,
  lossCoefficient: 1,
);

PneumaticNetwork graph({
  required double energized,
  bool invalidPort = false,
  double? deadVolumeM3 = .00001,
}) => PneumaticNetwork(
  devices: <PneumaticDevice>[
    boundary('source', PneumaticDeviceKind.idealSource, 601325),
    boundary('ambient', PneumaticDeviceKind.silencer, 101325),
    valve32(energized, invalidPort: invalidPort, deadVolumeM3: deadVolumeM3),
    manifold(),
  ],
  pipes: <PneumaticPipe>[
    hose('source', 'source.1', 'v32.P'),
    hose('work', 'v32.A', 'ch.1'),
    if (!invalidPort) hose('vent', 'v32.R', 'ambient.1'),
  ],
);

void main() {
  const WorkshopClosedAirCompiler compiler = WorkshopClosedAirCompiler(
    dischargeCoefficient: .8,
  );

  test('R6/K 3/2 energized connects source to working chamber', () {
    final IsothermalAirNetwork solver = compiler.compileWithStaticValves(
      graph(energized: 1),
    );
    final Set<String> routes = solver.passages.map((p) => p.id).toSet();
    expect(routes, contains('v32.PtoA'));
    expect(routes, isNot(contains('v32.AtoR')));
    expect(solver.initialSnapshot.chambers, hasLength(4));
    final IsothermalAirSnapshot result = solver.advance(
      solver.initialSnapshot,
      durationS: .035,
      maxStepS: .0005,
    );
    expect(result.chambers['ch']!.pressureAbsPa, greaterThan(201325));
    expect(result.passageMassFlowKgPerS['v32.PtoA'], greaterThan(0));
    expect(
      solver.massBalanceResidualKg(result).abs(),
      lessThan(solver.initialSnapshot.totalMassKg * 1e-9),
    );
  });

  test('R6/K 3/2 rest exhausts A and seals source P', () {
    final IsothermalAirNetwork solver = compiler.compileWithStaticValves(
      graph(energized: 0),
    );
    final Set<String> routes = solver.passages.map((p) => p.id).toSet();
    expect(routes, contains('v32.AtoR'));
    expect(routes, isNot(contains('v32.PtoA')));
    final IsothermalAirSnapshot next = solver.advance(
      solver.initialSnapshot,
      durationS: .035,
      maxStepS: .0005,
    );
    expect(next.chambers['ch']!.pressureAbsPa, lessThan(201325));
    expect(
      solver.massBalanceResidualKg(next).abs(),
      lessThan(solver.initialSnapshot.totalMassKg * 1e-9),
    );
  });

  test('R6/K 3/2 unsupported route or invalid calibration fails closed', () {
    expect(
      () => compiler.compileWithStaticValve52(graph(energized: 1)),
      throwsA(
        isA<PneumaticPhysicsException>().having(
          (e) => e.code,
          'code',
          'unsupported_device',
        ),
      ),
    );
    for (final PneumaticNetwork bad in <PneumaticNetwork>[
      graph(energized: 2),
      graph(energized: 1, deadVolumeM3: null),
      graph(energized: 0, invalidPort: true),
    ]) {
      expect(
        () => compiler.compileWithStaticValves(bad),
        throwsA(isA<PneumaticPhysicsException>()),
      );
    }
  });
}
