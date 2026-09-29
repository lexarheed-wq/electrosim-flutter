import 'dart:ui';

import 'package:flutter/foundation.dart';

@immutable
final class CircuitVisualLayout {
  CircuitVisualLayout({
    required Map<String, Offset> elementPositions,
    Map<String, Size> elementSizes = const <String, Size>{},
    Map<String, List<Offset>> wireRoutes = const <String, List<Offset>>{},
    this.defaultElementSize = const Size(104, 64),
  }) : elementPositions = Map<String, Offset>.unmodifiable(elementPositions),
       elementSizes = Map<String, Size>.unmodifiable(elementSizes),
       wireRoutes = Map<String, List<Offset>>.unmodifiable(
         wireRoutes.map(
           (String key, List<Offset> value) =>
               MapEntry<String, List<Offset>>(key, List<Offset>.unmodifiable(value)),
         ),
       );

  final Map<String, Offset> elementPositions;
  final Map<String, Size> elementSizes;
  final Map<String, List<Offset>> wireRoutes;
  final Size defaultElementSize;

  Offset? positionOf(String elementId) => elementPositions[elementId];

  Size sizeOf(String elementId) => elementSizes[elementId] ?? defaultElementSize;

  List<Offset> routeFor(String connectionId) =>
      wireRoutes[connectionId] ?? const <Offset>[];

  CircuitVisualLayout moveElement(String elementId, Offset worldPosition) {
    final Map<String, Offset> next = <String, Offset>{...elementPositions};
    next[elementId] = worldPosition;
    return CircuitVisualLayout(
      elementPositions: next,
      elementSizes: elementSizes,
      wireRoutes: wireRoutes,
      defaultElementSize: defaultElementSize,
    );
  }
}
