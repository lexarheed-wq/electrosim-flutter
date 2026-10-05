import 'dart:ui';

import 'package:flutter/foundation.dart';

@immutable
final class CircuitVisualLayout {
  CircuitVisualLayout({
    required Map<String, Offset> elementPositions,
    Map<String, Size> elementSizes = const <String, Size>{},
    Map<String, List<Offset>> wireRoutes = const <String, List<Offset>>{},
    Map<String, int> elementQuarterTurns = const <String, int>{},
    this.defaultElementSize = const Size(104, 64),
  }) : elementPositions = Map<String, Offset>.unmodifiable(elementPositions),
       elementSizes = Map<String, Size>.unmodifiable(elementSizes),
       wireRoutes = Map<String, List<Offset>>.unmodifiable(
         wireRoutes.map(
           (String key, List<Offset> value) => MapEntry<String, List<Offset>>(
             key,
             List<Offset>.unmodifiable(value),
           ),
         ),
       ),
       elementQuarterTurns = Map<String, int>.unmodifiable(
         elementQuarterTurns.map(
           (String key, int value) =>
               MapEntry<String, int>(key, _normalizeQuarterTurns(value)),
         ),
       );

  final Map<String, Offset> elementPositions;
  final Map<String, Size> elementSizes;
  final Map<String, List<Offset>> wireRoutes;
  final Map<String, int> elementQuarterTurns;
  final Size defaultElementSize;

  Offset? positionOf(String elementId) => elementPositions[elementId];

  Size sizeOf(String elementId) =>
      elementSizes[elementId] ?? defaultElementSize;

  int quarterTurnsOf(String elementId) => elementQuarterTurns[elementId] ?? 0;

  Size displaySizeOf(String elementId) {
    final Size size = sizeOf(elementId);
    return quarterTurnsOf(elementId).isOdd
        ? Size(size.height, size.width)
        : size;
  }

  List<Offset> routeFor(String connectionId) =>
      wireRoutes[connectionId] ?? const <Offset>[];

  CircuitVisualLayout moveElement(String elementId, Offset worldPosition) {
    final Map<String, Offset> next = <String, Offset>{...elementPositions};
    next[elementId] = worldPosition;
    return CircuitVisualLayout(
      elementPositions: next,
      elementSizes: elementSizes,
      wireRoutes: wireRoutes,
      elementQuarterTurns: elementQuarterTurns,
      defaultElementSize: defaultElementSize,
    );
  }

  CircuitVisualLayout rotateElement(
    String elementId, {
    int deltaQuarterTurns = 1,
  }) {
    if (!elementPositions.containsKey(elementId)) {
      return this;
    }
    final Map<String, int> next = <String, int>{...elementQuarterTurns};
    next[elementId] = _normalizeQuarterTurns(
      quarterTurnsOf(elementId) + deltaQuarterTurns,
    );
    return CircuitVisualLayout(
      elementPositions: elementPositions,
      elementSizes: elementSizes,
      wireRoutes: wireRoutes,
      elementQuarterTurns: next,
      defaultElementSize: defaultElementSize,
    );
  }

  static int _normalizeQuarterTurns(int value) {
    final int result = value % 4;
    return result < 0 ? result + 4 : result;
  }
}
