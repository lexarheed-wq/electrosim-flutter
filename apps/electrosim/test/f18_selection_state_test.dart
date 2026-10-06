import 'package:electrosim/f18_selection_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plain selection always replaces the current selection', () {
    F18SelectionState state = F18SelectionState.single('a');
    state = state.select('b', additive: false);
    expect(state.selectedIds, <String>{'b'});
    expect(state.primaryId, 'b');
  });

  test('modifier selection toggles members without implicit activation', () {
    F18SelectionState state = F18SelectionState.empty();
    state = state.select('a', additive: true);
    state = state.select('b', additive: true);
    expect(state.selectedIds, <String>{'a', 'b'});
    expect(state.primaryId, 'b');

    state = state.select('b', additive: true);
    expect(state.selectedIds, <String>{'a'});
    expect(state.primaryId, 'a');

    state = state.select('a', additive: true);
    expect(state.selectedIds, isEmpty);
    expect(state.primaryId, isNull);
  });
}
