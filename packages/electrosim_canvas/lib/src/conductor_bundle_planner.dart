import 'dart:ui';

import 'wire_geometry.dart';

enum ConductorLaneRole {
  dcPositive,
  dcNegative,
  l1,
  l2,
  l3,
  neutral,
  protectiveEarth,
}

final class ConductorBundlePlan {
  ConductorBundlePlan({
    required List<ConductorLaneRole> laneOrder,
    required Map<ConductorLaneRole, OrthogonalWirePath> paths,
    required this.commonBendStationX,
  }) : laneOrder = List<ConductorLaneRole>.unmodifiable(laneOrder),
       paths = Map<ConductorLaneRole, OrthogonalWirePath>.unmodifiable(paths);

  final List<ConductorLaneRole> laneOrder;
  final Map<ConductorLaneRole, OrthogonalWirePath> paths;
  final double? commonBendStationX;
}

final class ConductorBundlePlanner {
  const ConductorBundlePlanner({required this.lanePitch, required this.grid})
    : assert(lanePitch > 0),
      assert(grid > 0);

  final double lanePitch;
  final double grid;

  ConductorBundlePlan planAc1({required Offset start, required Offset end}) {
    return _plan(
      roles: const <ConductorLaneRole>[
        ConductorLaneRole.l1,
        ConductorLaneRole.neutral,
        ConductorLaneRole.protectiveEarth,
      ],
      start: start,
      end: end,
    );
  }

  ConductorBundlePlan planAc3({required Offset start, required Offset end}) {
    return _plan(
      roles: const <ConductorLaneRole>[
        ConductorLaneRole.l1,
        ConductorLaneRole.l2,
        ConductorLaneRole.l3,
        ConductorLaneRole.neutral,
        ConductorLaneRole.protectiveEarth,
      ],
      start: start,
      end: end,
    );
  }

  ConductorBundlePlan planPvDcPair({
    required Offset start,
    required Offset end,
  }) {
    return _plan(
      roles: const <ConductorLaneRole>[
        ConductorLaneRole.dcPositive,
        ConductorLaneRole.dcNegative,
      ],
      start: start,
      end: end,
    );
  }

  ConductorBundlePlan _plan({
    required List<ConductorLaneRole> roles,
    required Offset start,
    required Offset end,
  }) {
    final Map<ConductorLaneRole, OrthogonalWirePath> paths =
        <ConductorLaneRole, OrthogonalWirePath>{};

    if (start.dy == end.dy) {
      for (var index = 0; index < roles.length; index++) {
        final double offset = index * lanePitch;
        paths[roles[index]] = OrthogonalWirePath(
          points: <Offset>[
            Offset(start.dx, start.dy + offset),
            Offset(end.dx, end.dy + offset),
          ],
        );
      }
      return ConductorBundlePlan(
        laneOrder: roles,
        paths: paths,
        commonBendStationX: null,
      );
    }

    if (start.dx == end.dx) {
      for (var index = 0; index < roles.length; index++) {
        final double offset = index * lanePitch;
        paths[roles[index]] = OrthogonalWirePath(
          points: <Offset>[
            Offset(start.dx + offset, start.dy),
            Offset(end.dx + offset, end.dy),
          ],
        );
      }
      return ConductorBundlePlan(
        laneOrder: roles,
        paths: paths,
        commonBendStationX: null,
      );
    }

    final double direction = end.dx >= start.dx ? 1 : -1;
    final double midpointX = _snap((start.dx + end.dx) / 2);
    final bool movingDown = end.dy > start.dy;

    for (var index = 0; index < roles.length; index++) {
      final double laneOffset = index * lanePitch;
      final Offset laneStart = Offset(start.dx, start.dy + laneOffset);
      final Offset laneEnd = Offset(end.dx, end.dy + laneOffset);
      final int rank = movingDown ? roles.length - 1 - index : index;
      final double rankOffset =
          (rank - (roles.length - 1) / 2) * lanePitch * direction;
      final double bendX = _snap(midpointX + rankOffset);
      paths[roles[index]] = OrthogonalWirePath(
        points: <Offset>[
          laneStart,
          Offset(bendX, laneStart.dy),
          Offset(bendX, laneEnd.dy),
          laneEnd,
        ],
      );
    }

    return ConductorBundlePlan(
      laneOrder: roles,
      paths: paths,
      commonBendStationX: null,
    );
  }

  double _snap(double value) => (value / grid).roundToDouble() * grid;
}

enum PvVisualZone {
  generation,
  dcProtection,
  regulationStorage,
  conversion,
  acDistributionLoad,
}

final class PvVisualZonePlan {
  PvVisualZonePlan({
    required List<PvVisualZone> zoneOrder,
    required Map<PvVisualZone, Rect> bounds,
  }) : zoneOrder = List<PvVisualZone>.unmodifiable(zoneOrder),
       bounds = Map<PvVisualZone, Rect>.unmodifiable(bounds);

  final List<PvVisualZone> zoneOrder;
  final Map<PvVisualZone, Rect> bounds;
}

final class PvVisualZonePlanner {
  const PvVisualZonePlanner({
    required this.minimumZoneWidth,
    required this.zoneGap,
  }) : assert(minimumZoneWidth > 0),
       assert(zoneGap >= 0);

  final double minimumZoneWidth;
  final double zoneGap;

  PvVisualZonePlan plan({required Offset origin, required double height}) {
    if (height <= 0) {
      throw ArgumentError.value(height, 'height', 'Height must be positive.');
    }
    const List<PvVisualZone> order = <PvVisualZone>[
      PvVisualZone.generation,
      PvVisualZone.dcProtection,
      PvVisualZone.regulationStorage,
      PvVisualZone.conversion,
      PvVisualZone.acDistributionLoad,
    ];
    final Map<PvVisualZone, Rect> bounds = <PvVisualZone, Rect>{};
    double x = origin.dx;
    for (final PvVisualZone zone in order) {
      bounds[zone] = Rect.fromLTWH(x, origin.dy, minimumZoneWidth, height);
      x += minimumZoneWidth + zoneGap;
    }
    return PvVisualZonePlan(zoneOrder: order, bounds: bounds);
  }
}
