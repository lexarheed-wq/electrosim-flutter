import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

abstract interface class F18ContinuityAudioBackend {
  Future<void> setActive(bool active);
  Future<void> dispose();
}

final class PlayerF18ContinuityAudioBackend
    implements F18ContinuityAudioBackend {
  // AudioPlayer initializes audioplayers' global platform scope in its
  // constructor. Keep that initialization out of workspaces which never turn
  // the continuity buzzer on (including headless/widget-test sessions).
  AudioPlayer? _player;
  bool _active = false;

  @override
  Future<void> setActive(bool active) async {
    if (_active == active) return;
    _active = active;
    if (active) {
      final AudioPlayer player = _player ??= AudioPlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(AssetSource('sounds/continuity.wav'), volume: 0.12);
    } else {
      await _player?.stop();
    }
  }

  @override
  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
    _active = false;
  }
}

/// Shares one looping continuity tone across the workspace and serializes
/// play/stop calls so a pending start cannot outlive a later stop.
final class F18ContinuityAudio {
  F18ContinuityAudio({F18ContinuityAudioBackend? backend})
    : _backend = backend ?? PlayerF18ContinuityAudioBackend();

  final F18ContinuityAudioBackend _backend;
  bool _wanted = false;
  bool _applied = false;
  bool _disposed = false;
  Future<void>? _pending;

  Future<void> setActive(bool active) {
    if (_disposed) return Future<void>.value();
    _wanted = active;
    return _pending ??= _drain().whenComplete(() => _pending = null);
  }

  Future<void> _drain() async {
    while (!_disposed && _wanted != _applied) {
      final bool next = _wanted;
      try {
        await _backend.setActive(next);
        _applied = next;
      } on Object {
        // Audio is an enhancement; measurement and display remain available.
        _applied = next;
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _wanted = false;
    if (_pending != null) await _pending;
    if (_applied) {
      try {
        await _backend.setActive(false);
      } on Object {
        // Continue disposal even when a platform audio call fails.
      }
    }
    _applied = false;
    _disposed = true;
    await _backend.dispose();
  }
}
