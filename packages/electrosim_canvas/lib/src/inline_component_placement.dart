import 'dart:ui';

import 'wire_geometry.dart';

enum InlinePlacementFailure {
  insufficientStraightLength,
}

final class InlinePlacementResult {
  const InlinePlacementResult._({
    required this.centers,
    required this.reason,
  });

  factory InlinePlacementResult.resolved(List<Offset> centers) {
    return InlinePlacementResult._(
      centers: List<Offset>.unmodifiable(centers),
      reason: null,
    );
  }

  const InlinePlacementResult.unresolved(InlinePlacementFailure failure)
      : this._(
          centers: const <Offset>[],
          reason: failure,
        );

  final List<Offset> centers;
  final InlinePlacementFailure? reason;

  bool get isResolved => reason == null;
}

final class InlinePlacementPolicy {
  const InlinePlacementPolicy({
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

  InlinePlacementResult placeCentered({
    required OrthogonalSegment host,
    required List<double> componentExtents,
  }) {
    final WireAxis axis = host.axis;
    if (componentExtents.isEmpty ||
        componentExtents.any((double extent) => extent <= 0)) {
      throw ArgumentError.value(
        componentExtents,
        'componentExtents',
        'Component extents must contain positive values.',
      );
    }

    final double hostStart =
        axis == WireAxis.horizontal ? host.minX : host.minY;
    final double hostEnd =
        axis == WireAxis.horizontal ? host.maxX : host.maxY;
    final double edgeClearance = bendKeepOut + minimumTerminalStub;
    final double usableStart = hostStart + edgeClearance;
    final double usableEnd = hostEnd - edgeClearance;

    final double bodies = componentExtents.fold<double>(
      0,
      (double sum, double value) => sum + value,
    );
    final double gaps =
        minimumComponentGap * (componentExtents.length - 1);
    final double totalSpan = bodies + gaps;

    if (usableEnd - usableStart < totalSpan) {
      return const InlinePlacementResult.unresolved(
        InlinePlacementFailure.insufficientStraightLength,
      );
    }

    final double hostMidpoint = (hostStart + hostEnd) / 2;
    final double groupMidpoint = _snap(hostMidpoint, grid);
    double cursor = groupMidpoint - totalSpan / 2;

    if (cursor < usableStart) {
      cursor = usableStart;
    }
    if (cursor + totalSpan > usableEnd) {
      cursor = usableEnd - totalSpan;
    }

    final List<Offset> centers = <Offset>[];
    for (final double extent in componentExtents) {
      final double along = _snap(cursor + extent / 2, grid);
      centers.add(
        axis == WireAxis.horizontal
            ? Offset(along, host.start.dy)
            : Offset(host.start.dx, along),
      );
      cursor += extent + minimumComponentGap;
    }

    if (!_fits(
      centers: centers,
      extents: componentExtents,
      usableStart: usableStart,
      usableEnd: usableEnd,
      axis: axis,
    )) {
      return const InlinePlacementResult.unresolved(
        InlinePlacementFailure.insufficientStraightLength,
      );
    }

    return InlinePlacementResult.resolved(centers);
  }

  static double _snap(double value, double grid) {
    return (value / grid).roundToDouble() * grid;
  }

  static bool _fits({
    required List<Offset> centers,
    required List<double> extents,
    required double usableStart,
    required double usableEnd,
    required WireAxis axis,
  }) {
    for (var index = 0; index < centers.length; index++) {
      final double center =
          axis == WireAxis.horizontal ? centers[index].dx : centers[index].dy;
      final double half = extents[index] / 2;
      if (center - half < usableStart || center + half > usableEnd) {
        return false;
      }
      if (index > 0) {
        final double previousCenter = axis == WireAxis.horizontal
            ? centers[index - 1].dx
            : centers[index - 1].dy;
        final double previousHalf = extents[index - 1] / 2;
        if (center - half < previousCenter + previousHalf) {
          return false;
        }
      }
    }
    return true;
  }
}
