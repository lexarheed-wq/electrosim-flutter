import 'package:electrosim_electropneumatic/electrosim_electropneumatic.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';
import 'package:test/test.dart';

import 'r6_authored_network_self_hold_test.dart' as authored;

MultiphysicsProject calibrated({double voltageV = 24}) {
  final MultiphysicsProject project =
      authored.physicalProject(supplyVoltage: voltageV);
  final List<PneumaticDevice> devices = <PneumaticDevice>[
    for (final PneumaticDevice d in project.pneumaticNetwork.devices)
      PneumaticDevice(
        id: d.id,
        kind: d.kind,
        ports: d.ports,
        parametersSi: <String, double>{
          ...d.parametersSi,
          if (d.id == 'valve') ...<String, double>{
            'coilNominalVoltageV': 24,
            'coilPickupRatio': .8,
            'coilDropRatio': .35,
            'coilPickupDelayS': .02,
            'coilReleaseDelayS': .01,
          },
          if (d.id == 'cylinder') ...<String, double>{
            'sensorTriggerPositionM': .059,
            'sensorReleasePositionM': .055,
          },
        },
      ),
  ];
  return MultiphysicsProject(
    electricalCircuit: project.electricalCircuit,
    pneumaticNetwork: PneumaticNetwork(
      devices: devices,
      pipes: project.pneumaticNetwork.pipes,
    ),
    devices: project.devices,
    links: project.links,
    physicalLayout: project.physicalLayout,
    schematicLayout: project.schematicLayout,
  );
}

void main() {
  const AuthoredSelfHoldCycleFactory factory = AuthoredSelfHoldCycleFactory();

  test('R6/L Y1 and B1 linked from canonical project without id guessing', () {
    final MultiphysicsProject project = calibrated();
    final AuthoredNetworkSelfHoldValve52Cycle cycle = factory.create(
      project,
      hoseDischargeCoefficient: .8,
    );
    final AuthoredNetworkSelfHoldSnapshot initial = cycle.initial();
    final AuthoredNetworkSelfHoldSnapshot pressed = cycle.advance(
      initial,
      durationS: 0,
      startPressed: true,
    );
    expect(pressed.electrical!.relay.energized, true);
    expect(pressed.electrical!.valveReading.voltageV, closeTo(24, 1e-9));
    expect(pressed.physical.pneumaticAdvances, 0);
    expect(pressed.air.air.totalMassKg, initial.air.air.totalMassKg);
    final AuthoredNetworkSelfHoldSnapshot latched = cycle.advance(
      pressed,
      durationS: .025,
      startPressed: false,
    );
    expect(latched.spool, ValveSpoolSide.coilSide);
    expect(latched.electrical!.relay.energized, true);
    expect(latched.air.positionM, greaterThan(initial.air.positionM));
    expect(cycle.massBalanceResidualKg(latched).abs(), lessThan(1e-8));
    expect(latched.timeS, closeTo(.025, 1e-9));
    expect(project.pneumaticNetwork.devices.first.id, 'air');
  });

  test('R6/L refusing uncalibrated devices is mandatory', () {
    final MultiphysicsProject project = authored.physicalProject();
    expect(
      () => factory.create(project, hoseDischargeCoefficient: .8),
      throwsA(
        isA<ElectropneumaticRuntimeException>().having(
          (e) => e.code,
          'code',
          'missing_pilot_calibration',
        ),
      ),
    );
  });

  test('R6/L DC source at zero never actuates a fitted solenoid', () {
    final AuthoredNetworkSelfHoldValve52Cycle cycle = factory.create(
      calibrated(voltageV: 0),
      hoseDischargeCoefficient: .8,
    );
    final AuthoredNetworkSelfHoldSnapshot pressed = cycle.advance(
      cycle.initial(),
      durationS: .025,
      startPressed: true,
    );
    expect(pressed.electrical!.valveReading.voltageV, closeTo(0, 1e-9));
    expect(pressed.spool, ValveSpoolSide.springSide);
    expect(pressed.electrical!.relay.energized, false);
    expect(cycle.massBalanceResidualKg(pressed).abs(), lessThan(1e-8));
  });
}
