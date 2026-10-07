import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pointer-move drag path never invokes geometry rebuild or global routing', () {
    final String source = File('lib/main.dart').readAsStringSync();
    final int moveStart = source.indexOf('void _commitElementMoveIfSafe(');
    final int finalizeStart = source.indexOf(
      'void _finalizeDirectDrag(',
      moveStart,
    );
    expect(moveStart, greaterThanOrEqualTo(0));
    expect(finalizeStart, greaterThan(moveStart));

    final String moveMethod = source.substring(moveStart, finalizeStart);
    final int movingBranch = moveMethod.indexOf('if (moving)');
    final int movingReturn = moveMethod.indexOf('return;', movingBranch);
    expect(movingBranch, greaterThanOrEqualTo(0));
    expect(movingReturn, greaterThan(movingBranch));

    final String hotPath = moveMethod.substring(movingBranch, movingReturn);
    expect(hotPath, contains('F18DragSession'));
    expect(hotPath, contains('_dragPreviewLayout.value = session.previewAt'));
    expect(hotPath, isNot(contains('setState')));
    expect(hotPath, isNot(contains('CircuitGeometryIndex.build')));
    expect(hotPath, isNot(contains('_routeWithG2A')));
    expect(hotPath, isNot(contains('routeAll(')));
  });

  test('authoritative routing is deferred to pointer-up', () {
    final String source = File('lib/main.dart').readAsStringSync();
    final int start = source.indexOf('void _finalizeDirectDrag(');
    final int end = source.indexOf('void _cancelCanvasInteraction(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final String method = source.substring(start, end);
    expect(method, contains('_dragPreviewLayout.value ?? _layout'));
    expect(method, contains('_routeWithG2A(_circuit, preview)'));
    expect(method, contains('F18WorkspaceWireSafety.isRenderable'));
  });
}
