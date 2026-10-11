import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';
import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';
import 'package:test/test.dart';

PneumaticDevice manifold(
  String id, {
  double pressure = 101325,
  double volume = .002,
  PneumaticDeviceKind kind = PneumaticDeviceKind.manifold,
}) => PneumaticDevice(
  id: id,
  kind: kind,
  ports: <PneumaticPort>[
    PneumaticPort(
      id: PneumaticPortId('$id.1'),
      deviceId: id,
      role: PneumaticPortRole.work,
    ),
    PneumaticPort(
      id: PneumaticPortId('$id.2'),
      deviceId: id,
      role: PneumaticPortRole.work,
    ),
  ],
  parametersSi: <String, double>{
    'volumeM3': volume,
    'pressureAbsPa': pressure,
  },
);

PneumaticPipe pipe(
  String from,
  String to, {
  PneumaticPipeFault fault = PneumaticPipeFault.none,
  PneumaticPipeLossModel model = PneumaticPipeLossModel.effectiveOrifice,
}) => PneumaticPipe(
  id: '$from.to.$to',
  fromPortId: PneumaticPortId('$from.1'),
  toPortId: PneumaticPortId('$to.1'),
  lengthM: .7,
  innerDiameterM: .002,
  lossCoefficient: 2,
  lossModel: model,
  fault: fault,
);

void main() {
  const WorkshopClosedAirCompiler compiler =
      WorkshopClosedAirCompiler(dischargeCoefficient: .8);

  test('R6/D actual drawn hoses transfer mass between 3 finite chambers', () {
    final PneumaticNetwork network = PneumaticNetwork(
      devices: <PneumaticDevice>[
        manifold('left', pressure: 601325),
        manifold('middle', pressure: 201325),
        manifold('right', pressure: 101325),
      ],
      pipes: <PneumaticPipe>[
        pipe('left', 'middle'),
        PneumaticPipe(
          id: 'middle.to.right',
          fromPortId: PneumaticPortId('middle.2'),
          toPortId: PneumaticPortId('right.1'),
          lengthM: .2,
          innerDiameterM: .002,
          lossCoefficient: 2,
        ),
      ],
    );
    final IsothermalAirNetwork solver = compiler.compile(network);
    expect(solver.passages, hasLength(2));
    final IsothermalAirSnapshot initial = solver.initialSnapshot;
    final IsothermalAirSnapshot next = solver.advance(
      initial,
      durationS: .04,
      maxStepS: .001,
    );
    expect(next.chambers, hasLength(3));
    expect(next.chambers['left']!.pressureAbsPa, lessThan(601325));
    expect(next.chambers['right']!.pressureAbsPa, greaterThan(101325));
    expect(next.totalMassKg,
        closeTo(initial.totalMassKg, initial.totalMassKg * 1e-10));
    expect(next.acceptedSubsteps, greaterThan(0));
    expect(initial.chambers['left']!.pressureAbsPa, closeTo(601325, 1e-8));
    final IsothermalAirSnapshot repeat = solver.advance(
      initial,
      durationS: .04,
      maxStepS: .001,
    );
    expect(repeat.chambers['right']!.pressureAbsPa,
        next.chambers['right']!.pressureAbsPa);
    expect(repeat.passageMassFlowKgPerS, next.passageMassFlowKgPerS);
  });

  test('R6/D a blocked hose really isolates finite air mass', () {
    final PneumaticNetwork network = PneumaticNetwork(
      devices: <PneumaticDevice>[
        manifold('left', pressure: 601325),
        manifold('right', pressure: 101325),
      ],
      pipes: <PneumaticPipe>[
        pipe('left', 'right', fault: PneumaticPipeFault.blocked),
      ],
    );
    final IsothermalAirNetwork solver = compiler.compile(network);
    expect(solver.passages, isEmpty);
    final IsothermalAirSnapshot initial = solver.initialSnapshot;
    final IsothermalAirSnapshot next =
        solver.advance(initial, durationS: .1);
    expect(next.chambers['left']!.pressureAbsPa, closeTo(601325, 1e-8));
    expect(next.chambers['right']!.pressureAbsPa, closeTo(101325, 1e-8));
    expect(next.totalMassKg, initial.totalMassKg);
  });

  test('R6/D reversing gradient reverses direction without swapping wires',
      () {
    final PneumaticNetwork reverse = PneumaticNetwork(
      devices: <PneumaticDevice>[
        manifold('left', pressure: 101325),
        manifold('right', pressure: 601325),
      ],
      pipes: <PneumaticPipe>[pipe('left', 'right')],
    );
    final IsothermalAirNetwork solver = compiler.compile(reverse);
    final IsothermalAirSnapshot next = solver.advance(
      solver.initialSnapshot,
      durationS: .005,
      maxStepS: .001,
    );
    expect(next.passageMassFlowKgPerS.values.single, lessThan(0));
    expect(next.chambers['left']!.pressureAbsPa, greaterThan(101325));
  });

  test('R6/D uncalibrated or unsupported source/valve never fakes physics',
      () {
    final PneumaticDevice invalid = PneumaticDevice(
      id: 'supply',
      kind: PneumaticDeviceKind.idealSource,
      ports: <PneumaticPort>[
        PneumaticPort(
          id: PneumaticPortId('supply.P'),
          deviceId: 'supply',
          role: PneumaticPortRole.supply,
        ),
      ],
    );
    expect(
      () => compiler.compile(PneumaticNetwork(devices: <PneumaticDevice>[invalid])),
      throwsA(isA<PneumaticPhysicsException>()
          .having((e) => e.code, 'code', 'unsupported_device')),
    );
    final PneumaticDevice absent = PneumaticDevice(
      id: 't',
      kind: PneumaticDeviceKind.tee,
      ports: <PneumaticPort>[
        PneumaticPort(
          id: PneumaticPortId('t.A'),
          deviceId: 't',
          role: PneumaticPortRole.work,
        ),
      ],
    );
    expect(
      () => compiler.compile(PneumaticNetwork(devices: <PneumaticDevice>[absent])),
      throwsA(isA<PneumaticPhysicsException>()
          .having((e) => e.code, 'code', 'missing_physical_calibration')),
    );
  });

  test('R6/D cannot pretend to simulate faults needing open atmosphere',
      () {
    for (final PneumaticPipeFault bad in <PneumaticPipeFault>[
      PneumaticPipeFault.leaking,
      PneumaticPipeFault.disconnected,
    ]) {
      expect(
        () => compiler.compile(PneumaticNetwork(
          devices: <PneumaticDevice>[manifold('a'), manifold('b')],
          pipes: <PneumaticPipe>[pipe('a', 'b', fault: bad)],
        )),
        throwsA(isA<PneumaticPhysicsException>()
            .having((e) => e.code, 'code', 'unsupported_pipe_fault')),
      );
    }
    expect(
      () => compiler.compile(PneumaticNetwork(
        devices: <PneumaticDevice>[manifold('a'), manifold('b')],
        pipes: <PneumaticPipe>[
          pipe('a', 'b', model: PneumaticPipeLossModel.distributedDarcy),
        ],
      )),
      throwsA(isA<PneumaticPhysicsException>()
          .having((e) => e.code, 'code', 'unsupported_loss_model')),
    );
  });
}
