import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_tp/electrosim_tp.dart';
import 'package:flutter/foundation.dart';

import 'electrosim_tp_session_controller.dart';

enum ElectroSimSyncMessageType { studentState, snapshot, ack, error }

enum ElectroSimLanSyncStatus {
  disconnected,
  connecting,
  synchronized,
  reconnecting,
  closed,
}

final class ElectroSimSyncEnvelope {
  const ElectroSimSyncEnvelope({
    required this.type,
    required this.sessionCode,
    required this.senderId,
    required this.sequence,
    required this.payload,
  });

  static const int schemaVersion = 1;

  final ElectroSimSyncMessageType type;
  final String sessionCode;
  final String senderId;
  final int sequence;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': schemaVersion,
        'type': type.name,
        'sessionCode': sessionCode,
        'senderId': senderId,
        'sequence': sequence,
        'payload': payload,
      };

  String toJsonString() => jsonEncode(toJson());

  factory ElectroSimSyncEnvelope.fromJsonString(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Sync envelope root must be an object.');
    }
    return ElectroSimSyncEnvelope.fromJson(decoded);
  }

  factory ElectroSimSyncEnvelope.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != schemaVersion) {
      throw FormatException(
        'Unsupported sync schemaVersion: ' +
            json['schemaVersion'].toString() +
            '.',
      );
    }
    final Object? typeRaw = json['type'];
    final Object? code = json['sessionCode'];
    final Object? sender = json['senderId'];
    final Object? sequence = json['sequence'];
    final Object? payload = json['payload'];
    if (typeRaw is! String ||
        code is! String ||
        code.isEmpty ||
        sender is! String ||
        sender.isEmpty ||
        sequence is! int ||
        sequence < 0 ||
        payload is! Map<String, dynamic>) {
      throw const FormatException('Invalid sync envelope.');
    }
    final ElectroSimSyncMessageType type =
        ElectroSimSyncMessageType.values.firstWhere(
      (ElectroSimSyncMessageType value) => value.name == typeRaw,
      orElse: () => throw FormatException('Unknown sync message type: $typeRaw'),
    );
    return ElectroSimSyncEnvelope(
      type: type,
      sessionCode: code,
      senderId: sender,
      sequence: sequence,
      payload: payload.map(
        (String key, dynamic value) => MapEntry<String, Object?>(key, value),
      ),
    );
  }
}

final class ElectroSimLanHostInfo {
  const ElectroSimLanHostInfo({
    required this.sessionCode,
    required this.port,
    required this.endpoints,
  });

  final String sessionCode;
  final int port;
  final List<Uri> endpoints;

  Uri get preferredEndpoint => endpoints.first;
}

final class ElectroSimLanSyncHost {
  ElectroSimLanSyncHost({
    required this.controller,
    required String sessionCode,
    this.hostId = 'teacher',
  }) : sessionCode = sessionCode.trim().toUpperCase();

  final ElectroSimTpSessionController controller;
  final String sessionCode;
  final String hostId;

  HttpServer? _server;
  final Map<String, WebSocket> _clients = <String, WebSocket>{};
  final Map<String, int> _lastClientSequence = <String, int>{};
  int _serverSequence = 0;
  bool _reconciling = false;
  bool _closed = false;

  bool get isRunning => _server != null && !_closed;

  static String generateSessionCode({Random? random}) {
    final Random source = random ?? Random.secure();
    const String alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List<String>.generate(
      6,
      (_) => alphabet[source.nextInt(alphabet.length)],
      growable: false,
    ).join();
  }

  Future<ElectroSimLanHostInfo> start({
    InternetAddress? address,
    int port = 0,
  }) async {
    if (_server != null) return _hostInfo(_server!);
    if (_closed) {
      throw StateError('A closed LAN sync host cannot be restarted.');
    }
    final HttpServer server = await HttpServer.bind(
      address ?? InternetAddress.anyIPv4,
      port,
      shared: false,
    );
    _server = server;
    controller.addListener(_onControllerChanged);
    unawaited(_serve(server));
    return _hostInfo(server);
  }

  Future<ElectroSimLanHostInfo> _hostInfo(HttpServer server) async {
    final List<Uri> endpoints = <Uri>[];
    if (server.address.isLoopback) {
      endpoints.add(
        Uri(
          scheme: 'ws',
          host: server.address.address,
          port: server.port,
          path: '/electrosim-sync',
        ),
      );
    } else {
      final List<NetworkInterface> interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      for (final NetworkInterface interface in interfaces) {
        for (final InternetAddress candidate in interface.addresses) {
          endpoints.add(
            Uri(
              scheme: 'ws',
              host: candidate.address,
              port: server.port,
              path: '/electrosim-sync',
            ),
          );
        }
      }
      if (endpoints.isEmpty) {
        endpoints.add(
          Uri(
            scheme: 'ws',
            host: InternetAddress.loopbackIPv4.address,
            port: server.port,
            path: '/electrosim-sync',
          ),
        );
      }
    }
    endpoints.sort((Uri a, Uri b) => a.toString().compareTo(b.toString()));
    return ElectroSimLanHostInfo(
      sessionCode: sessionCode,
      port: server.port,
      endpoints: List<Uri>.unmodifiable(endpoints),
    );
  }

  Future<void> _serve(HttpServer server) async {
    try {
      await for (final HttpRequest request in server) {
        unawaited(_handleRequest(request));
      }
    } on Object {
      if (!_closed) rethrow;
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (request.uri.path != '/electrosim-sync') {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.upgradeRequired;
      await request.response.close();
      return;
    }
    final String? code = request.uri.queryParameters['code'];
    final String? clientId = request.uri.queryParameters['clientId'];
    if (code == null ||
        code.trim().toUpperCase() != sessionCode ||
        !_safeClientId(clientId)) {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }

    final WebSocket socket = await WebSocketTransformer.upgrade(request);
    final String id = clientId!;
    final WebSocket? previous = _clients[id];
    _clients[id] = socket;
    if (previous != null) {
      await previous.close(
        WebSocketStatus.goingAway,
        'Replaced by a newer connection.',
      );
    }
    socket.listen(
      (dynamic data) {
        if (data is String) {
          unawaited(_handleClientMessage(id, socket, data));
        } else {
          _sendError(socket, 'Only UTF-8 JSON text messages are accepted.');
        }
      },
      onError: (_) {
        if (identical(_clients[id], socket)) _clients.remove(id);
      },
      onDone: () {
        if (identical(_clients[id], socket)) _clients.remove(id);
      },
      cancelOnError: false,
    );
    _sendSnapshot(socket);
  }

  Future<void> _handleClientMessage(
    String clientId,
    WebSocket socket,
    String source,
  ) async {
    try {
      final ElectroSimSyncEnvelope envelope =
          ElectroSimSyncEnvelope.fromJsonString(source);
      if (envelope.type != ElectroSimSyncMessageType.studentState) {
        throw const FormatException(
          'Students may send studentState messages only.',
        );
      }
      if (envelope.sessionCode != sessionCode ||
          envelope.senderId != clientId) {
        throw const FormatException('Sync identity mismatch.');
      }
      final int last = _lastClientSequence[clientId] ?? -1;
      if (envelope.sequence <= last) {
        throw StateError('Stale or replayed student sync message.');
      }
      _lastClientSequence[clientId] = envelope.sequence;
      final Object? raw = envelope.payload['state'];
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('studentState payload is missing state.');
      }

      _reconciling = true;
      try {
        _reconcileStudentState(
          raw.map(
            (String key, dynamic value) =>
                MapEntry<String, Object?>(key, value),
          ),
        );
      } finally {
        _reconciling = false;
      }

      _send(
        socket,
        ElectroSimSyncEnvelope(
          type: ElectroSimSyncMessageType.ack,
          sessionCode: sessionCode,
          senderId: hostId,
          sequence: _serverSequence++,
          payload: <String, Object?>{'acceptedSequence': envelope.sequence},
        ),
      );
      _broadcastSnapshot();
    } on Object catch (error) {
      _sendError(socket, error.toString());
      _sendSnapshot(socket);
    }
  }

  void _reconcileStudentState(Map<String, Object?> state) {
    if (state['hasSession'] != true) {
      throw const FormatException('Student state has no TP session.');
    }
    if (state['tpId'] != controller.tpIdValue ||
        state['title'] != controller.title) {
      throw const FormatException('Student TP identity mismatch.');
    }
    final TpSession? initial = controller.session;
    if (initial == null) {
      throw StateError('Teacher has no TP to synchronize.');
    }
    final Object? lifecycleRaw = state['lifecycle'];
    if (lifecycleRaw is! String) {
      throw const FormatException('Student lifecycle is missing.');
    }
    final TpLifecycle desired = TpLifecycle.values.firstWhere(
      (TpLifecycle value) => value.name == lifecycleRaw,
      orElse: () =>
          throw FormatException('Unknown student lifecycle: $lifecycleRaw'),
    );

    TpSession current = initial;
    if (current.lifecycle == TpLifecycle.draft) {
      throw StateError('Teacher TP is not published yet.');
    }
    if (current.lifecycle == TpLifecycle.published) {
      if (desired == TpLifecycle.published) return;
      if (desired != TpLifecycle.started &&
          desired != TpLifecycle.submitted) {
        throw StateError(
          'Student cannot transition published TP to ' + desired.name + '.',
        );
      }
      current = controller.startStudent();
    }

    if (current.lifecycle == TpLifecycle.started) {
      if (desired != TpLifecycle.started &&
          desired != TpLifecycle.submitted) {
        throw StateError(
          'Student cannot transition active TP to ' + desired.name + '.',
        );
      }
      final Object? circuitRaw = state['studentCircuit'];
      if (circuitRaw is! Map<String, dynamic>) {
        throw const FormatException('Student circuit is missing.');
      }
      final CircuitState candidate = CircuitState.fromJson(circuitRaw);
      if (candidate.circuitId != current.studentCircuit.circuitId) {
        throw StateError('Student circuit identity mismatch.');
      }
      if (candidate.revision < current.studentCircuit.revision) {
        throw StateError('Student circuit revision cannot go backwards.');
      }
      if (candidate.revision > current.studentCircuit.revision) {
        current = controller.updateStudentCircuit(candidate);
      }

      final Object? entriesRaw = state['diagnosticEntries'];
      if (entriesRaw is! List) {
        throw const FormatException('Student diagnostic entries are invalid.');
      }
      final List<DiagnosticEntry> candidates = <DiagnosticEntry>[];
      for (final Object? raw in entriesRaw) {
        if (raw is! Map<String, dynamic>) {
          throw const FormatException('Invalid student diagnostic entry.');
        }
        final Object? promptId = raw['promptId'];
        final Object? answer = raw['answer'];
        if (promptId is! String || answer is! String) {
          throw const FormatException(
            'Invalid student diagnostic entry fields.',
          );
        }
        candidates.add(DiagnosticEntry(promptId: promptId, answer: answer));
      }

      final List<DiagnosticEntry> authoritative =
          current.diagnosticSheet.entries;
      if (candidates.length < authoritative.length) {
        throw StateError('Student diagnostic history cannot be truncated.');
      }
      for (var index = 0; index < authoritative.length; index++) {
        final DiagnosticEntry expected = authoritative[index];
        final DiagnosticEntry candidate = candidates[index];
        if (candidate.promptId != expected.promptId ||
            candidate.answer != expected.answer) {
          throw StateError('Student diagnostic history is append-only.');
        }
      }
      for (var index = authoritative.length;
          index < candidates.length;
          index++) {
        final DiagnosticEntry entry = candidates[index];
        current = controller.addDiagnosticEntry(
          promptId: entry.promptId,
          answer: entry.answer,
        );
      }
      if (desired == TpLifecycle.submitted) {
        controller.submitStudent();
      }
      return;
    }

    if (desired != current.lifecycle) {
      throw StateError(
        'Teacher TP is ' +
            current.lifecycle.name +
            '; student mutation is read-only.',
      );
    }
  }

  void _onControllerChanged() {
    if (!_reconciling) _broadcastSnapshot();
  }

  void _broadcastSnapshot() {
    for (final WebSocket socket in _clients.values.toList(growable: false)) {
      _sendSnapshot(socket);
    }
  }

  void _sendSnapshot(WebSocket socket) {
    _send(
      socket,
      ElectroSimSyncEnvelope(
        type: ElectroSimSyncMessageType.snapshot,
        sessionCode: sessionCode,
        senderId: hostId,
        sequence: _serverSequence++,
        payload: <String, Object?>{
          'state': controller.toPersistenceJson(),
        },
      ),
    );
  }

  void _sendError(WebSocket socket, String message) {
    _send(
      socket,
      ElectroSimSyncEnvelope(
        type: ElectroSimSyncMessageType.error,
        sessionCode: sessionCode,
        senderId: hostId,
        sequence: _serverSequence++,
        payload: <String, Object?>{'message': message},
      ),
    );
  }

  void _send(WebSocket socket, ElectroSimSyncEnvelope envelope) {
    try {
      socket.add(envelope.toJsonString());
    } on Object {
      // Socket lifecycle callbacks own connection cleanup.
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    controller.removeListener(_onControllerChanged);
    final List<WebSocket> sockets =
        _clients.values.toList(growable: false);
    _clients.clear();
    for (final WebSocket socket in sockets) {
      await socket.close(
        WebSocketStatus.normalClosure,
        'Teacher session closed.',
      );
    }
    final HttpServer? server = _server;
    _server = null;
    await server?.close(force: true);
  }

  static bool _safeClientId(String? value) =>
      value != null &&
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{2,79}$').hasMatch(value);
}

final class ElectroSimLanSyncClient extends ChangeNotifier {
  ElectroSimLanSyncClient({
    required this.controller,
    required String sessionCode,
    required this.clientId,
    this.autoReconnect = true,
  }) : sessionCode = sessionCode.trim().toUpperCase() {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{2,79}$')
        .hasMatch(clientId)) {
      throw ArgumentError.value(clientId, 'clientId', 'Invalid client ID.');
    }
    controller.addListener(_onLocalControllerChanged);
  }

  final ElectroSimTpSessionController controller;
  final String sessionCode;
  final String clientId;
  final bool autoReconnect;

  WebSocket? _socket;
  Uri? _endpoint;
  Timer? _reconnectTimer;
  Completer<void>? _firstSnapshot;
  int _clientSequence = 0;
  int _lastServerSequence = -1;
  bool _applyingRemote = false;
  bool _closed = false;
  bool _manualDisconnect = false;
  ElectroSimLanSyncStatus _status = ElectroSimLanSyncStatus.disconnected;
  String? _lastError;

  ElectroSimLanSyncStatus get status => _status;
  String? get lastError => _lastError;
  bool get synchronized => _status == ElectroSimLanSyncStatus.synchronized;
  Uri? get endpoint => _endpoint;

  static String generateClientId({Random? random}) {
    final Random source = random ?? Random.secure();
    final int value = source.nextInt(0x7fffffff);
    return 'student-' + value.toRadixString(16).padLeft(8, '0');
  }

  Future<void> connect(
    Uri endpoint, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_closed) {
      throw StateError('A closed LAN sync client cannot reconnect.');
    }
    _endpoint = _normalizeEndpoint(endpoint);
    _manualDisconnect = false;
    _reconnectTimer?.cancel();
    _lastServerSequence = -1;
    _setStatus(ElectroSimLanSyncStatus.connecting);
    final Completer<void> first = Completer<void>();
    _firstSnapshot = first;
    await _openSocket();
    await first.future.timeout(timeout);
  }

  Future<void> disconnect() async {
    if (_closed) return;
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    final WebSocket? socket = _socket;
    _socket = null;
    await socket?.close(
      WebSocketStatus.goingAway,
      'Student disconnected.',
    );
    _setStatus(ElectroSimLanSyncStatus.disconnected);
  }

  Future<void> reconnect({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_closed) {
      throw StateError('A closed LAN sync client cannot reconnect.');
    }
    if (_endpoint == null) {
      throw StateError('No previous LAN endpoint is available.');
    }
    _manualDisconnect = false;
    _reconnectTimer?.cancel();
    await _socket?.close(
      WebSocketStatus.goingAway,
      'Manual reconnect.',
    );
    _socket = null;
    _lastServerSequence = -1;
    _setStatus(ElectroSimLanSyncStatus.reconnecting);
    final Completer<void> first = Completer<void>();
    _firstSnapshot = first;
    await _openSocket();
    await first.future.timeout(timeout);
  }

  Future<void> _openSocket() async {
    final Uri target =
        _endpoint ?? (throw StateError('No LAN endpoint configured.'));
    final Uri uri = target.replace(
      queryParameters: <String, String>{
        ...target.queryParameters,
        'code': sessionCode,
        'clientId': clientId,
      },
    );
    try {
      final WebSocket socket = await WebSocket.connect(uri.toString());
      if (_closed) {
        await socket.close();
        return;
      }
      _socket = socket;
      socket.listen(
        (dynamic data) {
          if (data is String) _handleServerMessage(data);
        },
        onError: (Object error) {
          _lastError = error.toString();
          _handleDisconnected();
        },
        onDone: _handleDisconnected,
        cancelOnError: false,
      );
    } on Object catch (error) {
      _lastError = error.toString();
      final Completer<void>? first = _firstSnapshot;
      _firstSnapshot = null;
      if (first != null && !first.isCompleted) first.completeError(error);
      _handleDisconnected();
      rethrow;
    }
  }

  void _handleServerMessage(String source) {
    try {
      final ElectroSimSyncEnvelope envelope =
          ElectroSimSyncEnvelope.fromJsonString(source);
      if (envelope.sessionCode != sessionCode) {
        throw const FormatException('Server session code mismatch.');
      }
      if (envelope.sequence <= _lastServerSequence) return;
      _lastServerSequence = envelope.sequence;

      switch (envelope.type) {
        case ElectroSimSyncMessageType.snapshot:
          final Object? raw = envelope.payload['state'];
          if (raw is! Map<String, dynamic>) {
            throw const FormatException('Server snapshot is missing state.');
          }
          _applyingRemote = true;
          try {
            controller.restoreFromPersistenceJson(
              raw.map(
                (String key, dynamic value) =>
                    MapEntry<String, Object?>(key, value),
              ),
            );
          } finally {
            _applyingRemote = false;
          }
          _lastError = null;
          _setStatus(ElectroSimLanSyncStatus.synchronized);
          final Completer<void>? first = _firstSnapshot;
          _firstSnapshot = null;
          if (first != null && !first.isCompleted) first.complete();
          notifyListeners();
          break;
        case ElectroSimSyncMessageType.ack:
          break;
        case ElectroSimSyncMessageType.error:
          _lastError = envelope.payload['message']?.toString();
          notifyListeners();
          break;
        case ElectroSimSyncMessageType.studentState:
          throw const FormatException(
            'Server cannot send studentState messages.',
          );
      }
    } on Object catch (error) {
      _lastError = error.toString();
      notifyListeners();
    }
  }

  void _onLocalControllerChanged() {
    if (_applyingRemote || _closed) return;
    final WebSocket? socket = _socket;
    if (socket == null) return;
    final ElectroSimSyncEnvelope envelope = ElectroSimSyncEnvelope(
      type: ElectroSimSyncMessageType.studentState,
      sessionCode: sessionCode,
      senderId: clientId,
      sequence: _clientSequence++,
      payload: <String, Object?>{
        'state': controller.toPersistenceJson(),
      },
    );
    try {
      socket.add(envelope.toJsonString());
    } on Object catch (error) {
      _lastError = error.toString();
      notifyListeners();
    }
  }

  void _handleDisconnected() {
    _socket = null;
    if (_closed) {
      _setStatus(ElectroSimLanSyncStatus.closed);
      return;
    }
    _setStatus(ElectroSimLanSyncStatus.disconnected);
    if (!_manualDisconnect && autoReconnect && _endpoint != null) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_closed ||
        _manualDisconnect ||
        _reconnectTimer?.isActive == true) {
      return;
    }
    _reconnectTimer = Timer(const Duration(seconds: 1), () async {
      if (_closed || _manualDisconnect) return;
      _lastServerSequence = -1;
      _setStatus(ElectroSimLanSyncStatus.reconnecting);
      try {
        await _openSocket();
      } on Object {
        if (!_closed && !_manualDisconnect) _scheduleReconnect();
      }
    });
  }

  void _setStatus(ElectroSimLanSyncStatus value) {
    if (_status == value) return;
    _status = value;
    notifyListeners();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    controller.removeListener(_onLocalControllerChanged);
    final WebSocket? socket = _socket;
    _socket = null;
    await socket?.close(
      WebSocketStatus.normalClosure,
      'Student client closed.',
    );
    _setStatus(ElectroSimLanSyncStatus.closed);
  }

  static Uri _normalizeEndpoint(Uri endpoint) {
    if (endpoint.scheme != 'ws' && endpoint.scheme != 'wss') {
      throw ArgumentError.value(
        endpoint,
        'endpoint',
        'LAN endpoint must use ws:// or wss://.',
      );
    }
    if (endpoint.host.isEmpty) {
      throw ArgumentError.value(
        endpoint,
        'endpoint',
        'LAN endpoint must include a host.',
      );
    }
    return endpoint.replace(
      path: endpoint.path.isEmpty || endpoint.path == '/'
          ? '/electrosim-sync'
          : endpoint.path,
    );
  }
}
