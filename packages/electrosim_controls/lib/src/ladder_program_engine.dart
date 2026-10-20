/// Persistent PLC state. Timers use seconds so scans remain deterministic.
final class LadderRuntimeState {
  LadderRuntimeState({
    Map<String, bool> outputs = const <String, bool>{},
    Map<String, bool> memories = const <String, bool>{},
    Map<String, double> timerSeconds = const <String, double>{},
    Map<String, bool> timerDone = const <String, bool>{},
  }) : outputs = Map<String, bool>.unmodifiable(<String, bool>{
         for (int i = 0; i < 4; i++) 'Q$i': outputs['Q$i'] ?? false,
       }),
       memories = Map<String, bool>.unmodifiable(<String, bool>{
         for (int i = 0; i < 16; i++) 'M$i': memories['M$i'] ?? false,
       }),
       timerSeconds = Map<String, double>.unmodifiable(<String, double>{
         for (int i = 0; i < 16; i++) 'T$i': timerSeconds['T$i'] ?? 0.0,
       }),
       timerDone = Map<String, bool>.unmodifiable(<String, bool>{
         for (int i = 0; i < 16; i++) 'T$i': timerDone['T$i'] ?? false,
       });
  final Map<String, bool> outputs;
  final Map<String, bool> memories;
  final Map<String, double> timerSeconds;
  final Map<String, bool> timerDone;
}

final class LadderScanResult {
  const LadderScanResult({required this.state, required this.programError});
  final LadderRuntimeState state;
  final bool programError;
}

/// Pure deterministic scan for the supported ElectroSim Ladder subset.
final class LadderProgramEngine {
  const LadderProgramEngine();

  LadderScanResult scan({
    required List<Map<String, Object?>> program,
    required Map<String, bool> inputs,
    required LadderRuntimeState previous,
    required Duration elapsed,
  }) {
    if (elapsed.isNegative || !_validProgram(program)) {
      return LadderScanResult(state: LadderRuntimeState(), programError: true);
    }
    final Map<String, bool> q = Map<String, bool>.from(previous.outputs);
    final Map<String, bool> m = Map<String, bool>.from(previous.memories);
    final Map<String, double> seconds = Map<String, double>.from(previous.timerSeconds);
    final Map<String, bool> done = Map<String, bool>.from(previous.timerDone);
    final Set<String> activeTimers = <String>{};

    for (final Map<String, Object?> rung in program) {
      final List<Map<String, Object?>> steps = (rung['steps']! as List<Object?>)
          .cast<Map<String, Object?>>();
      bool energized = true;
      for (final Map<String, Object?> step in steps) {
        final String type = step['type']! as String;
        final String address = step['address']! as String;
        if (type == 'TON') {
          activeTimers.add(address);
          seconds[address] = energized
              ? (seconds[address] ?? 0) + elapsed.inMicroseconds / 1e6
              : 0;
          done[address] = energized && seconds[address]! >= (step['presetSeconds']! as num).toDouble();
          continue;
        }
        final bool current = _read(address, inputs, q, m, done);
        switch (type) {
          case 'contact_no':
            energized = energized && current;
          case 'contact_nc':
            energized = energized && !current;
          case 'timer_done':
            energized = energized && (done[address] ?? false);
          case 'coil':
            if (address.startsWith('Q')) q[address] = energized;
            if (address.startsWith('M')) m[address] = energized;
          case 'coil_set':
            if (energized && address.startsWith('Q')) q[address] = true;
            if (energized && address.startsWith('M')) m[address] = true;
          case 'coil_reset':
            if (energized && address.startsWith('Q')) q[address] = false;
            if (energized && address.startsWith('M')) m[address] = false;
        }
      }
    }
    for (int i = 0; i < 16; i++) {
      final String timer = 'T$i';
      if (!activeTimers.contains(timer)) {
        seconds[timer] = 0;
        done[timer] = false;
      }
    }
    return LadderScanResult(
      state: LadderRuntimeState(outputs: q, memories: m, timerSeconds: seconds, timerDone: done),
      programError: false,
    );
  }

  static bool _read(String address, Map<String, bool> inputs,
      Map<String, bool> outputs, Map<String, bool> memories,
      Map<String, bool> done) {
    if (address.startsWith('I')) return inputs[address] ?? false;
    if (address.startsWith('Q')) return outputs[address] ?? false;
    if (address.startsWith('M')) return memories[address] ?? false;
    return done[address] ?? false;
  }

  static final RegExp _address = RegExp(r'^(I[0-3]|Q[0-3]|M(?:[0-9]|1[0-5])|T(?:[0-9]|1[0-5]))$');

  static bool _validProgram(List<Map<String, Object?>> program) {
    for (final Map<String, Object?> rung in program) {
      final Object? raw = rung['steps'];
      if (raw is! List<Object?> || raw.isEmpty) return false;
      final List<Map<String, Object?>> steps = <Map<String, Object?>>[];
      for (final Object? value in raw) {
        if (value is! Map<String, Object?>) return false;
        steps.add(value);
      }
      for (int i = 0; i < steps.length; i++) {
        final Map<String, Object?> step = steps[i];
        final Object? rawType = step['type'];
        final Object? rawAddress = step['address'];
        if (rawType is! String || rawAddress is! String || !_address.hasMatch(rawAddress)) return false;
        final String type = rawType;
        final String address = rawAddress;
        final bool isLast = i == steps.length - 1;
        switch (type) {
          case 'contact_no':
          case 'contact_nc':
            if (address.startsWith('T') || isLast) return false;
          case 'TON':
            final Object? preset = step['presetSeconds'];
            if (!address.startsWith('T') || preset is! num || !preset.toDouble().isFinite || preset <= 0 || preset > 3600 || !isLast) return false;
          case 'timer_done':
            if (!address.startsWith('T') || isLast) return false;
          case 'coil':
          case 'coil_set':
          case 'coil_reset':
            if (!(address.startsWith('Q') || address.startsWith('M')) || !isLast) return false;
          default:
            return false;
        }
      }
    }
    return true;
  }
}
