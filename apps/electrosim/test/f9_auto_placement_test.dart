import 'dart:ui';

import 'package:electrosim/f9_auto_placement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quick-add avoids occupied element rectangles', () {
    const Rect visible = Rect.fromLTWH(0, 0, 900, 600);
    const Size size = Size(104, 64);
    final Rect occupied = Rect.fromCenter(
      center: const Offset(450, 400),
      width: 140,
      height: 100,
    );

    final Offset? result = F9AutoPlacement.findPosition(
      visibleWorldRect: visible,
      elementSize: size,
      occupiedElements: <Rect>[occupied],
      occupiedPolylines: const <List<Offset>>[],
    );
    expect(result, isNotNull);
    final Rect placed = Rect.fromCenter(
      center: result!,
      width: size.width,
      height: size.height,
    );

    expect(placed.inflate(18).overlaps(occupied.inflate(9)), isFalse);
  });

  test('quick-add avoids wire segments that cross its preferred position', () {
    const Rect visible = Rect.fromLTWH(0, 0, 900, 600);
    const Size size = Size(104, 64);
    const List<Offset> wire = <Offset>[Offset(100, 400), Offset(800, 400)];

    final Offset? result = F9AutoPlacement.findPosition(
      visibleWorldRect: visible,
      elementSize: size,
      occupiedElements: const <Rect>[],
      occupiedPolylines: const <List<Offset>>[wire],
    );
    expect(result, isNotNull);
    final Rect placed = Rect.fromCenter(
      center: result!,
      width: size.width,
      height: size.height,
    ).inflate(18);

    expect(placed.contains(const Offset(450, 400)), isFalse);
    expect(result.dy, isNot(closeTo(400, 50)));
  });

  test('successive quick-add can reserve the previous result', () {
    const Rect visible = Rect.fromLTWH(0, 0, 900, 600);
    const Size size = Size(104, 64);
    final Offset? first = F9AutoPlacement.findPosition(
      visibleWorldRect: visible,
      elementSize: size,
      occupiedElements: const <Rect>[],
      occupiedPolylines: const <List<Offset>>[],
    );
    expect(first, isNotNull);
    final Rect firstRect = Rect.fromCenter(
      center: first!,
      width: size.width,
      height: size.height,
    );
    final Offset? second = F9AutoPlacement.findPosition(
      visibleWorldRect: visible,
      elementSize: size,
      occupiedElements: <Rect>[firstRect],
      occupiedPolylines: const <List<Offset>>[],
    );

    expect(second, isNotNull);
    expect(second, isNot(first));
    expect(
      Rect.fromCenter(
        center: second!,
        width: size.width,
        height: size.height,
      ).inflate(18).overlaps(firstRect.inflate(9)),
      isFalse,
    );
  });

  test('quick-add refuses ambiguous placement when viewport is saturated', () {
    const Rect visible = Rect.fromLTWH(0, 0, 180, 120);
    const Size size = Size(104, 64);
    final Offset? result = F9AutoPlacement.findPosition(
      visibleWorldRect: visible,
      elementSize: size,
      occupiedElements: <Rect>[visible],
      occupiedPolylines: const <List<Offset>>[],
    );

    expect(result, isNull);
  });
}
