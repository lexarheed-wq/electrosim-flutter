import 'dart:async';
import 'dart:math' as math;
import 'package:electrosim/runtime/industrial_alarm_audio.dart';
import 'package:electrosim/runtime/rotor_motion.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

class _Audio implements AlarmAudioBackend {
  final calls = <Set<AlarmVoice>>[];
  Completer<void>? gate;
  bool disposed = false;
  @override
  Future<void> setActive(Set<AlarmVoice> voices) async {
    calls.add(Set.of(voices));
    if (voices.isNotEmpty && gate != null) await gate!.future;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

CircuitState alarmCircuit({
  bool powered = true,
  bool horn = false,
  String modelType = 'buzzer',
  bool reversed = false,
}) => CircuitState(
  circuitId: CircuitId('audio'),
  revision: 0,
  mode: ElectricalMode.dc,
  sources: [
    SourceInstance(
      id: SourceId('s'),
      modelType: 'dc_voltage_source',
      terminals: [
        Terminal(
          id: TerminalId('s-positive'),
          name: '+',
          role: TerminalRole.positive,
        ),
        Terminal(
          id: TerminalId('s-negative'),
          name: '-',
          role: TerminalRole.negative,
        ),
      ],
      parameters: {'voltageV': 24.0},
    ),
  ],
  components: [
    ComponentInstance(
      id: ComponentId('b'),
      modelType: modelType,
      terminals: [
        Terminal(id: TerminalId('b-positive'), name: '+'),
        Terminal(id: TerminalId('b-negative'), name: '-'),
      ],
      parameters: {'resistanceOhm': 48.0, if (horn) 'soundProfile': 'horn'},
    ),
  ],
  connections: powered
      ? [
          Connection(
            id: ConnectionId('a'),
            fromTerminalId: TerminalId('s-positive'),
            toTerminalId: TerminalId(reversed ? 'b-negative' : 'b-positive'),
          ),
          Connection(
            id: ConnectionId('b'),
            fromTerminalId: TerminalId('s-negative'),
            toTerminalId: TerminalId(reversed ? 'b-positive' : 'b-negative'),
          ),
        ]
      : [],
);

void main() {
  test(
    'alarms require solved powered circuit and running unmuted simulation',
    () {
      final on = const ElectroSimRuntimeEngine().evaluate(alarmCircuit());
      expect(activeAlarmVoices(on, running: true), {AlarmVoice.buzzer});
      expect(activeAlarmVoices(on, running: false), isEmpty);
      expect(activeAlarmVoices(on, running: true, enabled: false), isEmpty);
      expect(
        activeAlarmVoices(
          const ElectroSimRuntimeEngine().evaluate(
            alarmCircuit(powered: false),
          ),
          running: true,
        ),
        isEmpty,
      );
      final horn = const ElectroSimRuntimeEngine().evaluate(
        alarmCircuit(horn: true),
      );
      expect(activeAlarmVoices(horn, running: true), {AlarmVoice.horn});
    },
  );
  test(
    'sound stops after a delayed play and does not restart on disposal',
    () async {
      final backend = _Audio()..gate = Completer<void>();
      final service = IndustrialAlarmAudio(backend: backend);
      final start = service.update({AlarmVoice.buzzer});
      final stop = service.update({});
      backend.gate!.complete();
      await Future.wait([start, stop]);
      expect(backend.calls, [
        {AlarmVoice.buzzer},
        <AlarmVoice>{},
      ]);
      await service.update({});
      expect(backend.calls, hasLength(2));
      await service.dispose();
      await service.update({AlarmVoice.horn});
      expect(backend.disposed, isTrue);
      expect(backend.calls, hasLength(2));
    },
  );
  test(
    'DC animation uses mechanical speed and reverses with supply polarity',
    () {
      for (final reverse in [false, true]) {
        final circuit = alarmCircuit(modelType: 'motor_dc', reversed: reverse);
        final snapshot = const ElectroSimRuntimeEngine().advance(
          circuit,
          elapsed: const Duration(milliseconds: 20),
        );
        final speed = snapshot.motorAngularSpeedsRadS[ComponentId('b')]!;
        expect(reverse ? speed < 0 : speed > 0, isTrue);
        expect(
          rotorVelocity(
            snapshot,
            circuit.components.first,
            running: true,
            energized: false,
            voltageV: 0,
            ratedVoltageV: 24,
          ),
          closeTo(visibleRotorSpeed(speed), 1e-10),
        );
        expect(
          rotorVelocity(
            snapshot,
            circuit.components.first,
            running: false,
            energized: true,
            voltageV: 24,
            ratedVoltageV: 24,
          ),
          0,
        );
      }
    },
  );
  test(
    'phase makes full rotations, reverses and changes speed without jumps',
    () {
      final phase = RotorPhase();
      expect(phase.advance(0, math.pi), 0);
      expect(phase.advance(.5, math.pi), closeTo(.25, 1e-10));
      expect(phase.advance(.5, 2 * math.pi), closeTo(.25, 1e-10));
      expect(phase.advance(.75, 2 * math.pi), closeTo(.5, 1e-10));
      expect(phase.advance(1, -2 * math.pi), closeTo(.25, 1e-10));
      expect(phase.advance(1.25, -2 * math.pi), closeTo(0, 1e-10));
      expect(phase.advance(10, 0), closeTo(0, 1e-10));
      expect(visibleRotorSpeed(10), lessThan(visibleRotorSpeed(20)));
      expect(visibleRotorSpeed(-10), -visibleRotorSpeed(10));
    },
  );
}
