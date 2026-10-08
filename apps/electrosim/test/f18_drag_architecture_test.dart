import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wiring hover uses prepared terminal hit testing and isolated preview notifier', () {
    final String source = File('lib/main.dart').readAsStringSync();
    final int start = source.indexOf('void _updateWiringHover(');
    final int end = source.indexOf('void _handleConnectionRequested(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final String method = source.substring(start, end);
    expect(method, contains('hitTestTerminalPrepared'));
    expect(method, contains('_preparedHitTestSession()'));
    expect(method, contains('_wiringPointerWorld.value = worldPoint'));
    expect(method, isNot(contains('CircuitGeometryIndex.build')));
    expect(method, isNot(contains('_f9CanvasHit(localPosition)')));
  });

  test('full canvas hit testing reuses a prepared session', () {
    final String source = File('lib/main.dart').readAsStringSync();
    final int start = source.indexOf('CanvasHitResult _f9CanvasHit(');
    final int end = source.indexOf('void _onCanvasPointerDown(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final String method = source.substring(start, end);
    expect(method, contains('hitTestPrepared'));
    expect(method, contains('_preparedHitTestSession()'));
  });

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

  test('authoritative routing is offloaded to worker after pointer-up', () {
    final String source = File('lib/main.dart').readAsStringSync();
    final int start = source.indexOf('void _finalizeDirectDrag(');
    final int end = source.indexOf('void _cancelCanvasInteraction(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final String method = source.substring(start, end);
    expect(method, contains('_dragPreviewLayout.value ?? _layout'));
    expect(method, contains('unawaited(_finishElementRoute('));
    expect(method, isNot(contains('_routeWithG2A(')));
    expect(method, isNot(contains('routeAll(')));
  });
}
