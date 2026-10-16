import 'package:electrosim_controls/electrosim_controls.dart';
import 'package:test/test.dart';

Map<String, Object?> _rung(List<Map<String, Object?>> steps) => <String, Object?>{'steps': steps};
Map<String, Object?> _step(String type, String address, {double? preset}) => <String, Object?>{
  'type': type, 'address': address, if (preset != null) 'presetSeconds': preset,
};

void main() {
  const LadderProgramEngine engine = LadderProgramEngine();

  test('NO and NC contacts evaluate solved boolean inputs', () {
    final result = engine.scan(
      program: <Map<String, Object?>>[
        _rung(<Map<String, Object?>>[_step('contact_no', 'I0'), _step('coil', 'Q0')]),
        _rung(<Map<String, Object?>>[_step('contact_nc', 'I1'), _step('coil', 'Q1')]),
      ], inputs: <String, bool>{'I0': true, 'I1': false}, previous: LadderRuntimeState(), elapsed: Duration.zero,
    );
    expect(result.state.outputs['Q0'], isTrue);
    expect(result.state.outputs['Q1'], isTrue);
  });

  test('SET and RESET hold memory between scans', () {
    final set = engine.scan(program: <Map<String, Object?>>[
      _rung(<Map<String, Object?>>[_step('contact_no', 'I0'), _step('coil_set', 'Q0')]),
    ], inputs: <String, bool>{'I0': true}, previous: LadderRuntimeState(), elapsed: Duration.zero);
    final held = engine.scan(program: <Map<String, Object?>>[
      _rung(<Map<String, Object?>>[_step('contact_no', 'I1'), _step('coil_set', 'Q0')]),
    ], inputs: const <String, bool>{}, previous: set.state, elapsed: Duration.zero);
    expect(held.state.outputs['Q0'], isTrue);
    final reset = engine.scan(program: <Map<String, Object?>>[
      _rung(<Map<String, Object?>>[_step('contact_no', 'I0'), _step('coil_reset', 'Q0')]),
    ], inputs: <String, bool>{'I0': true}, previous: held.state, elapsed: Duration.zero);
    expect(reset.state.outputs['Q0'], isFalse);
  });

  test('TON accumulates across scans, resets on false, and zero-time solve does not advance', () {
    final program = <Map<String, Object?>>[
      _rung(<Map<String, Object?>>[_step('contact_no', 'I0'), _step('TON', 'T0', preset: 1)]),
      _rung(<Map<String, Object?>>[_step('timer_done', 'T0'), _step('coil', 'Q0')]),
    ];
    final first = engine.scan(program: program, inputs: <String, bool>{'I0': true}, previous: LadderRuntimeState(), elapsed: const Duration(milliseconds: 600));
    final correction = engine.scan(program: program, inputs: <String, bool>{'I0': true}, previous: first.state, elapsed: Duration.zero);
    expect(correction.state.timerDone['T0'], isFalse);
    final second = engine.scan(program: program, inputs: <String, bool>{'I0': true}, previous: correction.state, elapsed: const Duration(milliseconds: 500));
    expect(second.state.timerDone['T0'], isTrue);
    expect(second.state.outputs['Q0'], isTrue);
    final reset = engine.scan(program: program, inputs: const <String, bool>{}, previous: second.state, elapsed: Duration.zero);
    expect(reset.state.timerSeconds['T0'], 0);
    expect(reset.state.timerDone['T0'], isFalse);
  });

  test('invalid programs and negative elapsed time deenergize all outputs', () {
    final result = engine.scan(program: <Map<String, Object?>>[
      _rung(<Map<String, Object?>>[_step('contact_no', 'I99'), _step('coil', 'Q0')]),
    ], inputs: const <String, bool>{}, previous: LadderRuntimeState(outputs: <String, bool>{'Q1': true}), elapsed: Duration.zero);
    expect(result.programError, isTrue);
    expect(result.state.outputs.values, everyElement(isFalse));
    expect(engine.scan(program: const <Map<String, Object?>>[], inputs: const <String, bool>{}, previous: LadderRuntimeState(), elapsed: const Duration(seconds: -1)).programError, isTrue);
  });
}
