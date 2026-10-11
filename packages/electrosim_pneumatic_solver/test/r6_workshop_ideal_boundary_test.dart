import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';
import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';
import 'package:test/test.dart';

PneumaticDevice finiteNode(String id, double pressure) => PneumaticDevice(
  id: id,
  kind: PneumaticDeviceKind.manifold,
  ports: <PneumaticPort>[
    for (int i = 1; i <= 3; i++)
      PneumaticPort(
        id: PneumaticPortId('$id.$i'),
        deviceId: id,
        role: PneumaticPortRole.work,
      ),
  ],
  parametersSi: <String, double>{
    'volumeM3': .002,
    'pressureAbsPa': pressure,
  },
);

PneumaticDevice fixedBoundary(
  String id,
  PneumaticDeviceKind kind,
  double? pressure,
) => PneumaticDevice(
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
  parametersSi: <String, double>{
    if (pressure != null) 'pressureAbsPa': pressure,
  },
);

PneumaticPipe hose(
  String id,
  String start,
  String end, {
  PneumaticPipeFault fault = PneumaticPipeFault.none,
  PneumaticPipeLossModel lossModel = PneumaticPipeLossModel.effectiveOrifice,
}) => PneumaticPipe(
  id: id,
  fromPortId: PneumaticPortId(start),
  toPortId: PneumaticPortId(end),
  lengthM: .5,
  innerDiameterM: .001,
  lossCoefficient: 2,
  lossModel: lossModel,
  fault: fault,
);

PneumaticNetwork simpleWorkshop({
  double sourcePressure = 601325,
  double chamberPressure = 201325,
  double ventPressure = 101325,
  PneumaticPipeFault supplyFault = PneumaticPipeFault.none,
}) => PneumaticNetwork(
  devices: <PneumaticDevice>[
    fixedBoundary('supply', PneumaticDeviceKind.idealSource, sourcePressure),
    finiteNode('left', chamberPressure),
    finiteNode('right', 101325),
    fixedBoundary('atmosphere', PneumaticDeviceKind.silencer, ventPressure),
  ],
  pipes: <PneumaticPipe>[
    hose('supply.line', 'supply.1', 'left.1', fault: supplyFault),
    hose('middle.line', 'left.2', 'right.1'),
    hose('vent.line', 'right.2', 'atmosphere.1'),
  ],
);

void main() {
  const WorkshopClosedAirCompiler compiler = WorkshopClosedAirCompiler(
    dischargeCoefficient: .8,
  );

  test('R6/E source and vent exchange measured mass across authored graph', () {
    final IsothermalAirNetwork solver = compiler.compileWithIdealBoundaries(
      simpleWorkshop(),
    );
    expect(solver.boundaries, hasLength(2));
    expect(solver.passages, hasLength(3));
    final IsothermalAirSnapshot initial = solver.initialSnapshot;
    final IsothermalAirSnapshot result = solver.advance(
      initial,
      durationS: .02,
      maxStepS: .001,
    );
    expect(result.chambers['left']!.pressureAbsPa, greaterThan(201325));
    expect(result.chambers['right']!.pressureAbsPa, greaterThan(101325));
    expect(result.passageMassFlowKgPerS['supply.line'], greaterThan(0));
    expect(result.externalMassAddedKg, greaterThan(0));
    expect(
      solver.massBalanceResidualKg(result).abs(),
      lessThan(initial.totalMassKg * 1e-9),
    );
    expect(initial.externalMassAddedKg, 0);
    expect(initial.chambers['left']!.pressureAbsPa, closeTo(201325, 1e-7));
    final IsothermalAirSnapshot repeated = solver.advance(
      initial,
      durationS: .02,
      maxStepS: .001,
    );
    expect(repeated.externalMassAddedKg, result.externalMassAddedKg);
    expect(repeated.chambers['right']!.massKg, result.chambers['right']!.massKg);

    final IsothermalAirSnapshot later = solver.advance(
      result,
      durationS: .02,
      maxStepS: .001,
    );
    expect(later.timeS, closeTo(.04, 1e-12));
    expect(
      solver.massBalanceResidualKg(later).abs(),
      lessThan(initial.totalMassKg * 1e-9),
    );
  });

  test('R6/E pressure boundary permits reverse gradient without fake valve', () {
    final IsothermalAirNetwork solver = compiler.compileWithIdealBoundaries(
      simpleWorkshop(sourcePressure: 101325, chamberPressure: 601325),
    );
    final IsothermalAirSnapshot result = solver.advance(
      solver.initialSnapshot,
      durationS: .002,
      maxStepS: .0002,
    );
    expect(result.passageMassFlowKgPerS['supply.line'], lessThan(0));
    expect(result.externalMassAddedKg, lessThan(0));
    expect(result.chambers['left']!.pressureAbsPa, lessThan(601325));
    expect(
      solver.massBalanceResidualKg(result).abs(),
      lessThan(solver.initialSnapshot.totalMassKg * 1e-9),
    );
  });

  test('R6/E physically blocked supply cannot secretly inject air', () {
    final IsothermalAirNetwork solver = compiler.compileWithIdealBoundaries(
      simpleWorkshop(supplyFault: PneumaticPipeFault.blocked),
    );
    final IsothermalAirSnapshot result = solver.advance(
      solver.initialSnapshot,
      durationS: .02,
      maxStepS: .001,
    );
    expect(result.passageMassFlowKgPerS.containsKey('supply.line'), isFalse);
    expect(result.chambers['left']!.pressureAbsPa, lessThan(201325));
    expect(
      solver.massBalanceResidualKg(result).abs(),
      lessThan(solver.initialSnapshot.totalMassKg * 1e-9),
    );
  });

  test('R6/E closed compiler remains closed and unsupported models fail', () {
    expect(
      () => compiler.compile(simpleWorkshop()),
      throwsA(
        isA<PneumaticPhysicsException>().having(
          (e) => e.code,
          'code',
          'unsupported_device',
        ),
      ),
    );
    final PneumaticNetwork missingPressure = PneumaticNetwork(
      devices: <PneumaticDevice>[
        fixedBoundary('supply', PneumaticDeviceKind.idealSource, null),
        finiteNode('a', 101325),
      ],
      pipes: <PneumaticPipe>[hose('line', 'supply.1', 'a.1')],
    );
    expect(
      () => compiler.compileWithIdealBoundaries(missingPressure),
      throwsA(
        isA<PneumaticPhysicsException>().having(
          (e) => e.code,
          'code',
          'missing_physical_calibration',
        ),
      ),
    );
    final PneumaticDevice valve = PneumaticDevice(
      id: 'valve',
      kind: PneumaticDeviceKind.valve52,
      ports: <PneumaticPort>[
        PneumaticPort(
          id: PneumaticPortId('valve.P'),
          deviceId: 'valve',
          role: PneumaticPortRole.supply,
        ),
      ],
    );
    expect(
      () => compiler.compileWithIdealBoundaries(
        PneumaticNetwork(devices: <PneumaticDevice>[valve]),
      ),
      throwsA(
        isA<PneumaticPhysicsException>().having(
          (e) => e.code,
          'code',
          'unsupported_device',
        ),
      ),
    );
  });

  test('R6/E rejects direct source to vent with no modeled volume', () {
    final PneumaticNetwork network = PneumaticNetwork(
      devices: <PneumaticDevice>[
        fixedBoundary('supply', PneumaticDeviceKind.idealSource, 601325),
        fixedBoundary('atmosphere', PneumaticDeviceKind.silencer, 101325),
        finiteNode('isolated', 101325),
      ],
      pipes: <PneumaticPipe>[
        hose('direct', 'supply.1', 'atmosphere.1'),
      ],
    );
    expect(
      () => compiler.compileWithIdealBoundaries(network),
      throwsA(
        isA<PneumaticPhysicsException>().having(
          (e) => e.code,
          'code',
          'unsupported_boundary_connection',
        ),
      ),
    );
  });
}
