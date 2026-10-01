import 'dart:ui';

import 'inline_component_placement.dart';
import 'wire_geometry.dart';

final class DcInlineElement {
  const DcInlineElement({
    required this.id,
    required this.extent,
  });

  final String id;
  final double extent;
}

enum DcArrangeFailure {
  insufficientStraightBranchLength,
}

final class DcRectangularArrangement {
  DcRectangularArrangement._({
    required Map<String, Offset> positions,
    required this.outerLoop,
    required this.failure,
  }) : positions = Map<String, Offset>.unmodifiable(positions);

  factory DcRectangularArrangement.resolved({
    required Map<String, Offset> positions,
    required OrthogonalWirePath outerLoop,
  }) {
    return DcRectangularArrangement._(
      positions: positions,
      outerLoop: outerLoop,
      failure: null,
    );
  }

  const DcRectangularArrangement.unresolved(this.failure)
      : positions = const <String, Offset>{},
        outerLoop = null;

  final Map<String, Offset> positions;
  final OrthogonalWirePath? outerLoop;
  final DcArrangeFailure? failure;

  bool get isResolved => failure == null;
}

final class DcRectangularArrangePolicy {
  const DcRectangularArrangePolicy({
    required this.grid,
    required this.bendKeepOut,
    required this.minimumTerminalStub,
    required this.minimumComponentGap,
  }) : assert(grid > 0),
       assert(bendKeepOut >= 0),
       assert(minimumTerminalStub >= 0),
       assert(minimumComponentGap >= 0);

  final double grid;
  final double bendKeepOut;
  final double minimumTerminalStub;
  final double minimumComponentGap;

  DcRectangularArrangement arrange({
    required Offset topLeft,
    required double width,
    required double height,
    required String sourceId,
    required String loadId,
    List<DcInlineElement> topInlineElements = const <DcInlineElement>[],
  }) {
    if (width <= 0 || height <= 0) {
      return const DcRectangularArrangement.unresolved(
        DcArrangeFailure.insufficientStraightBranchLength,
      );
    }

    final Offset topRight = Offset(topLeft.dx + width, topLeft.dy);
    final Offset bottomRight = Offset(
      topLeft.dx + width,
      topLeft.dy + height,
    );
    final Offset bottomLeft = Offset(topLeft.dx, topLeft.dy + height);
    final OrthogonalWirePath loop = OrthogonalWirePath(
      points: <Offset>[
        topLeft,
        topRight,
        bottomRight,
        bottomLeft,
        topLeft,
      ],
    );

    final Map<String, Offset> positions = <String, Offset>{
      sourceId: Offset(
        topLeft.dx,
        _snap(topLeft.dy + height / 2),
      ),
      loadId: Offset(
        topRight.dx,
        _snap(topRight.dy + height / 2),
      ),
    };

    if (topInlineElements.isEmpty) {
      return DcRectangularArrangement.resolved(
        positions: positions,
        outerLoop: loop,
      );
    }

    final OrthogonalSegment host = OrthogonalSegment(
      start: topLeft,
      end: topRight,
    );
    final List<Offset>? centers = _symmetricCenters(
      host: host,
      elements: topInlineElements,
    );
    if (centers == null) {
      return const DcRectangularArrangement.unresolved(
        DcArrangeFailure.insufficientStraightBranchLength,
      );
    }

    for (var index = 0; index < topInlineElements.length; index++) {
      positions[topInlineElements[index].id] = centers[index];
    }
    return DcRectangularArrangement.resolved(
      positions: positions,
      outerLoop: loop,
    );
  }

  List<Offset>? _symmetricCenters({
    required OrthogonalSegment host,
    required List<DcInlineElement> elements,
  }) {
    if (elements.any((DcInlineElement element) => element.extent <= 0)) {
      throw ArgumentError.value(
        elements,
        'elements',
        'Inline component extents must be positive.',
      );
    }

    final bool equalExtents = elements.every(
      (DcInlineElement element) => element.extent == elements.first.extent,
    );
    if (!equalExtents) {
      final InlinePlacementResult fallback = InlinePlacementPolicy(
        grid: grid,
        bendKeepOut: bendKeepOut,
        minimumTerminalStub: minimumTerminalStub,
        minimumComponentGap: minimumComponentGap,
      ).placeCentered(
        host: host,
        componentExtents: elements
            .map((DcInlineElement element) => element.extent)
            .toList(growable: false),
      );
      return fallback.isResolved ? fallback.centers : null;
    }

    final double extent = elements.first.extent;
    final double leftLimit =
        host.minX + bendKeepOut + minimumTerminalStub + extent / 2;
    final double rightLimit =
        host.maxX - bendKeepOut - minimumTerminalStub - extent / 2;
    final double midpoint = _snap((host.minX + host.maxX) / 2);

    final List<double> xs = <double>[];
    if (elements.length.isOdd) {
      xs.add(midpoint);
      final double step = _ceilToGrid(extent + minimumComponentGap);
      for (var ring = 1; xs.length < elements.length; ring++) {
        xs
          ..insert(0, midpoint - ring * step)
          ..add(midpoint + ring * step);
      }
    } else {
      final double halfStep =
          _ceilToGrid((extent + minimumComponentGap) / 2);
      for (var ring = elements.length ~/ 2 - 1; ring >= 0; ring--) {
        xs.add(midpoint - (2 * ring + 1) * halfStep);
      }
      for (var ring = 0; ring < elements.length ~/ 2; ring++) {
        xs.add(midpoint + (2 * ring + 1) * halfStep);
      }
    }

    xs.sort();
    if (xs.first < leftLimit || xs.last > rightLimit) {
      return null;
    }

    for (var index = 1; index < xs.length; index++) {
      final double gap = xs[index] - xs[index - 1] - extent;
      if (gap < minimumComponentGap) {
        return null;
      }
    }

    return xs
        .map((double x) => Offset(x, host.start.dy))
        .toList(growable: false);
  }

  double _snap(double value) => (value / grid).roundToDouble() * grid;

  double _ceilToGrid(double value) {
    return (value / grid).ceilToDouble() * grid;
  }
}
