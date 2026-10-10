// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'electrosim_tp_session_controller.dart';

enum ElectroSimBrowserSessionStatus {
  idle,
  connecting,
  connected,
  ended,
  failed,
}

/// Browser-only transport: snapshots remain authoritative on the Mac host.
/// Unexpected disconnections are recoverable; teacher closure is terminal.
final class ElectroSimBrowserSessionBridge extends ChangeNotifier {
  ElectroSimBrowserSessionBridge({
    required this.controller,
    required this.sessionCode,
    required this.displayName,
    required this.endpoint,
  }) {
    _restoreIdentity();
  }

  final ElectroSimTpSessionController controller;
  final String sessionCode;
  final String displayName;
  final Uri endpoint;
  late final String clientId;

  static const int maxAutomaticReconnects = 5;
  html.WebSocket? _socket;
  StreamSubscription<html.Event>? _openSubscription;
  StreamSubscription<html.MessageEvent>? _messageSubscription;
  StreamSubscription<html.CloseEvent>? _closeSubscription;
  StreamSubscription<html.Event>? _errorSubscription;
  Timer? _reconnectTimer;
  Completer<void>? _firstSnapshot;
  ElectroSimBrowserSessionStatus _status = ElectroSimBrowserSessionStatus.idle;
  String? _lastError;
  String? _reconnectToken;
  String _sessionName = 'Session ElectroSim';
  bool _sessionStarted = false;
  bool _simulatorEnabled = false;
  bool _applyingRemote = false;
  bool _explicitlyClosed = false;
  bool _teacherEnded = false;
  bool _replaced = false;
  bool _disposed = false;
  bool _listeningToController = false;
  int _clientSequence = 0;
  int _reconnectAttempts = 0;

  ElectroSimBrowserSessionStatus get status => _status;
  String? get lastError => _lastError;
  String get sessionName => _sessionName;
  bool get sessionStarted => _sessionStarted;
  bool get replaced => _replaced;
  bool get simulatorEnabled => _simulatorEnabled;
  bool get sessionUsable => _status == ElectroSimBrowserSessionStatus.connected;

  Future<void> connect({Duration timeout = const Duration(seconds: 6)}) async {
    if (_disposed ||
        _explicitlyClosed ||
        _teacherEnded ||
        _status == ElectroSimBrowserSessionStatus.connected ||
        _status == ElectroSimBrowserSessionStatus.connecting) {
      return;
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _setStatus(ElectroSimBrowserSessionStatus.connecting);
    await _detachSocket();
    if (_disposed || _explicitlyClosed || _teacherEnded) return;

    final Uri target = endpoint.replace(
      queryParameters: <String, String>{
        ...endpoint.queryParameters,
        'code': sessionCode,
        'clientId': clientId,
        'displayName': displayName,
        if (_reconnectToken != null) 'reconnectToken': _reconnectToken!,
      },
    );
    final html.WebSocket socket = html.WebSocket(target.toString());
    _socket = socket;
    final Completer<void> first = Completer<void>();
    _firstSnapshot = first;

    _openSubscription = socket.onOpen.listen((html.Event _) {
      if (!identical(_socket, socket)) return;
      _lastError = null;
      _emit();
    });
    _messageSubscription = socket.onMessage.listen((html.MessageEvent event) {
      if (!identical(_socket, socket)) return;
      if (event.data is String) {
        _handleMessage(event.data as String);
      }
    });
    _closeSubscription = socket.onClose.listen((html.CloseEvent event) {
      if (!identical(_socket, socket) || _disposed) return;
      if (event.reason == 'Replaced by a newer connection.') {
        _replaced = true;
        _explicitlyClosed = true;
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        _setStatus(ElectroSimBrowserSessionStatus.ended);
        return;
      }
      if (!first.isCompleted) {
        first.completeError(
          StateError('Connexion interrompue avant la synchronisation.'),
        );
      }
      if (!_explicitlyClosed && !_teacherEnded) {
        _lastError = 'Connexion au professeur interrompue.';
        _setStatus(ElectroSimBrowserSessionStatus.failed);
        _scheduleReconnect();
      }
    });
    _errorSubscription = socket.onError.listen((html.Event _) {
      if (!identical(_socket, socket) ||
          _disposed ||
          _explicitlyClosed ||
          _teacherEnded) {
        return;
      }
      _lastError = 'Connexion au professeur interrompue.';
      _setStatus(ElectroSimBrowserSessionStatus.failed);
      _scheduleReconnect();
    });
    if (!_listeningToController) {
      controller.addListener(_onLocalControllerChanged);
      _listeningToController = true;
    }
    try {
      await first.future.timeout(timeout);
    } on Object catch (error) {
      if (_disposed || _explicitlyClosed || _teacherEnded) return;
      _lastError = error.toString();
      _setStatus(ElectroSimBrowserSessionStatus.failed);
      _scheduleReconnect();
      rethrow;
    }
  }

  void _scheduleReconnect() {
    if (_disposed ||
        _explicitlyClosed ||
        _teacherEnded ||
        _reconnectTimer != null) {
      return;
    }
    if (_reconnectAttempts >= maxAutomaticReconnects) return;
    final seconds = 1 << (_reconnectAttempts < 3 ? _reconnectAttempts : 3);
    _reconnectAttempts++;
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      _reconnectTimer = null;
      if (!_disposed && !_explicitlyClosed && !_teacherEnded) {
        unawaited(_attemptReconnect());
      }
    });
  }

  Future<void> _attemptReconnect() async {
    try {
      await connect();
    } on Object {
      // connect() reports the failure; the bounded retry policy schedules
      // another attempt, and the UI provides an explicit retry afterwards.
    }
  }

  /// Resets the retry budget after the user explicitly requests a new attempt.
  Future<void> retry() async {
    if (_disposed || _explicitlyClosed || _teacherEnded) return;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    if (_status == ElectroSimBrowserSessionStatus.connecting) {
      return;
    }
    await _attemptReconnect();
  }

  void _handleMessage(String source) {
    try {
      final Object? decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Message de session invalide.');
      }
      if (decoded['schemaVersion'] != 1 ||
          decoded['sessionCode'] != sessionCode) {
        throw const FormatException('Session distante incompatible.');
      }
      final Object? type = decoded['type'];
      final Object? payloadRaw = decoded['payload'];
      if (payloadRaw is! Map<String, dynamic>) {
        throw const FormatException('Payload de session invalide.');
      }
      if (type == 'snapshot') {
        final Object? stateRaw = payloadRaw['state'];
        if (stateRaw is! Map<String, dynamic>) {
          throw const FormatException('État de TP invalide.');
        }
        final Object? tokenRaw = payloadRaw['reconnectToken'];
        if (tokenRaw is String && tokenRaw.isNotEmpty) {
          _reconnectToken = tokenRaw;
          _persistIdentity();
        }
        final Object? sessionRaw = payloadRaw['session'];
        if (sessionRaw is Map<String, dynamic>) {
          final Object? name = sessionRaw['name'];
          if (name is String && name.trim().isNotEmpty) {
            _sessionName = name.trim();
          }
          _sessionStarted = sessionRaw['started'] == true;
          _simulatorEnabled = sessionRaw['simulatorEnabled'] == true;
          if (sessionRaw['closed'] == true) {
            _teacherEnded = true;
          }
        }
        _applyingRemote = true;
        try {
          controller.restoreFromPersistenceJson(
            stateRaw.map(
              (String key, dynamic value) =>
                  MapEntry<String, Object?>(key, value),
            ),
          );
        } finally {
          _applyingRemote = false;
        }
        if (_teacherEnded) {
          _reconnectTimer?.cancel();
          _setStatus(ElectroSimBrowserSessionStatus.ended);
        } else {
          _reconnectAttempts = 0;
          _lastError = null;
          _setStatus(ElectroSimBrowserSessionStatus.connected);
        }
        final Completer<void>? first = _firstSnapshot;
        _firstSnapshot = null;
        if (first != null && !first.isCompleted) first.complete();
        _emit();
        return;
      }
      if (type == 'error') {
        _lastError = payloadRaw['message']?.toString();
        _emit();
      }
    } on Object catch (error) {
      _lastError = error.toString();
      _emit();
    }
  }

  void _onLocalControllerChanged() {
    if (_disposed ||
        _applyingRemote ||
        _status != ElectroSimBrowserSessionStatus.connected) {
      return;
    }
    final html.WebSocket? socket = _socket;
    if (socket == null || socket.readyState != html.WebSocket.OPEN) return;
    final sequence = _clientSequence++;
    _persistIdentity();
    socket.send(
      jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'type': 'studentState',
        'sessionCode': sessionCode,
        'senderId': clientId,
        'sequence': sequence,
        'payload': <String, Object?>{
          'state': controller.toStudentPersistenceJson(),
        },
      }),
    );
  }

  void _setStatus(ElectroSimBrowserSessionStatus status) {
    if (_status == status) return;
    _status = status;
    _emit();
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _detachSocket() async {
    await _openSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _closeSubscription?.cancel();
    await _errorSubscription?.cancel();
    _openSubscription = null;
    _messageSubscription = null;
    _closeSubscription = null;
    _errorSubscription = null;
    final socket = _socket;
    _socket = null;
    socket?.close(1000, 'Transport Web renouvelé.');
  }

  Future<void> close() async {
    if (_explicitlyClosed) return;
    _explicitlyClosed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    if (_listeningToController) {
      controller.removeListener(_onLocalControllerChanged);
      _listeningToController = false;
    }
    await _detachSocket();
    _setStatus(ElectroSimBrowserSessionStatus.ended);
  }

  @override
  void dispose() {
    _disposed = true;
    _explicitlyClosed = true;
    _reconnectTimer?.cancel();
    if (_listeningToController) {
      controller.removeListener(_onLocalControllerChanged);
      _listeningToController = false;
    }
    unawaited(_detachSocket());
    super.dispose();
  }

  String get _identityKey =>
      'electrosim.student.v1.${endpoint.host}:${endpoint.port}.$sessionCode.${base64Url.encode(utf8.encode(displayName.trim().toLowerCase()))}';

  void _restoreIdentity() {
    String? restoredId;
    try {
      final source = html.window.localStorage[_identityKey];
      if (source != null) {
        final saved = jsonDecode(source);
        if (saved is Map<String, dynamic> &&
            saved['clientId'] is String &&
            saved['reconnectToken'] is String &&
            (saved['reconnectToken'] as String).isNotEmpty &&
            saved['nextSequence'] is int &&
            (saved['nextSequence'] as int) >= 0) {
          restoredId = saved['clientId'] as String;
          _reconnectToken = saved['reconnectToken'] as String;
          _clientSequence = saved['nextSequence'] as int;
        }
      }
    } on Object {
      // Browsers that prohibit storage still support in-page reconnects.
    }
    clientId = restoredId ?? _generateClientId();
  }

  void _persistIdentity() {
    try {
      html.window.localStorage[_identityKey] = jsonEncode(<String, Object?>{
        'clientId': clientId,
        'reconnectToken': _reconnectToken,
        'nextSequence': _clientSequence,
      });
    } on Object {
      // The authoritative TP stays on the teacher host, never in this record.
    }
  }

  static String _generateClientId() {
    final int value = Random().nextInt(0x7fffffff);
    return 'web-${value.toRadixString(16).padLeft(8, '0')}';
  }
}
