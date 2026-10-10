import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_electropneumatic/electrosim_electropneumatic.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';
import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

Terminal terminal(String id, String name) =>
    Terminal(id: TerminalId(id), name: name);

CircuitState circuit({required double voltageV, required bool startClosed}) =>
    CircuitState(
      circuitId: CircuitId('r3-real-24v'),
      revision: startClosed ? 1 : 2,
      mode: ElectricalMode.dc,
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('s1'),
          modelType: 'switch',
          terminals: <Terminal>[
            terminal('s1a', 'A'),
            terminal('s1b', 'B'),
          ],
          controlState: <String, Object?>{'closed': startClosed},
        ),
        ComponentInstance(
          id: ComponentId('y1'),
          modelType: 'resistor',
          terminals: <Terminal>[
            terminal('y1a', 'A1'),
            terminal('y1b', 'A2'),
          ],
          parameters: const <String, Object?>{'resistanceOhm': 240},
        ),
      ],
      connections: <Connection>[
        Connection(
          id: ConnectionId('w1'),
          fromTerminalId: TerminalId('vp'),
          toTerminalId: TerminalId('s1a'),
        ),
        Connection(
          id: ConnectionId('w2'),
          fromTerminalId: TerminalId('s1b'),
          toTerminalId: TerminalId('y1a'),
        ),
        Connection(
          id: ConnectionId('w3'),
          fromTerminalId: TerminalId('y1b'),
          toTerminalId: TerminalId('vn'),
        ),
      ],
      sources: <SourceInstance>[
        SourceInstance(
          id: SourceId('dc24'),
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
          parameters: <String, Object?>{'voltageV': voltageV},
        ),
      ],
    );

ElectropneumaticLink link() => ElectropneumaticLink(
  id: 'y1-valve',
  electricalComponentId: 'y1',
  pneumaticDeviceId: 'valve',
  role: ElectropneumaticLinkRole.solenoidCoil,
);

MultiphysicsProject project(CircuitState electric) => MultiphysicsProject(
  electricalCircuit: electric,
  pneumaticNetwork: PneumaticNetwork(
    devices: <PneumaticDevice>[
      PneumaticDevice(
        id: 'valve',
        kind: PneumaticDeviceKind.valve52,
        ports: <PneumaticPort>[
          PneumaticPort(
            id: PneumaticPortId('valve.P'),
            deviceId: 'valve',
            role: PneumaticPortRole.supply,
          ),
          PneumaticPort(
            id: PneumaticPortId('valve.A'),
            deviceId: 'valve',
            role: PneumaticPortRole.work,
          ),
        ],
      ),
    ],
  ),
  devices: <PhysicalDeviceRecord>[
    PhysicalDeviceRecord(
      id: 'valve-actuator',
      pneumaticDeviceId: 'valve',
      electricalComponentIds: <String>['y1'],
    ),
  ],
  links: <ElectropneumaticLink>[link()],
);

CoilElectricalReading meter({required bool powered, double voltage = 24}) {
  final CircuitState c = circuit(voltageV: voltage, startClosed: powered);
  final DcSolveResult dc = const SolverDC().solve(
    c,
    const TopologyEngine().compile(c),
  );
  expect(dc.status, DcSolveStatus.solved);
  return DcCoilMeter.read(project: project(c), link: link(), result: dc);
}

void main() {
  group('CPL-01 actual electrical 24 V → pneumatic state', () {
    test('solenoid gets real branch current and voltage, not nominal source', () {
      final CoilElectricalReading energized = meter(powered: true);
      expect(energized.voltageV, closeTo(24, 1e-9));
      expect(energized.currentA, closeTo(.1, 1e-9));
      expect(energized.powerW, closeTo(2.4, 1e-9));
      final CoilElectricalReading open = meter(powered: false);
      expect(open.voltageV, closeTo(0, 1e-9));
      expect(open.currentA, 0);
    });

    test('coil voltage below pickup does not energize a valve', () {
      final Solenoid24vDynamics drive = Solenoid24vDynamics(
        Solenoid24vCalibration(),
      );
      final CoilElectricalReading supply = meter(
        powered: true,
        voltage: 10,
      );
      final Solenoid24vSnapshot state = drive.observe(
        const Solenoid24vSnapshot(energized: false, measuredVoltageV: 0),
        nowS: 0,
        measuredVoltageV: supply.voltageV,
      );
      expect(state.energized, isFalse);
      expect(state.transitionDueS, isNull);
    });

    test('stale circuit revision or wrong link is rejected', () {
      final CircuitState c = circuit(voltageV: 24, startClosed: true);
      final DcSolveResult result = const SolverDC().solve(
        c,
        const TopologyEngine().compile(c),
      );
      expect(
        () => DcCoilMeter.read(
          project: project(circuit(voltageV: 24, startClosed: false)),
          link: link(),
          result: result,
        ),
        throwsA(isA<ElectropneumaticRuntimeException>()),
      );
      expect(
        () => DcCoilMeter.read(
          project: project(c),
          link: ElectropneumaticLink(
            id: 'fake',
            electricalComponentId: 'y1',
            pneumaticDeviceId: 'valve',
            role: ElectropneumaticLinkRole.solenoidCoil,
          ),
          result: result,
        ),
        throwsA(isA<ElectropneumaticRuntimeException>()),
      );
    });
  });

  group('CPL-02 single shared clock and pressure-loss distinctions', () {
    test('coil pickup, time-cutoff and retained compressed air', () {
      bool switchClosed = true;
      final FixedAirChamber initial = FixedAirChamber.fromPressure(
        id: 'chamber',
        volumeM3: .002,
        pressureAbsPa: 101325,
      );
      final IsentropicOrifice orifice = IsentropicOrifice(
        effectiveAreaM2: 1e-6,
        dischargeCoefficient: .8,
      );
      int actualAirCalls = 0;
      final ElectropneumaticEventClock<OpenAirSnapshot> clock =
          ElectropneumaticEventClock<OpenAirSnapshot>(
            solenoid: Solenoid24vDynamics(Solenoid24vCalibration()),
            valveMemory: const SingleCoilValveMemory(
              returnKind: ValveReturnKind.monostableSpring,
            ),
            solveElectrical: (air, spool, closed) =>
                meter(powered: switchClosed),
            airTime: (air) => air.timeS,
            advanceAir: (before, dt, valve) {
              actualAirCalls++;
              final OpenIsothermalAirChamber physical =
                  OpenIsothermalAirChamber(
                    initialChamber: initial,
                    boundaries: <PneumaticPressureBoundary>[
                      PneumaticPressureBoundary(
                        id: 'supply',
                        pressureAbsPa: 701325,
                        orifice: orifice,
                        enabled: valve == ValveSpoolSide.coilSide,
                        allowReverseFlow: false,
                      ),
                    ],
                  );
              return physical.advance(before, durationS: dt);
            },
          );
      final OpenAirSnapshot airStart = OpenIsothermalAirChamber(
        initialChamber: initial,
        boundaries: const <PneumaticPressureBoundary>[],
      ).initialSnapshot;

      final initialState = clock.initial(airStart);
      final running = clock.advance(initialState, durationS: .06);
      expect(running.timeS, closeTo(.06, 1e-10));
      expect(running.coil.energized, isTrue);
      expect(running.spool, ValveSpoolSide.coilSide);
      expect(running.air.chamber.pressureAbsPa, greaterThan(101325));
      final double trappedMass = running.air.chamber.massKg;
      expect(running.pneumaticAdvances, actualAirCalls);
      expect(running.electricalSolves, greaterThan(running.pneumaticAdvances));

      switchClosed = false; // Electrical switch off, not an air vent.
      final stopped = clock.advance(running, durationS: .05);
      expect(stopped.timeS, closeTo(.11, 1e-10));
      expect(stopped.coil.energized, isFalse);
      expect(stopped.spool, ValveSpoolSide.springSide);
      expect(stopped.air.chamber.massKg, closeTo(trappedMass, 1e-13));
      expect(stopped.air.externalMassAddedKg,
          closeTo(running.air.externalMassAddedKg, 1e-13));
      expect(stopped.pneumaticAdvances, actualAirCalls);
    });

    test('no pneumatic integration on pure zero-time electrical re-solve', () {
      int airCalls = 0;
      final FixedAirChamber air = FixedAirChamber.fromPressure(
        id: 'fixed',
        volumeM3: .001,
        pressureAbsPa: 201325,
      );
      final OpenAirSnapshot gas = OpenIsothermalAirChamber(
        initialChamber: air,
        boundaries: const <PneumaticPressureBoundary>[],
      ).initialSnapshot;
      final clock = ElectropneumaticEventClock<OpenAirSnapshot>(
        solenoid: Solenoid24vDynamics(
          Solenoid24vCalibration(pickupDelayS: 0),
        ),
        valveMemory: const SingleCoilValveMemory(
          returnKind: ValveReturnKind.monostableSpring,
        ),
        solveElectrical: (a, spool, closed) => meter(powered: true),
        advanceAir: (a, dt, spool) {
          airCalls++;
          return OpenIsothermalAirChamber(
            initialChamber: air,
            boundaries: const <PneumaticPressureBoundary>[],
          ).advance(a, durationS: dt);
        },
        airTime: (a) => a.timeS,
      );
      final settled = clock.advance(clock.initial(gas), durationS: 0);
      expect(settled.spool, ValveSpoolSide.coilSide);
      expect(settled.electricalSolves, greaterThan(1));
      expect(settled.pneumaticAdvances, 0);
      expect(airCalls, 0);
      expect(settled.air.chamber.massKg, gas.chamber.massKg);
    });
  });

  group('CPL-03 event safety and contact physics', () {
    test('NO and NC contact agree on physical sensor hysteresis', () {
      final no = PositionEndContact(
        strokeM: .2,
        triggerPositionM: .199,
        releasePositionM: .195,
        normallyOpen: true,
      );
      final nc = PositionEndContact(
        strokeM: .2,
        triggerPositionM: .199,
        releasePositionM: .195,
        normallyOpen: false,
      );
      expect(no.actuated(previouslyActuated: false, positionM: .19), false);
      expect(no.actuated(previouslyActuated: false, positionM: .2), true);
      expect(no.actuated(previouslyActuated: true, positionM: .197), true);
      expect(no.actuated(previouslyActuated: true, positionM: .194), false);
      expect(no.closed(true), true);
      expect(nc.closed(true), false);
      expect(nc.closed(false), true);
    });

    test('5/2 monostable returns; 5/2 bistable remembers without power', () {
      const spring = SingleCoilValveMemory(
        returnKind: ValveReturnKind.monostableSpring,
      );
      const memory = SingleCoilValveMemory(
        returnKind: ValveReturnKind.bistableMemory,
      );
      expect(
        spring.update(
          previous: ValveSpoolSide.coilSide,
          coilEnergized: false,
        ),
        ValveSpoolSide.springSide,
      );
      expect(
        memory.update(
          previous: ValveSpoolSide.coilSide,
          coilEnergized: false,
        ),
        ValveSpoolSide.coilSide,
      );
      expect(
        () => const DualCoilBistableMemory().update(
          previous: ValveSpoolSide.springSide,
          coilToSpring: true,
          coilToActuated: true,
        ),
        throwsA(isA<ElectropneumaticRuntimeException>()),
      );
    });

    test('invalid feedback never advances physical air', () {
      final FixedAirChamber air = FixedAirChamber.fromPressure(
        id: 'single',
        volumeM3: .001,
        pressureAbsPa: 201325,
      );
      final gas = OpenIsothermalAirChamber(
        initialChamber: air,
        boundaries: const <PneumaticPressureBoundary>[],
      ).initialSnapshot;
      int physicalCalls = 0;
      final clock = ElectropneumaticEventClock<OpenAirSnapshot>(
        solenoid: Solenoid24vDynamics(Solenoid24vCalibration()),
        valveMemory: const SingleCoilValveMemory(
          returnKind: ValveReturnKind.monostableSpring,
        ),
        solveElectrical: (a, v, c) =>
            const CoilElectricalReading(
              linkId: 'y1-valve',
              voltageV: double.nan,
              currentA: 0,
              powerW: 0,
            ),
        advanceAir: (a, dt, v) {
          physicalCalls++;
          return a;
        },
        airTime: (a) => a.timeS,
      );
      expect(
        () => clock.advance(clock.initial(gas), durationS: 1),
        throwsA(isA<ElectropneumaticRuntimeException>()),
      );
      expect(physicalCalls, 0);
      expect(gas.timeS, 0);
    });
  });
}
