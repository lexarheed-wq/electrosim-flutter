import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';
import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';

import 'self_hold_circuit.dart';
import 'self_hold_valve52_cycle.dart';
import 'solenoid_actuator.dart';
import 'pneumatic_telemetry.dart';

/// An explicitly labeled, calibrated generic demonstration: the exact
/// electrical project passed to SolverDC is also retained with the
/// electropneumatic 5/2 valve link. This fixture must not be confused with
/// compilation of arbitrary wires and pipes edited by the workshop user.
final class PneumaticReferenceCycle {
  PneumaticReferenceCycle._({required this.project, required this.cycle});

  final MultiphysicsProject project;
  final SelfHoldValve52Cycle cycle;

  static PneumaticReferenceCycle build({
    double supplyVoltageV = 24,
    double pressureAbsPa = 701325,
    double strokeM = .06,
  }) {
    if (!supplyVoltageV.isFinite ||
        supplyVoltageV < 0 ||
        !pressureAbsPa.isFinite ||
        pressureAbsPa <= 101325 ||
        !strokeM.isFinite ||
        strokeM <= .006) {
      throw ArgumentError('Invalid generic reference cycle calibration.');
    }
    Terminal t(String id) => Terminal(id: TerminalId(id), name: id);
    ComponentInstance contact(
      String id,
      String kind,
      String left,
      String right,
    ) => ComponentInstance(
      id: ComponentId(id),
      modelType: kind,
      terminals: <Terminal>[t(left), t(right)],
      controlState: <String, Object?>{
        if (kind == 'switch') 'closed': false,
        if (kind != 'switch') 'actuated': false,
      },
    );
    ComponentInstance winding(
      String id,
      String left,
      String right,
      double resistanceOhm,
    ) => ComponentInstance(
      id: ComponentId(id),
      modelType: 'resistor',
      terminals: <Terminal>[t(left), t(right)],
      parameters: <String, Object?>{'resistanceOhm': resistanceOhm},
    );
    Connection wire(String id, String from, String to) => Connection(
      id: ConnectionId(id),
      fromTerminalId: TerminalId(from),
      toTerminalId: TerminalId(to),
    );
    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('pneu-reference-24v-5-2'),
      revision: 0,
      mode: ElectricalMode.dc,
      components: <ComponentInstance>[
        contact('s1', 'switch', 's1a', 's1b'),
        contact('k1-contact', 'relay_contact_no', 'k1a', 'k1b'),
        contact('b1', 'relay_contact_nc', 'b1a', 'b1b'),
        winding('k1-winding', 'k1c', 'k1d', 480),
        winding('y1', 'y1a', 'y1b', 240),
      ],
      connections: <Connection>[
        wire('w1', 'vp', 's1a'),
        wire('w2', 'vp', 'k1a'),
        wire('w3', 's1b', 'b1a'),
        wire('w4', 'k1b', 'b1a'),
        wire('w5', 'b1b', 'k1c'),
        wire('w6', 'b1b', 'y1a'),
        wire('w7', 'k1d', 'vn'),
        wire('w8', 'y1b', 'vn'),
      ],
      sources: <SourceInstance>[
        SourceInstance(
          id: SourceId('supply'),
          modelType: 'dc_voltage_source',
          terminals: <Terminal>[
            Terminal(
              id: TerminalId('vp'),
              name: '+',
              role: TerminalRole.positive,
              phase: PhaseTag.dcPositive,
            ),
            Terminal(
              id: TerminalId('vn'),
              name: '-',
              role: TerminalRole.negative,
              phase: PhaseTag.dcNegative,
            ),
          ],
          parameters: <String, Object?>{'voltageV': supplyVoltageV},
        ),
      ],
    );
    final ElectropneumaticLink y1 = ElectropneumaticLink(
      id: 'y1-to-valve',
      electricalComponentId: 'y1',
      pneumaticDeviceId: 'valve',
      role: ElectropneumaticLinkRole.solenoidCoil,
    );
    PneumaticDevice device(
      String id,
      PneumaticDeviceKind kind,
      List<(String, PneumaticPortRole)> labels,
    ) => PneumaticDevice(
      id: id,
      kind: kind,
      ports: <PneumaticPort>[
        for (final (String label, PneumaticPortRole role) in labels)
          PneumaticPort(
            id: PneumaticPortId('$id.$label'),
            deviceId: id,
            role: role,
          ),
      ],
    );
    final MultiphysicsProject model = MultiphysicsProject(
      electricalCircuit: circuit,
      pneumaticNetwork: PneumaticNetwork(
        devices: <PneumaticDevice>[
          device(
            'source',
            PneumaticDeviceKind.idealSource,
            <(String, PneumaticPortRole)>[('P', PneumaticPortRole.supply)],
          ),
          device(
            'valve',
            PneumaticDeviceKind.valve52,
            <(String, PneumaticPortRole)>[
              ('P', PneumaticPortRole.supply),
              ('A', PneumaticPortRole.work),
              ('B', PneumaticPortRole.work),
              ('R', PneumaticPortRole.exhaust),
              ('S', PneumaticPortRole.exhaust),
            ],
          ),
          device(
            'cylinder',
            PneumaticDeviceKind.doubleActingCylinder,
            <(String, PneumaticPortRole)>[
              ('A', PneumaticPortRole.work),
              ('B', PneumaticPortRole.work),
            ],
          ),
        ],
      ),
      devices: <PhysicalDeviceRecord>[
        PhysicalDeviceRecord(id: 'source-body', pneumaticDeviceId: 'source'),
        PhysicalDeviceRecord(
          id: 'valve-body',
          pneumaticDeviceId: 'valve',
          electricalComponentIds: <String>['y1'],
        ),
        PhysicalDeviceRecord(
          id: 'cylinder-body',
          pneumaticDeviceId: 'cylinder',
          electricalComponentIds: <String>['b1'],
        ),
      ],
      links: <ElectropneumaticLink>[
        y1,
        ElectropneumaticLink(
          id: 'b1-to-cylinder',
          electricalComponentId: 'b1',
          pneumaticDeviceId: 'cylinder',
          role: ElectropneumaticLinkRole.positionContact,
        ),
      ],
    );
    final IsentropicOrifice orifice = IsentropicOrifice(
      effectiveAreaM2: 3e-6,
      dischargeCoefficient: .8,
    );
    PneumaticPressureBoundary boundary(String name, double p) =>
        PneumaticPressureBoundary(id: name, pressureAbsPa: p, orifice: orifice);
    final MovingDoubleActingAirCylinder cylinder =
        MovingDoubleActingAirCylinder.fromPressure(
          geometry: DoubleActingCylinderGeometry(
            pistonDiameterM: .032,
            rodDiameterM: .008,
            strokeM: strokeM,
            deadVolumeAM3: .0005,
            deadVolumeBM3: .0005,
          ),
          mechanics: CylinderMechanicalCalibration(
            movingMassKg: 1,
            staticBreakawayFrictionN: 3,
            coulombFrictionN: 2,
          ),
          initialPositionM: .005,
          initialPressureAAbsPa: 101325,
          initialPressureBAbsPa: 101325,
        );
    return PneumaticReferenceCycle._(
      project: model,
      cycle: SelfHoldValve52Cycle(
        electrical: SelfHold24vElectricalCycle(
          project: model,
          binding: SelfHold24vBinding(
            startComponentId: 's1',
            holdContactComponentId: 'k1-contact',
            endStopComponentId: 'b1',
            relayWindingComponentId: 'k1-winding',
            valveSolenoidLink: y1,
          ),
        ),
        cylinder: cylinder,
        routing: Valve52CylinderRouting(
          supplyA: boundary('P.to.A', pressureAbsPa),
          supplyB: boundary('P.to.B', pressureAbsPa),
          exhaustA: boundary('A.to.R', 101325),
          exhaustB: boundary('B.to.S', 101325),
        ),
        endSensor: PositionEndContact(
          strokeM: strokeM,
          triggerPositionM: strokeM - .001,
          releasePositionM: strokeM - .005,
          normallyOpen: false,
        ),
        solenoid: Solenoid24vDynamics(Solenoid24vCalibration()),
        maxStepS: .00075,
      ),
    );
  }

  SelfHoldValve52Snapshot initial() => cycle.initial();

  PneumaticCylinderTelemetry read(SelfHoldValve52Snapshot state) =>
      PneumaticTelemetryReader.cylinder(model: cycle.cylinder, accepted: state);
}
