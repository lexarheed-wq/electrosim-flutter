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
        'Unsupported sync schemaVersion: ${json['schemaVersion']}.',
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
    final ElectroSimSyncMessageType type = ElectroSimSyncMessageType.values
        .firstWhere(
          (ElectroSimSyncMessageType value) => value.name == typeRaw,
          orElse: () =>
              throw FormatException('Unknown sync message type: $typeRaw'),
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
    required this.joinUrls,
  });

  final String sessionCode;
  final int port;
  final List<Uri> endpoints;
  final List<Uri> joinUrls;

  Uri get preferredEndpoint => endpoints.first;
  Uri get preferredJoinUrl => joinUrls.first;
}

final class ElectroSimConnectedStudent {
  const ElectroSimConnectedStudent({
    required this.clientId,
    required this.displayName,
  });

  final String clientId;
  final String displayName;
}

final class ElectroSimStudentSupervisionState {
  const ElectroSimStudentSupervisionState({
    required this.clientId,
    required this.displayName,
    required this.connected,
    required this.session,
    this.lastActivityAtUtc,
  });

  final String clientId;
  final String displayName;
  final bool connected;
  final TpSession? session;
  final DateTime? lastActivityAtUtc;
}

final class ElectroSimLanSyncHost extends ChangeNotifier {
  ElectroSimLanSyncHost({
    required this.controller,
    required String sessionCode,
    this.sessionName = 'Session ElectroSim',
    this.hostId = 'teacher',
    this.studentWebRoot,
  }) : sessionCode = sessionCode.trim().toUpperCase();

  final ElectroSimTpSessionController controller;
  final String sessionCode;
  final String sessionName;
  final String hostId;
  final Directory? studentWebRoot;

  HttpServer? _server;
  final Map<String, WebSocket> _clients = <String, WebSocket>{};
  // Individual random capability: a collective session code is not an identity.
  final Map<String, String> _clientReconnectTokens = <String, String>{};
  final Random _secureRandom = Random.secure();
  final Map<String, String> _clientDisplayNames = <String, String>{};
  final Map<String, DateTime> _studentLastActivityAtUtc = <String, DateTime>{};
  final Map<String, ElectroSimTpSessionController> _studentControllers =
      <String, ElectroSimTpSessionController>{};
  final Map<String, int> _lastClientSequence = <String, int>{};
  int _serverSequence = 0;
  bool _reconciling = false;
  bool _closed = false;
  bool _sessionStarted = false;
  bool _classroomClosed = false;

  bool get isRunning => _server != null && !_closed;
  bool get sessionStarted => _sessionStarted;

  List<String> get connectedClientIds =>
      List<String>.unmodifiable(_clients.keys.toList()..sort());

  List<ElectroSimConnectedStudent> get connectedStudents {
    final List<ElectroSimConnectedStudent> students =
        _clients.keys
            .map(
              (String id) => ElectroSimConnectedStudent(
                clientId: id,
                displayName: _clientDisplayNames[id] ?? id,
              ),
            )
            .toList(growable: false)
          ..sort(
            (ElectroSimConnectedStudent a, ElectroSimConnectedStudent b) => a
                .displayName
                .toLowerCase()
                .compareTo(b.displayName.toLowerCase()),
          );
    return List<ElectroSimConnectedStudent>.unmodifiable(students);
  }

  List<ElectroSimStudentSupervisionState> get studentSupervisionStates {
    final Set<String> ids = <String>{
      ..._studentControllers.keys,
      ..._clients.keys,
    };
    final List<ElectroSimStudentSupervisionState> states =
        ids
            .map(
              (String id) => ElectroSimStudentSupervisionState(
                clientId: id,
                displayName: _clientDisplayNames[id] ?? id,
                connected: _clients.containsKey(id),
                session: _studentControllers[id]?.session,
                lastActivityAtUtc: _studentLastActivityAtUtc[id],
              ),
            )
            .toList(growable: false)
          ..sort(
            (
              ElectroSimStudentSupervisionState a,
              ElectroSimStudentSupervisionState b,
            ) => a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            ),
          );
    return List<ElectroSimStudentSupervisionState>.unmodifiable(states);
  }

  void setSessionStarted(bool value) {
    if (_classroomClosed) return;
    if (_sessionStarted == value) return;
    _sessionStarted = value;
    _broadcastSnapshot();
    notifyListeners();
  }

  Map<String, TpSession?> get studentSessions =>
      Map<String, TpSession?>.unmodifiable(<String, TpSession?>{
        for (final MapEntry<String, ElectroSimTpSessionController> entry
            in _studentControllers.entries)
          entry.key: entry.value.session,
      });

  ElectroSimTpSessionController _studentController(String clientId) =>
      _studentControllers.putIfAbsent(
        clientId,
        controller.createStudentReplica,
      );

  TpSession evaluateStudent(String clientId, {int? score}) {
    final ElectroSimTpSessionController? student =
        _studentControllers[clientId];
    if (student == null) {
      throw StateError('Unknown student: $clientId');
    }
    final TpSession evaluated = student.evaluateTeacher(score: score);
    final WebSocket? socket = _clients[clientId];
    if (socket != null) _sendSnapshot(socket, clientId);
    notifyListeners();
    return evaluated;
  }

  TpSession closeStudent(String clientId) {
    final ElectroSimTpSessionController? student =
        _studentControllers[clientId];
    if (student == null) {
      throw StateError('Unknown student: $clientId');
    }
    final TpSession closed = student.closeTeacher();
    final WebSocket? socket = _clients[clientId];
    if (socket != null) _sendSnapshot(socket, clientId);
    notifyListeners();
    return closed;
  }

  void resetClassroomActivity() {
    _reconciling = true;
    try {
      for (final ElectroSimTpSessionController student
          in _studentControllers.values) {
        student.dispose();
      }
      _studentControllers.clear();
      _lastClientSequence.clear();
    } finally {
      _reconciling = false;
    }
    _broadcastSnapshot();
    notifyListeners();
  }

  void closeClassroomSession() {
    _reconciling = true;
    try {
      for (final ElectroSimTpSessionController student
          in _studentControllers.values) {
        final TpSession? session = student.session;
        if (session == null || session.lifecycle == TpLifecycle.closed) {
          continue;
        }
        switch (session.lifecycle) {
          case TpLifecycle.draft:
          case TpLifecycle.published:
          case TpLifecycle.started:
            student.cancelTeacher();
          case TpLifecycle.submitted:
            student.evaluateTeacher();
            student.closeTeacher();
          case TpLifecycle.evaluated:
            student.closeTeacher();
          case TpLifecycle.closed:
            break;
        }
      }

      final TpSession? teacher = controller.session;
      if (teacher != null && teacher.lifecycle != TpLifecycle.closed) {
        switch (teacher.lifecycle) {
          case TpLifecycle.draft:
          case TpLifecycle.published:
          case TpLifecycle.started:
            controller.cancelTeacher();
          case TpLifecycle.submitted:
            controller.evaluateTeacher();
            controller.closeTeacher();
          case TpLifecycle.evaluated:
            controller.closeTeacher();
          case TpLifecycle.closed:
            break;
        }
      }
    } finally {
      _reconciling = false;
    }
    _classroomClosed = true;
    _sessionStarted = false;
    _broadcastSnapshot();
    notifyListeners();
  }

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
    final List<Uri> joinUrls = endpoints
        .map(
          (Uri endpoint) => endpoint.replace(
            scheme: 'http',
            path: '/join/$sessionCode',
            query: null,
            fragment: null,
          ),
        )
        .toList(growable: false);
    return ElectroSimLanHostInfo(
      sessionCode: sessionCode,
      port: server.port,
      endpoints: List<Uri>.unmodifiable(endpoints),
      joinUrls: List<Uri>.unmodifiable(joinUrls),
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

  String _newReconnectToken() => base64UrlEncode(
    List<int>.generate(32, (_) => _secureRandom.nextInt(256)),
  );

  bool _tokenMatches(String expected, String? presented) {
    if (presented == null || expected.length != presented.length) return false;
    var differences = 0;
    for (var index = 0; index < expected.length; index++) {
      differences |= expected.codeUnitAt(index) ^ presented.codeUnitAt(index);
    }
    return differences == 0;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (request.method == 'GET' && request.uri.path.startsWith('/join/')) {
      final String requestedCode = request.uri.pathSegments.length >= 2
          ? request.uri.pathSegments[1].trim().toUpperCase()
          : '';
      if (requestedCode != sessionCode) {
        request.response.statusCode = HttpStatus.forbidden;
        await request.response.close();
        return;
      }
      await _serveStudentWebAsset(request, 'index.html');
      return;
    }

    if (request.method == 'GET' && request.uri.path != '/electrosim-sync') {
      final String relativePath = request.uri.path == '/'
          ? 'index.html'
          : request.uri.path.substring(1);
      await _serveStudentWebAsset(request, relativePath);
      return;
    }

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
    final String? reconnectToken =
        request.uri.queryParameters['reconnectToken'];
    final String displayName = _safeDisplayName(
      request.uri.queryParameters['displayName'],
      fallback: clientId ?? 'Élève',
    );
    if (code == null ||
        code.trim().toUpperCase() != sessionCode ||
        !_safeClientId(clientId)) {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }

    final String id = clientId!;
    final String? issuedToken = _clientReconnectTokens[id];
    if (issuedToken != null && !_tokenMatches(issuedToken, reconnectToken)) {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }
    final WebSocket socket = await WebSocketTransformer.upgrade(request);
    _clientReconnectTokens.putIfAbsent(id, _newReconnectToken);
    _studentController(id);
    _clientDisplayNames[id] = displayName;
    _studentLastActivityAtUtc[id] = DateTime.now().toUtc();
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
        if (identical(_clients[id], socket)) {
          _clients.remove(id);
          notifyListeners();
        }
      },
      onDone: () {
        if (identical(_clients[id], socket)) {
          _clients.remove(id);
          notifyListeners();
        }
      },
      cancelOnError: false,
    );
    _sendSnapshot(socket, id);
    notifyListeners();
  }

  Future<void> _serveStudentWebAsset(
    HttpRequest request,
    String requestedPath,
  ) async {
    final Directory? root = studentWebRoot;
    if (root == null || !root.existsSync()) {
      request.response
        ..statusCode = HttpStatus.serviceUnavailable
        ..headers.contentType = ContentType.html
        ..write(
          '<!doctype html><html><body><h1>ElectroSim Élève</h1>'
          '<p>Le client Web élève n’est pas disponible dans ce candidat.</p>'
          '</body></html>',
        );
      await request.response.close();
      return;
    }

    String relative = requestedPath.replaceAll(String.fromCharCode(92), '/');
    if (relative.isEmpty) relative = 'index.html';
    if (relative.startsWith('/') || relative.split('/').contains('..')) {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }

    File file = File('${root.path}/$relative');
    if (!file.existsSync() && !relative.split('/').last.contains('.')) {
      file = File('${root.path}/index.html');
    }
    if (!file.existsSync()) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    request.response.headers
      ..set(HttpHeaders.cacheControlHeader, 'no-store')
      ..contentType = _contentTypeFor(file.path);
    await request.response.addStream(file.openRead());
    await request.response.close();
  }

  static ContentType _contentTypeFor(String path) {
    final String lower = path.toLowerCase();
    if (lower.endsWith('.html')) return ContentType.html;
    if (lower.endsWith('.js')) {
      return ContentType('application', 'javascript', charset: 'utf-8');
    }
    if (lower.endsWith('.json')) return ContentType.json;
    if (lower.endsWith('.css')) {
      return ContentType('text', 'css', charset: 'utf-8');
    }
    if (lower.endsWith('.svg')) return ContentType('image', 'svg+xml');
    if (lower.endsWith('.png')) return ContentType('image', 'png');
    if (lower.endsWith('.woff2')) return ContentType('font', 'woff2');
    return ContentType.binary;
  }

  Future<void> _handleClientMessage(
    String clientId,
    WebSocket socket,
    String source,
  ) async {
    try {
      // A superseded socket may still have queued frames: never authorize it.
      if (!identical(_clients[clientId], socket)) {
        throw const FormatException('Socket no longer owns student identity.');
      }
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
      _studentLastActivityAtUtc[clientId] = DateTime.now().toUtc();
      final Object? raw = envelope.payload['state'];
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('studentState payload is missing state.');
      }

      _reconciling = true;
      try {
        _reconcileStudentState(
          clientId,
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
      _sendSnapshot(socket, clientId);
      notifyListeners();
    } on Object catch (error) {
      _sendError(socket, error.toString());
      _sendSnapshot(socket, clientId);
    }
  }

  void _reconcileStudentState(String clientId, Map<String, Object?> state) {
    final ElectroSimTpSessionController student = _studentController(clientId);
    if (state['hasSession'] != true) {
      throw const FormatException('Student state has no TP session.');
    }
    if (state['tpId'] != controller.tpIdValue ||
        state['title'] != controller.title) {
      throw const FormatException('Student TP identity mismatch.');
    }
    final TpSession? teacherSession = controller.session;
    if (teacherSession == null) {
      throw StateError('Teacher has no TP to synchronize.');
    }
    TpSession? initial = student.session;
    if (initial == null) {
      student.restoreFromPersistenceJson(controller.toPersistenceJson());
      initial = student.session;
    }
    if (initial == null) {
      throw StateError('Student replica has no TP to synchronize.');
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

    if (desired == TpLifecycle.evaluated || desired == TpLifecycle.closed) {
      throw StateError(
        'Student cannot set teacher evaluation or close the TP.',
      );
    }

    TpSession current = initial;
    if (teacherSession.lifecycle == TpLifecycle.draft) {
      throw StateError('Teacher TP is not published yet.');
    }
    if (teacherSession.lifecycle == TpLifecycle.published) {
      if (desired == TpLifecycle.published) return;
      throw StateError(
        'Le professeur doit démarrer le TP avant toute mutation élève.',
      );
    }
    if (teacherSession.lifecycle == TpLifecycle.started &&
        current.lifecycle == TpLifecycle.published) {
      current = student.startStudent();
    }
    if (teacherSession.lifecycle == TpLifecycle.closed) {
      throw StateError(
        'Teacher session is closed; student state is read-only.',
      );
    }

    if (current.lifecycle == TpLifecycle.started) {
      if (desired != TpLifecycle.started && desired != TpLifecycle.submitted) {
        throw StateError(
          'Student cannot transition active TP to ${desired.name}.',
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
        current = student.updateStudentCircuit(candidate);
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
      for (
        var index = authoritative.length;
        index < candidates.length;
        index++
      ) {
        final DiagnosticEntry entry = candidates[index];
        current = student.addDiagnosticEntry(
          promptId: entry.promptId,
          answer: entry.answer,
        );
      }
      if (desired == TpLifecycle.submitted) {
        student.submitStudent();
      }
      return;
    }

    if (desired != current.lifecycle) {
      throw StateError(
        'Teacher TP is ${current.lifecycle.name}; student mutation is read-only.',
      );
    }
  }

  void _onControllerChanged() {
    if (_reconciling) return;
    final TpSession? teacherSession = controller.session;

    if (teacherSession == null) {
      resetClassroomActivity();
      return;
    }

    _reconciling = true;
    try {
      for (final ElectroSimTpSessionController student
          in _studentControllers.values) {
        TpSession? current = student.session;
        if (current == null && teacherSession.lifecycle != TpLifecycle.draft) {
          student.restoreFromPersistenceJson(controller.toPersistenceJson());
          current = student.session;
        }
        if (current == null) continue;

        if (teacherSession.lifecycle == TpLifecycle.published &&
            current.lifecycle == TpLifecycle.draft) {
          student.publish();
          current = student.session;
        }

        if (teacherSession.lifecycle == TpLifecycle.started) {
          if (current?.lifecycle == TpLifecycle.draft) {
            student.publish();
            current = student.session;
          }
          if (current?.lifecycle == TpLifecycle.published) {
            student.startStudent();
            current = student.session;
          }
        }

        if (teacherSession.lifecycle == TpLifecycle.closed &&
            current?.lifecycle != TpLifecycle.closed) {
          switch (current!.lifecycle) {
            case TpLifecycle.draft:
            case TpLifecycle.published:
            case TpLifecycle.started:
              student.cancelTeacher();
            case TpLifecycle.submitted:
              student.evaluateTeacher();
              student.closeTeacher();
            case TpLifecycle.evaluated:
              student.closeTeacher();
            case TpLifecycle.closed:
              break;
          }
        }
      }
    } finally {
      _reconciling = false;
    }
    _broadcastSnapshot();
    notifyListeners();
  }

  void _broadcastSnapshot() {
    for (final MapEntry<String, WebSocket> entry in _clients.entries.toList(
      growable: false,
    )) {
      _sendSnapshot(entry.value, entry.key);
    }
  }

  void _sendSnapshot(WebSocket socket, [String? clientId]) {
    final ElectroSimTpSessionController source = clientId == null
        ? controller
        : _studentController(clientId);
    _send(
      socket,
      ElectroSimSyncEnvelope(
        type: ElectroSimSyncMessageType.snapshot,
        sessionCode: sessionCode,
        senderId: hostId,
        sequence: _serverSequence++,
        payload: <String, Object?>{
          'state': source.toStudentPersistenceJson(),
          if (clientId != null)
            'reconnectToken': _clientReconnectTokens[clientId],
          'session': <String, Object?>{
            'name': sessionName,
            'code': sessionCode,
            'started': _sessionStarted,
            'closed': _classroomClosed,
            'simulatorEnabled': _sessionStarted && !_classroomClosed,
          },
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
    final List<WebSocket> sockets = _clients.values.toList(growable: false);
    _clients.clear();
    _clientDisplayNames.clear();
    _clientReconnectTokens.clear();
    _studentLastActivityAtUtc.clear();
    for (final WebSocket socket in sockets) {
      await socket.close(
        WebSocketStatus.normalClosure,
        'Teacher session closed.',
      );
    }
    final HttpServer? server = _server;
    _server = null;
    await server?.close(force: true);
    for (final ElectroSimTpSessionController student
        in _studentControllers.values) {
      student.dispose();
    }
    _studentControllers.clear();
    notifyListeners();
  }

  static bool _safeClientId(String? value) =>
      value != null &&
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{2,79}$').hasMatch(value);

  static String _safeDisplayName(String? value, {required String fallback}) {
    final String normalized = (value ?? '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.length >= 2 && normalized.length <= 80) {
      return normalized;
    }
    return fallback;
  }
}

final class ElectroSimLanSyncClient extends ChangeNotifier {
  ElectroSimLanSyncClient({
    required this.controller,
    required String sessionCode,
    required this.clientId,
    this.displayName,
    this.autoReconnect = true,
  }) : sessionCode = sessionCode.trim().toUpperCase() {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{2,79}$').hasMatch(clientId)) {
      throw ArgumentError.value(clientId, 'clientId', 'Invalid client ID.');
    }
    controller.addListener(_onLocalControllerChanged);
  }

  final ElectroSimTpSessionController controller;
  final String sessionCode;
  final String clientId;
  final String? displayName;
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
  String? _reconnectToken;

  ElectroSimLanSyncStatus get status => _status;
  String? get lastError => _lastError;
  bool get synchronized => _status == ElectroSimLanSyncStatus.synchronized;
  Uri? get endpoint => _endpoint;

  static String generateClientId({Random? random}) {
    final Random source = random ?? Random.secure();
    final int value = source.nextInt(0x7fffffff);
    return 'student-${value.toRadixString(16).padLeft(8, '0')}';
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
    await socket?.close(WebSocketStatus.goingAway, 'Student disconnected.');
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
    await _socket?.close(WebSocketStatus.goingAway, 'Manual reconnect.');
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
        if (_reconnectToken != null) 'reconnectToken': _reconnectToken!,
        if (displayName != null && displayName!.trim().isNotEmpty)
          'displayName': displayName!.trim(),
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
      _firstSnapshot = null;
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
          final Object? issuedToken = envelope.payload['reconnectToken'];
          if (issuedToken is! String || issuedToken.isEmpty) {
            throw const FormatException('Missing student reconnect token.');
          }
          _reconnectToken = issuedToken;
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
          _setStatus(ElectroSimLanSyncStatus.synchronized);
          final Completer<void>? first = _firstSnapshot;
          _firstSnapshot = null;
          if (first != null && !first.isCompleted) first.complete();
          notifyListeners();
          break;
        case ElectroSimSyncMessageType.ack:
          _lastError = null;
          notifyListeners();
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
      payload: <String, Object?>{'state': controller.toPersistenceJson()},
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
    final Completer<void>? first = _firstSnapshot;
    _firstSnapshot = null;
    if (first != null && !first.isCompleted) {
      first.completeError(
        StateError('LAN connection closed before initial synchronization.'),
      );
    }
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
    if (_closed || _manualDisconnect || _reconnectTimer?.isActive == true) {
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
