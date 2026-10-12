/// Revision-aware single-flight transport independent of UI framework.
/// The executor must implement a genuine worker/isolate separately; this class
/// does not claim thread isolation or performance qualification.
final class RevisionJob<T> {
  const RevisionJob({required this.revision, required this.requestId, required this.payload});
  final int revision;
  final int requestId;
  final T payload;
}

final class RevisionGate<T> {
  int _revision = 0;
  int _requestId = 0;
  bool _closed = false;
  RevisionJob<T>? _active;
  RevisionJob<T>? _pending;
  int get revision => _revision;
  RevisionJob<T>? get active => _active;
  RevisionJob<T>? get pending => _pending;
  void updateRevision(int revision) {
    if (_closed) throw StateError('Gate closed');
    if (revision <= _revision) throw ArgumentError.value(revision, 'revision', 'Must increase');
    _revision = revision;
    _pending = null;
  }
  RevisionJob<T>? submit(T payload) {
    if (_closed) throw StateError('Gate closed');
    final job = RevisionJob<T>(revision: _revision, requestId: ++_requestId, payload: payload);
    if (_active == null) { _active = job; return job; }
    _pending = job;
    return null;
  }
  /// Returns the next job to dispatch. Stale responses are never accepted.
  RevisionJob<T>? complete(int revision, int requestId) {
    if (_closed || _active?.requestId != requestId || _active?.revision != revision) return null;
    _active = null;
    final next = _pending;
    _pending = null;
    if (next != null && next.revision == _revision) { _active = next; return next; }
    return null;
  }
  bool accepts(int revision, int requestId) => !_closed && revision == _revision && _active?.revision == revision && _active?.requestId == requestId;
  void close() { _closed = true; _active = null; _pending = null; }
}
