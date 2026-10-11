import 'package:electrosim_electropneumatic/electrosim_electropneumatic.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';
import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';
import 'package:test/test.dart';

import 'r3_self_hold_test.dart' as dc;

PneumaticDevice airBoundary(
  String id,
  PneumaticDeviceKind kind,
  double pressure,
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
  parametersSi: <String, double>{'pressureAbsPa': pressure},
);

PneumaticDevice fiveTwo() => PneumaticDevice(
  id: 'valve',
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
        id: PneumaticPortId('valve.$name'),
        deviceId: 'valve',
        role: role,
      ),
  ],
  parametersSi: <String, double>{
    'portDeadVolumeM3': .00001,
    'pressureAbsPa': 101325,
    'valveEffectiveAreaM2': .000004,
    'valveCd': .8,
    'energized': 0,
  },
);

PneumaticDevice piston() => PneumaticDevice(
  id: 'cylinder',
  kind: PneumaticDeviceKind.doubleActingCylinder,
  ports: <PneumaticPort>[
    for (final String name in <String>['A', 'B'])
      PneumaticPort(
        id: PneumaticPortId('cylinder.$name'),
        deviceId: 'cylinder',
        role: PneumaticPortRole.work,
      ),
  ],
  parametersSi: <String, double>{
    'pistonDiameterM': .032,
    'rodDiameterM': .008,
    'strokeM': .06,
    'deadVolumeAM3': .00005,
    'deadVolumeBM3': .00005,
    'initialPositionM': .005,
    'initialPressureAAbsPa': 101325,
    'initialPressureBAbsPa': 101325,
    'movingMassKg': 1,
    'staticBreakawayFrictionN': 3,
    'coulombFrictionN': 2,
  },
);

PneumaticPipe tube(String id, String a, String b) => PneumaticPipe(
  id: id,
  fromPortId: PneumaticPortId(a),
  toPortId: PneumaticPortId(b),
  lengthM: .2,
  innerDiameterM: .003,
  lossCoefficient: 1,
);

MultiphysicsProject physicalProject({double supplyVoltage = 24}) {
  final MultiphysicsProject original = dc.project(supplyV: supplyVoltage);
  return MultiphysicsProject(
    electricalCircuit: original.electricalCircuit,
    pneumaticNetwork: PneumaticNetwork(
      devices: <PneumaticDevice>[
        airBoundary('air', PneumaticDeviceKind.idealSource, 701325),
        airBoundary('outR', PneumaticDeviceKind.silencer, 101325),
        airBoundary('outS', PneumaticDeviceKind.silencer, 101325),
        fiveTwo(),
        piston(),
      ],
      pipes: <PneumaticPipe>[
        tube('P', 'air.1', 'valve.P'),
        tube('A', 'valve.A', 'cylinder.A'),
        tube('B', 'valve.B', 'cylinder.B'),
        tube('R', 'valve.R', 'outR.1'),
        tube('S', 'valve.S', 'outS.1'),
      ],
    ),
    devices: <PhysicalDeviceRecord>[
      ...original.devices,
      for (final String id in <String>['air', 'outR', 'outS'])
        PhysicalDeviceRecord(id: id, pneumaticDeviceId: id),
    ],
    links: original.links,
    physicalLayout: original.physicalLayout,
    schematicLayout: original.schematicLayout,
  );
}

AuthoredNetworkSelfHoldValve52Cycle buildCycle({double supplyVoltage = 24}) {
  final SelfHold24vElectricalCycle electrical = SelfHold24vElectricalCycle(
    project: physicalProject(supplyVoltage: supplyVoltage),
    binding: SelfHold24vBinding(
      startComponentId: 's1',
      holdContactComponentId: 'k1-contact',
      endStopComponentId: 'b1',
      relayWindingComponentId: 'k1-winding',
      valveSolenoidLink: dc.y1Link(),
    ),
  );
  return AuthoredNetworkSelfHoldValve52Cycle(
    electrical: electrical,
    compiler: const WorkshopClosedAirCompiler(dischargeCoefficient: .8),
    valveDeviceId: 'valve',
    cylinderDeviceId: 'cylinder',
    endSensor: PositionEndContact(
      strokeM: .06,
      triggerPositionM: .059,
      releasePositionM: .055,
      normallyOpen: false,
    ),
    solenoid: Solenoid24vDynamics(Solenoid24vCalibration()),
    maxStepS: .0005,
    mechanicalStepS: .00005,
  );
}

void main() {
  test('R6/J authored hoses DC S1/K1/Y1 switch valve without gas reset', () {
    final AuthoredNetworkSelfHoldValve52Cycle cycle = buildCycle();
    final AuthoredNetworkSelfHoldSnapshot initial = cycle.initial();
    final AuthoredNetworkSelfHoldSnapshot pressed = cycle.advance(
      initial,
      durationS: 0,
      startPressed: true,
    );
    expect(pressed.timeS, 0);
    expect(pressed.electrical!.relay.energized, isTrue);
    expect(pressed.electrical!.valveReading.voltageV, closeTo(24, 1e-9));
    expect(pressed.spool, ValveSpoolSide.coilSide);
    expect(pressed.air.air.totalMassKg, initial.air.air.totalMassKg);
    expect(pressed.physical.pneumaticAdvances, 0);

    final AuthoredNetworkSelfHoldSnapshot latched = cycle.advance(
      pressed,
      durationS: .025,
      startPressed: false,
    );
    expect(latched.electrical!.relay.energized, isTrue);
    expect(latched.spool, ValveSpoolSide.coilSide);
    expect(latched.timeS, closeTo(.025, 1e-10));
    expect(latched.air.timeS, latched.timeS);
    expect(latched.physical.pneumaticAdvances, greaterThan(0));
    expect(cycle.massBalanceResidualKg(latched).abs(), lessThan(1e-8));
    expect(initial.air.positionM, .005);
    expect(initial.timeS, 0);
  });

  test('R6/J B1 feedback eventually drops measured Y1 on real network', () {
    final AuthoredNetworkSelfHoldValve52Cycle cycle = buildCycle();
    AuthoredNetworkSelfHoldSnapshot snapshot = cycle.advance(
      cycle.initial(),
      durationS: 0,
      startPressed: true,
    );
    snapshot = cycle.advance(snapshot, durationS: .025, startPressed: false);
    bool reached = false;
    for (int i = 0; i < 220; i++) {
      final double timeBefore = snapshot.timeS;
      snapshot = cycle.advance(snapshot, durationS: .005, startPressed: false);
      expect(snapshot.timeS, greaterThan(timeBefore));
      expect(snapshot.air.timeS, snapshot.timeS);
      expect(snapshot.air.positionM, inInclusiveRange(0, .06));
      expect(cycle.massBalanceResidualKg(snapshot).abs(), lessThan(1e-8));
      if (snapshot.endStopActuated) {
        reached = true;
        expect(snapshot.electrical!.relay.energized, false);
        expect(snapshot.electrical!.valveReading.voltageV, closeTo(0, 1e-8));
        expect(snapshot.spool, ValveSpoolSide.springSide);
        break;
      }
    }
    expect(reached, isTrue, reason: 'The physical piston must reach B1.');
    final AuthoredNetworkSelfHoldSnapshot paused = cycle.advance(
      snapshot,
      durationS: .1,
      startPressed: false,
      paused: true,
    );
    expect(identical(paused, snapshot), isTrue);
  });

  test('R6/J DC source turned off cannot energize a fictitious spool', () {
    final AuthoredNetworkSelfHoldValve52Cycle cycle = buildCycle(
      supplyVoltage: 0,
    );
    final AuthoredNetworkSelfHoldSnapshot pressed = cycle.advance(
      cycle.initial(),
      durationS: 0,
      startPressed: true,
    );
    expect(pressed.electrical!.valveReading.voltageV, 0);
    expect(pressed.electrical!.relay.energized, false);
    expect(pressed.spool, ValveSpoolSide.springSide);
    expect(pressed.physical.pneumaticAdvances, 0);
  });
}
