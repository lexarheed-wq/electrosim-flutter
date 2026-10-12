import 'authored_network_self_hold_cycle.dart';

/// One accepted snapshot is authoritative; failed solves never advance time
/// or leak half-updated gas/electric state to the presentation layer.
final class AuthoredCycleSession {
  AuthoredCycleSession(this.cycle) : _accepted = cycle.initial();

  final AuthoredNetworkSelfHoldValve52Cycle cycle;
  AuthoredNetworkSelfHoldSnapshot _accepted;
  bool _paused = false;
  bool _powerEnabled = true;
  bool _airSupplyEnabled = true;
  Object? _lastFailure;

  AuthoredNetworkSelfHoldSnapshot get snapshot => _accepted;
  bool get paused => _paused;
  bool get powerEnabled => _powerEnabled;
  bool get airSupplyEnabled => _airSupplyEnabled;
  Object? get lastFailure => _lastFailure;
  void pause() => _paused = true;
  void resume() => _paused = false;
  void setPowerEnabled(bool enabled) => _powerEnabled = enabled;
  void setAirSupplyEnabled(bool enabled) => _airSupplyEnabled = enabled;

  AuthoredNetworkSelfHoldSnapshot advance({
    required double durationS,
    required bool startPressed,
  }) {
    if (_paused) return _accepted;
    try {
      if (!durationS.isFinite || durationS < 0) {
        throw ArgumentError.value(durationS, 'durationS');
      }
      final AuthoredNetworkSelfHoldSnapshot candidate = cycle.advance(
        _accepted,
        durationS: durationS,
        startPressed: startPressed && _powerEnabled,
        powerEnabled: _powerEnabled,
        airSupplyEnabled: _airSupplyEnabled,
      );
      final double residual = cycle.massBalanceResidualKg(candidate).abs();
      if (!candidate.timeS.isFinite ||
          candidate.timeS < _accepted.timeS ||
          (durationS > 0 && candidate.timeS <= _accepted.timeS) ||
          !candidate.air.positionM.isFinite ||
          !candidate.air.velocityMPerS.isFinite ||
          !residual.isFinite ||
          residual > 1e-8) {
        throw StateError('R6/M physical snapshot rejected: clock or mass');
      }
      _accepted = candidate;
      _lastFailure = null;
      return _accepted;
    } catch (error) {
      _lastFailure = error;
      rethrow;
    }
  }

  void reset() {
    _accepted = cycle.initial();
    _paused = true;
    _powerEnabled = true;
    _airSupplyEnabled = true;
    _lastFailure = null;
  }
}
