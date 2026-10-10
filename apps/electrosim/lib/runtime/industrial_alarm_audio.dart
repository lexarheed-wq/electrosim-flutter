import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:electrosim_measurements/electrosim_measurements.dart';
import 'package:flutter/foundation.dart';
import 'electrosim_runtime_engine.dart';

enum AlarmVoice { buzzer, horn }

abstract interface class AlarmAudioBackend {
  Future<void> setActive(Set<AlarmVoice> voices);
  Future<void> dispose();
}

/// Two shared looping voices, never one player per component or simulation tick.
final class PlayerAlarmAudioBackend implements AlarmAudioBackend {
  final _players = <AlarmVoice, AudioPlayer>{};
  final _active = <AlarmVoice>{};
  @override
  Future<void> setActive(Set<AlarmVoice> voices) async {
    for (final voice in AlarmVoice.values) {
      if (voices.contains(voice) && _active.contains(voice)) continue;
      if (!voices.contains(voice)) {
        await _players[voice]?.stop();
        _active.remove(voice);
      } else {
        final player = _players.putIfAbsent(voice, AudioPlayer.new);
        await player.setReleaseMode(ReleaseMode.loop);
        await player.play(AssetSource('sounds/${voice.name}.wav'), volume: .16);
        _active.add(voice);
      }
    }
  }

  @override
  Future<void> dispose() async {
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
    _active.clear();
  }
}

Set<AlarmVoice> activeAlarmVoices(
  ElectroSimRuntimeSnapshot? snapshot, {
  required bool running,
  bool enabled = true,
}) {
  if (!enabled || !running || snapshot == null || !snapshot.solved) return {};
  final voices = <AlarmVoice>{};
  for (final component in snapshot.effectiveCircuit.components) {
    final type = component.modelType.toLowerCase();
    final profile = component.parameters['soundProfile'];
    if (!{'buzzer', 'horn', 'claxon', 'alarm'}.contains(type) &&
        profile != 'buzzer' &&
        profile != 'horn') {
      continue;
    }
    final state = snapshot.componentOperatingState(component.id);
    if (state?.code != ComponentOperatingCode.energized &&
        state?.code != ComponentOperatingCode.overloaded) {
      continue;
    }
    voices.add(
      type == 'horn' || type == 'claxon' || profile == 'horn'
          ? AlarmVoice.horn
          : AlarmVoice.buzzer,
    );
  }
  return voices;
}

/// Serializes asynchronous platform calls; a pending play cannot outlive stop.
final class IndustrialAlarmAudio {
  IndustrialAlarmAudio({AlarmAudioBackend? backend})
    : _backend = backend ?? PlayerAlarmAudioBackend();
  final AlarmAudioBackend _backend;
  Set<AlarmVoice> _wanted = {}, _applied = {};
  Future<void>? _pending;
  bool _disposed = false;
  String? lastError;

  Future<void> update(Set<AlarmVoice> voices) {
    if (_disposed) return Future.value();
    _wanted = Set.of(voices);
    return _pending ??= _drain().whenComplete(() => _pending = null);
  }

  Future<void> _drain() async {
    while (!setEquals(_wanted, _applied)) {
      final target = Set<AlarmVoice>.of(_wanted);
      try {
        await _backend.setActive(target);
        lastError = null;
      } catch (error) {
        lastError = error.toString();
        debugPrint('ElectroSim audio: $error');
        // Stop partially started voices before reporting a failed transition.
        try {
          await _backend.setActive({});
        } catch (_) {}
      }
      _applied = target;
    }
  }

  Future<void> dispose() async {
    _wanted = {};
    _disposed = true;
    await (_pending ?? _drain());
    await _backend.dispose();
  }
}
