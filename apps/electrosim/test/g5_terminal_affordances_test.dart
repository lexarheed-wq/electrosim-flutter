import 'package:electrosim/f18_terminal_affordances.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('physical terminals have no interaction marker at rest', () {
    expect(
      F18TerminalAffordances.visible(
        hovered: false,
        pending: false,
        selected: false,
        showAll: false,
      ),
      isFalse,
    );
  });
  test(
    'mouse, touch selection, wiring origin and explicit display expose terminals',
    () {
      for (var mode = 0; mode < 4; mode++) {
        expect(
          F18TerminalAffordances.visible(
            hovered: mode == 0,
            pending: mode == 1,
            selected: mode == 2,
            showAll: mode == 3,
          ),
          isTrue,
        );
      }
    },
  );
}
