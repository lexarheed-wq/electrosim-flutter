import 'dart:async';

import 'package:electrosim_controls/electrosim_controls.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_protection/electrosim_protection.dart';
import 'package:flutter/foundation.dart';

import 'electrosim_runtime_engine.dart';

final class ElectroSimSimulationController extends ChangeNotifier {
  ElectroSimSimulationController({
    required CircuitState circuit,
    ElectroSimRuntimeEngine runtimeEngine = const ElectroSimRuntimeEngine(),
    this.fixedStep = const Duration(milliseconds: 100),
  }) : assert(!fixedStep.isNegative && fixedStep > Duration.zero),
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
  bool _fastForwarding = false;
  int _operationRevision = 0;

  CircuitState get circuit => _circuit;
  ElectroSimRuntimeSnapshot get snapshot => _snapshot;
  Duration get simulatedTime => _simulatedTime;
  bool get running => _running;
  bool get fastForwarding => _fastForwarding;

  void updateCircuit(CircuitState next) {
    // An editor change invalidates a long-running time integration. The
    // pending async loop must not hold the toolbar locked after cancellation.
    _operationRevision++;
    _fastForwarding = false;
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
      previousComponentHealthStates: _snapshot.componentHealthStates,
      previousPvBatterySoc: _currentPvBatterySoc(),
      previousDcBatterySocs: _snapshot.dcBatterySocs,
      previousMotorAngularSpeedsRadS: _snapshot.motorAngularSpeedsRadS,
    );
    notifyListeners();
  }

  void start() {
    if (_fastForwarding || _running) return;
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
      previousComponentHealthStates: _snapshot.componentHealthStates,
      previousPvBatterySoc: _currentPvBatterySoc(),
      previousDcBatterySocs: _snapshot.dcBatterySocs,
      previousMotorAngularSpeedsRadS: _snapshot.motorAngularSpeedsRadS,
    );
    _simulatedTime += elapsed;
    notifyListeners();
  }

  /// Integrate physical runtime states over a requested simulated duration.
  ///
  /// Long intervals are split so protections, energy and minSOC are
  /// re-evaluated during the interval rather than changing only the clock.
  /// This is a reduced-fidelity long-time stepping policy, not a transient
  /// RLC solver. Scheduling yields after every electrical solve, allowing
  /// pointer interaction and cancellation between steps.
  Future<void> advanceBy(Duration requested) async {
    if (requested <= Duration.zero) {
      throw ArgumentError.value(
        requested,
        'requested',
        'The simulation advance must be positive.',
      );
    }
    if (_fastForwarding) return;
    pause();
    final int revision = ++_operationRevision;
    _fastForwarding = true;
    notifyListeners();
    final Duration step = requested <= const Duration(minutes: 1)
        ? const Duration(seconds: 1)
        : requested <= const Duration(hours: 1)
        ? const Duration(seconds: 30)
        : const Duration(minutes: 5);
    Duration remaining = requested;
    try {
      while (remaining > Duration.zero && revision == _operationRevision) {
        final Duration elapsed = remaining < step ? remaining : step;
        advance(elapsed);
        remaining -= elapsed;
        // One electrical solve may already exceed the frame budget for
        // dense/nonlinear networks. Never add a synchronous batch on top.
        await Future<void>.delayed(Duration.zero);
      }
    } finally {
      if (revision == _operationRevision) {
        _fastForwarding = false;
        notifyListeners();
      }
    }
  }

  void cancelAdvance() {
    if (!_fastForwarding) return;
    _operationRevision++;
    _fastForwarding = false;
    notifyListeners();
  }

  void resetDynamics() {
    _operationRevision++;
    _fastForwarding = false;
    pause();
    _simulatedTime = Duration.zero;
    _snapshot = _runtimeEngine.evaluate(_circuit);
    notifyListeners();
  }

  /// Simulates the RCD internal test resistor. Unlike opening the handle, this
  /// updates the authoritative protection state and re-solves both poles.
  /// Returns false if the device is not closed or AC input is not energised.
  bool testResidualDevice(ComponentId componentId) {
    ComponentInstance? device;
    for (final ComponentInstance component in _circuit.components) {
      if (component.id == componentId) {
        device = component;
        break;
      }
    }
    if (device == null ||
        device.modelType != 'rcd_2p_ac1' ||
        device.controlState['closed'] != true ||
        _snapshot.protectionTripped(componentId)) {
      return false;
    }
    final result = _snapshot.ac1Result;
    if (result == null || !result.isSolved || device.terminals.length != 4) {
      return false;
    }
    final topology = _snapshot.topology;
    final neutralNode = topology.terminalToNode[device.terminals[0].id];
    final lineNode = topology.terminalToNode[device.terminals[1].id];
    if (neutralNode == null || lineNode == null) return false;
    final neutralV = result.nodeVoltages[neutralNode];
    final lineV = result.nodeVoltages[lineNode];
    if (neutralV == null || lineV == null ||
        !(lineV - neutralV).magnitude.isFinite ||
        (lineV - neutralV).magnitude < 1.0) {
      return false;
    }

    final previous = _snapshot.protectionState ??
        ProtectionRuntimeState.empty();
    final threshold = device.parameters[
      ComponentParameterKeys.residualTripCurrentA
    ];
    final sensitivity = threshold is num && threshold > 0
        ? threshold.toDouble()
        : 0.03;
    final tested = ProtectionRuntimeState(
      devices: <ComponentId, ProtectionDeviceState>{
        ...previous.devices,
        componentId: ProtectionDeviceState(
          componentId: componentId,
          exposure: const ProtectionExposureState.zero(),
          tripped: true,
          tripCause: ProtectionTripCause.residualCurrent,
          lastObservedCurrentA: sensitivity * 5,
        ),
      },
    );
    _operationRevision++;
    _fastForwarding = false;
    _snapshot = _runtimeEngine.advance(
      _circuit,
      elapsed: Duration.zero,
      previousProtectionState: tested,
      previousContactorStates: _currentContactorStates(),
      previousComponentHealthStates: _snapshot.componentHealthStates,
      previousPvBatterySoc: _currentPvBatterySoc(),
      previousDcBatterySocs: _snapshot.dcBatterySocs,
      previousMotorAngularSpeedsRadS: _snapshot.motorAngularSpeedsRadS,
    );
    notifyListeners();
    return _snapshot.protectionTripped(componentId);
  }

  /// Rearms one protection device without resetting unrelated dynamic state.
  /// If the electrical fault is still present, the normal protection engine
  /// can trip it again on the next simulation advance.
  void rearmProtection(ComponentId componentId) {
    final previous = _snapshot.protectionState;
    if (previous == null || !previous.isTripped(componentId)) {
      return;
    }
    _snapshot = _runtimeEngine.advance(
      _circuit,
      elapsed: Duration.zero,
      previousProtectionState: previous.reset(componentId),
      previousContactorStates: _currentContactorStates(),
      previousComponentHealthStates: _snapshot.componentHealthStates,
      previousPvBatterySoc: _currentPvBatterySoc(),
      previousDcBatterySocs: _snapshot.dcBatterySocs,
      previousMotorAngularSpeedsRadS: _snapshot.motorAngularSpeedsRadS,
    );
    notifyListeners();
  }

  double? _currentPvBatterySoc() => _snapshot.pvResult?.batteryPresent == true
      ? _snapshot.pvResult!.batterySoc
      : null;

  Map<ComponentId, bool> _currentContactorStates() => <ComponentId, bool>{
    for (final MapEntry<ComponentId, ContactorActuationState> entry
        in _snapshot.contactorStates.entries)
      entry.key: entry.value.actuated,
  };

  @override
  void dispose() {
    _operationRevision++;
    _timer?.cancel();
    _timer = null;
    _running = false;
    super.dispose();
  }
}
