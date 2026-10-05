import 'package:flutter/foundation.dart';

@immutable
final class F18SelectionState {
  F18SelectionState._({
    required Set<String> selectedIds,
    required this.primaryId,
  }) : selectedIds = Set<String>.unmodifiable(selectedIds);

  factory F18SelectionState.empty() =>
      F18SelectionState._(selectedIds: const <String>{}, primaryId: null);

  factory F18SelectionState.single(String id) =>
      F18SelectionState._(selectedIds: <String>{id}, primaryId: id);

  final Set<String> selectedIds;
  final String? primaryId;

  bool get isEmpty => selectedIds.isEmpty;
  int get length => selectedIds.length;

  F18SelectionState select(String id, {required bool additive}) {
    if (!additive) {
      return F18SelectionState.single(id);
    }

    final Set<String> next = <String>{...selectedIds};
    String? nextPrimary = primaryId;
    if (!next.add(id)) {
      next.remove(id);
      if (nextPrimary == id) {
        nextPrimary = next.isEmpty ? null : next.last;
      }
    } else {
      nextPrimary = id;
    }
    return F18SelectionState._(
      selectedIds: next,
      primaryId: nextPrimary,
    );
  }

  F18SelectionState clear() => F18SelectionState.empty();
}
