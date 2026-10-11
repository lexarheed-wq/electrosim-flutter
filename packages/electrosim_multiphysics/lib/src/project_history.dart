import 'dart:collection';

/// Transactional design history. Only accepted immutable projects are recorded.
/// Runtime gas masses belong to the solver snapshot, never to this history.
final class ProjectHistory<T> {
  ProjectHistory(T initial, {this.capacity = 100}) : _current = initial {
    if (capacity <= 0) {
      throw ArgumentError.value(capacity, 'capacity', 'Must be positive');
    }
  }
  final int capacity;
  T _current;
  final List<T> _undo = <T>[];
  final List<T> _redo = <T>[];
  T get current => _current;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  List<T> get undoEntries => UnmodifiableListView<T>(_undo);

  void accept(T next) {
    if (identical(next, _current)) return;
    _undo.add(_current);
    if (_undo.length > capacity) _undo.removeAt(0);
    _current = next;
    _redo.clear();
  }

  T undo() {
    if (!canUndo) throw StateError('No undo entry');
    _redo.add(_current);
    _current = _undo.removeLast();
    return _current;
  }

  T redo() {
    if (!canRedo) throw StateError('No redo entry');
    _undo.add(_current);
    _current = _redo.removeLast();
    return _current;
  }
}
