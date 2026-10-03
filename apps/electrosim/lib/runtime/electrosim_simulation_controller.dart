
import 'dart:async';

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/foundation.dart';

import 'electrosim_runtime_engine.dart';

final class ElectroSimSimulationController extends ChangeNotifier {
  ElectroSimSimulationController({
    required CircuitState circuit,
    ElectroSimRuntimeEngine runtimeEngine = const ElectroSimRuntimeEngine(),
    this.fixedStep = const Duration(milliseconds: 100),
  })  : assert(!fixedStep.isNegative && fixedStep > Duration.zero),
        _runtimeEngine = runtimeEngine,
        _circuit = circuit,
        _snapshot = runtimeEngine.evaluate(circuit);

  final ElectroSimRuntimeEngine _runtimeEngine;
  final Duration fixedStep;

  CircuitState _circuit;
  ElectroSimRuntimeSnapshot _snapshot;
  Duration _simulatedTime = Duration.zero;
  Timer? _timer;
  bool _running = false;

  CircuitState get circuit => _circuit;
  ElectroSimRuntimeSnapshot get snapshot => _snapshot;
  Duration get simulatedTime => _simulatedTime;
  bool get running => _running;

  void updateCircuit(CircuitState next) {
    final bool sameCircuit = next.circuitId == _circuit.circuitId;
    _circuit = next;

    if (!sameCircuit) {
      _simulatedTime = Duration.zero;
      _snapshot = _runtimeEngine.evaluate(next);
      notifyListeners();
      return;
    }

    _snapshot = _runtimeEngine.advance(
      next,
      elapsed: Duration.zero,
      previousProtectionState: _snapshot.protectionState,
      previousContactorStates: _currentContactorStates(),
    );
    notifyListeners();
  }

  void start() {
    if (_running) return;
    _running = true;
    _timer = Timer.periodic(fixedStep, (_) {
      if (_running) {
        advance(fixedStep);
      }
    });
    notifyListeners();
  }

  void pause() {
    if (!_running) return;
    _running = false;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  void toggle() {
    if (_running) {
      pause();
    } else {
      start();
    }
  }

  void advance(Duration elapsed) {
    if (elapsed.isNegative) {
      throw ArgumentError.value(
        elapsed,
        'elapsed',
        'Simulation elapsed time cannot be negative.',
      );
    }
    _snapshot = _runtimeEngine.advance(
      _circuit,
      elapsed: elapsed,
      previousProtectionState: _snapshot.protectionState,
      previousContactorStates: _currentContactorStates(),
    );
    _simulatedTime += elapsed;
    notifyListeners();
  }

  void resetDynamics() {
    pause();
    _simulatedTime = Duration.zero;
    _snapshot = _runtimeEngine.evaluate(_circuit);
    notifyListeners();
  }

  Map<ComponentId, bool> _currentContactorStates() =>
      <ComponentId, bool>{
        for (final MapEntry<ComponentId, ContactorActuationState> entry
            in _snapshot.contactorStates.entries)
          entry.key: entry.value.actuated,
      };

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    super.dispose();
  }
}
