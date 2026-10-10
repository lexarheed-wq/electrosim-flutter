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

final class ElectroSimBrowserSessionBridge extends ChangeNotifier {
  ElectroSimBrowserSessionBridge({
    required this.controller,
    required this.sessionCode,
    required this.displayName,
    required this.endpoint,
  }) : clientId = _generateClientId();

  final ElectroSimTpSessionController controller;
  final String sessionCode;
  final String displayName;
  final Uri endpoint;
  final String clientId;

  html.WebSocket? _socket;
  StreamSubscription<html.Event>? _openSubscription;
  StreamSubscription<html.MessageEvent>? _messageSubscription;
  StreamSubscription<html.CloseEvent>? _closeSubscription;
  StreamSubscription<html.Event>? _errorSubscription;
  Completer<void>? _firstSnapshot;
  ElectroSimBrowserSessionStatus _status = ElectroSimBrowserSessionStatus.idle;
  String? _lastError;
  String _sessionName = 'Session ElectroSim';
  bool _sessionStarted = false;
  bool _simulatorEnabled = false;
  bool _applyingRemote = false;
  int _clientSequence = 0;

  ElectroSimBrowserSessionStatus get status => _status;
  String? get lastError => _lastError;
  String get sessionName => _sessionName;
  bool get sessionStarted => _sessionStarted;
  bool get simulatorEnabled => _simulatorEnabled;
  bool get sessionUsable => _status == ElectroSimBrowserSessionStatus.connected;

  Future<void> connect({Duration timeout = const Duration(seconds: 6)}) async {
    if (_status == ElectroSimBrowserSessionStatus.connected ||
        _status == ElectroSimBrowserSessionStatus.connecting) {
      return;
    }
    _setStatus(ElectroSimBrowserSessionStatus.connecting);
    final Uri target = endpoint.replace(
      queryParameters: <String, String>{
        ...endpoint.queryParameters,
        'code': sessionCode,
        'clientId': clientId,
        'displayName': displayName,
      },
    );
    final html.WebSocket socket = html.WebSocket(target.toString());
    _socket = socket;
    final Completer<void> firstSnapshot = Completer<void>();
    _firstSnapshot = firstSnapshot;

    _openSubscription = socket.onOpen.listen((html.Event _) {
      _lastError = null;
      notifyListeners();
    });
    _messageSubscription = socket.onMessage.listen((html.MessageEvent event) {
      if (event.data is String) {
        _handleMessage(event.data as String);
      }
    });
    _closeSubscription = socket.onClose.listen((html.CloseEvent _) {
      if (_status != ElectroSimBrowserSessionStatus.ended) {
        _setStatus(ElectroSimBrowserSessionStatus.ended);
      }
      final Completer<void>? first = _firstSnapshot;
      _firstSnapshot = null;
      if (first != null && !first.isCompleted) {
        first.completeError(
          StateError('La session a été fermée avant la synchronisation.'),
        );
      }
    });
    _errorSubscription = socket.onError.listen((html.Event _) {
      _lastError = 'Connexion au professeur interrompue.';
      if (_status == ElectroSimBrowserSessionStatus.connecting) {
        _setStatus(ElectroSimBrowserSessionStatus.failed);
      } else {
        notifyListeners();
      }
    });
    controller.addListener(_onLocalControllerChanged);

    try {
      await firstSnapshot.future.timeout(timeout);
    } on Object catch (error) {
      _lastError = error.toString();
      if (_status != ElectroSimBrowserSessionStatus.ended) {
        _setStatus(ElectroSimBrowserSessionStatus.failed);
      }
      rethrow;
    }
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
        final Object? sessionRaw = payloadRaw['session'];
        if (sessionRaw is Map<String, dynamic>) {
          final Object? name = sessionRaw['name'];
          final Object? started = sessionRaw['started'];
          final Object? simulator = sessionRaw['simulatorEnabled'];
          final bool closed = sessionRaw['closed'] == true;
          if (name is String && name.trim().isNotEmpty) {
            _sessionName = name.trim();
          }
          _sessionStarted = started == true;
          _simulatorEnabled = simulator == true;
          if (closed) {
            _setStatus(ElectroSimBrowserSessionStatus.ended);
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
        if (_status != ElectroSimBrowserSessionStatus.ended) {
          _setStatus(ElectroSimBrowserSessionStatus.connected);
        }
        final Completer<void>? first = _firstSnapshot;
        _firstSnapshot = null;
        if (first != null && !first.isCompleted) {
          first.complete();
        }
        notifyListeners();
        return;
      }
      if (type == 'error') {
        _lastError = payloadRaw['message']?.toString();
        notifyListeners();
      }
    } on Object catch (error) {
      _lastError = error.toString();
      notifyListeners();
    }
  }

  void _onLocalControllerChanged() {
    if (_applyingRemote ||
        _status != ElectroSimBrowserSessionStatus.connected) {
      return;
    }
    final html.WebSocket? socket = _socket;
    if (socket == null || socket.readyState != html.WebSocket.OPEN) {
      return;
    }
    socket.send(
      jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'type': 'studentState',
        'sessionCode': sessionCode,
        'senderId': clientId,
        'sequence': _clientSequence++,
        'payload': <String, Object?>{'state': controller.toStudentPersistenceJson()},
      }),
    );
  }

  void _setStatus(ElectroSimBrowserSessionStatus value) {
    if (_status == value) return;
    _status = value;
    notifyListeners();
  }

  Future<void> close() async {
    controller.removeListener(_onLocalControllerChanged);
    await _openSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _closeSubscription?.cancel();
    await _errorSubscription?.cancel();
    _openSubscription = null;
    _messageSubscription = null;
    _closeSubscription = null;
    _errorSubscription = null;
    final html.WebSocket? socket = _socket;
    _socket = null;
    socket?.close(1000, 'Client élève fermé.');
    _setStatus(ElectroSimBrowserSessionStatus.ended);
  }

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }

  static String _generateClientId() {
    final int value = Random().nextInt(0x7fffffff);
    return 'web-${value.toRadixString(16).padLeft(8, '0')}';
  }
}
