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

PneumaticDevice manifold(String id, double p) => PneumaticDevice(
  id: id,
  kind: PneumaticDeviceKind.manifold,
  ports: <PneumaticPort>[
    PneumaticPort(
      id: PneumaticPortId('$id.1'),
      deviceId: id,
      role: PneumaticPortRole.work,
    ),
  ],
  parametersSi: <String, double>{'pressureAbsPa': p, 'volumeM3': .002},
);

PneumaticDevice valve(
  double energized, {
  bool badPort = false,
  double? area = .000001,
  double valveCd = .8,
}) => PneumaticDevice(
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
        id: PneumaticPortId('v52.${badPort && name == 'S' ? 'X' : name}'),
        deviceId: 'v52',
        role: role,
      ),
  ],
  parametersSi: <String, double>{
    'portDeadVolumeM3': .0002,
    'pressureAbsPa': 101325,
    if (area != null) 'valveEffectiveAreaM2': area,
    'valveCd': valveCd,
    'energized': energized,
  },
);

PneumaticPipe hose(String id, String from, String to) => PneumaticPipe(
  id: id,
  fromPortId: PneumaticPortId(from),
  toPortId: PneumaticPortId(to),
  lengthM: .5,
  innerDiameterM: .002,
  lossCoefficient: 2,
);

PneumaticNetwork circuit({
  required double energized,
  bool badPort = false,
  double? area = .000001,
  double valveCd = .8,
}) => PneumaticNetwork(
  devices: <PneumaticDevice>[
    boundary('source', PneumaticDeviceKind.idealSource, 601325),
    boundary('ventR', PneumaticDeviceKind.silencer, 101325),
    boundary('ventS', PneumaticDeviceKind.silencer, 101325),
    valve(energized, badPort: badPort, area: area, valveCd: valveCd),
    manifold('a', 101325),
    manifold('b', 601325),
  ],
  pipes: <PneumaticPipe>[
    hose('source-to-P', 'source.1', 'v52.P'),
    hose('A-to-a', 'v52.A', 'a.1'),
    hose('B-to-b', 'v52.B', 'b.1'),
    hose('R-to-vent', 'v52.R', 'ventR.1'),
    if (!badPort) hose('S-to-vent', 'v52.S', 'ventS.1'),
  ],
);

void main() {
  const WorkshopClosedAirCompiler compiler = WorkshopClosedAirCompiler(
    dischargeCoefficient: .8,
  );

  test('R6/G energised P-A B-S paths and conservation', () {
    final IsothermalAirNetwork solver = compiler.compileWithStaticValve52(
      circuit(energized: 1),
    );
    expect(solver.initialSnapshot.chambers, hasLength(7));
    expect(solver.boundaries, hasLength(3));
    final Set<String> ids = solver.passages.map((p) => p.id).toSet();
    expect(ids, containsAll(<String>['v52.PtoA', 'v52.BtoS']));
    expect(ids, isNot(contains('v52.PtoB')));
    expect(ids, isNot(contains('v52.AtoR')));
    final IsothermalAirSnapshot start = solver.initialSnapshot;
    final IsothermalAirSnapshot next = solver.advance(
      start,
      durationS: .05,
      maxStepS: .0001,
    );
    expect(next.chambers['v52.A']!.pressureAbsPa, greaterThan(101325));
    expect(next.chambers['v52.B']!.pressureAbsPa, greaterThan(101325));
    expect(next.chambers['b']!.pressureAbsPa, lessThan(601325));
    expect(
      solver.massBalanceResidualKg(next).abs(),
      lessThan(start.totalMassKg * 1e-9),
    );
    final IsothermalAirSnapshot duplicate = solver.advance(
      start,
      durationS: .05,
      maxStepS: .0001,
    );
    expect(duplicate.totalMassKg, next.totalMassKg);
    expect(duplicate.passageMassFlowKgPerS, next.passageMassFlowKgPerS);
  });

  test('R6/G rest P-B A-R paths and conserved gas', () {
    final IsothermalAirNetwork solver = compiler.compileWithStaticValve52(
      circuit(energized: 0),
    );
    final Set<String> ids = solver.passages.map((p) => p.id).toSet();
    expect(ids, containsAll(<String>['v52.PtoB', 'v52.AtoR']));
    expect(ids, isNot(contains('v52.PtoA')));
    expect(ids, isNot(contains('v52.BtoS')));
    final IsothermalAirSnapshot next = solver.advance(
      solver.initialSnapshot,
      durationS: .05,
      maxStepS: .0001,
    );
    expect(next.chambers['v52.B']!.pressureAbsPa, greaterThan(101325));
    expect(
      solver.massBalanceResidualKg(next).abs(),
      lessThan(solver.initialSnapshot.totalMassKg * 1e-9),
    );
  });

  test('R6/G uncalibrated valve and invalid ISO ports fail closed', () {
    expect(
      () => compiler.compileWithIdealBoundaries(circuit(energized: 1)),
      throwsA(isA<PneumaticPhysicsException>().having(
        (e) => e.code, 'code', 'unsupported_device',
      )),
    );
    for (final PneumaticNetwork invalid in <PneumaticNetwork>[
      circuit(energized: 1, area: null),
      circuit(energized: 2),
      circuit(energized: 0, valveCd: 1.2),
      circuit(energized: 0, badPort: true),
    ]) {
      expect(
        () => compiler.compileWithStaticValve52(invalid),
        throwsA(isA<PneumaticPhysicsException>()),
      );
    }
  });

  test('R6/G initial gas snapshot is immutable after advancing', () {
    final IsothermalAirNetwork solver = compiler.compileWithStaticValve52(
      circuit(energized: 1),
    );
    final IsothermalAirSnapshot before = solver.initialSnapshot;
    solver.advance(before, durationS: .01, maxStepS: .0001);
    expect(before.timeS, 0);
    expect(before.externalMassAddedKg, 0);
    expect(before.chambers['v52.P']!.pressureAbsPa, closeTo(101325, 1e-6));
  });
}
