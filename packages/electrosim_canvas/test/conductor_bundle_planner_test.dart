import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ConductorBundlePlanner planner = ConductorBundlePlanner(
    lanePitch: 24,
    grid: 24,
  );

  test('AC1 preserves L N PE order and common bend station', () {
    final ConductorBundlePlan plan = planner.planAc1(
      start: const Offset(48, 72),
      end: const Offset(432, 168),
    );

    expect(
      plan.laneOrder,
      const <ConductorLaneRole>[
        ConductorLaneRole.l1,
        ConductorLaneRole.neutral,
        ConductorLaneRole.protectiveEarth,
      ],
    );
    expect(plan.paths, hasLength(3));
    expect(plan.commonBendStationX, isNotNull);

    final List<double> startYs = plan.laneOrder
        .map((role) => plan.paths[role]!.points.first.dy)
        .toList();
    expect(startYs, orderedEquals(<double>[72, 96, 120]));

    for (final ConductorLaneRole role in plan.laneOrder) {
      final OrthogonalWirePath path = plan.paths[role]!;
      expect(path.points[1].dx, plan.commonBendStationX);
      expect(path.points[path.points.length - 2].dx, plan.commonBendStationX);
    }
  });

  test('AC3 preserves L1 L2 L3 N PE order without crossings', () {
    final ConductorBundlePlan plan = planner.planAc3(
      start: const Offset(48, 72),
      end: const Offset(480, 192),
    );

    expect(
      plan.laneOrder,
      const <ConductorLaneRole>[
        ConductorLaneRole.l1,
        ConductorLaneRole.l2,
        ConductorLaneRole.l3,
        ConductorLaneRole.neutral,
        ConductorLaneRole.protectiveEarth,
      ],
    );

    final List<OrthogonalWirePath> occupied = <OrthogonalWirePath>[];
    for (final ConductorLaneRole role in plan.laneOrder) {
      final OrthogonalWirePath candidate = plan.paths[role]!;
      expect(
        WireRouteSafety.hasDifferentNetCrossing(
          candidate: candidate,
          occupiedDifferentNetPaths: occupied,
        ),
        isFalse,
      );
      occupied.add(candidate);
    }
  });

  test('PV keeps DC positive and negative as an ordered pair', () {
    final ConductorBundlePlan plan = planner.planPvDcPair(
      start: const Offset(48, 96),
      end: const Offset(384, 96),
    );

    expect(
      plan.laneOrder,
      const <ConductorLaneRole>[
        ConductorLaneRole.dcPositive,
        ConductorLaneRole.dcNegative,
      ],
    );
    expect(
      plan.paths[ConductorLaneRole.dcPositive]!.points.first.dy,
      lessThan(plan.paths[ConductorLaneRole.dcNegative]!.points.first.dy),
    );
  });

  test('PV visual zones keep DC and AC on opposite sides of conversion', () {
    const PvVisualZonePlanner zonePlanner = PvVisualZonePlanner(
      minimumZoneWidth: 144,
      zoneGap: 24,
    );

    final PvVisualZonePlan plan = zonePlanner.plan(
      origin: const Offset(48, 48),
      height: 288,
    );

    expect(
      plan.zoneOrder,
      const <PvVisualZone>[
        PvVisualZone.generation,
        PvVisualZone.dcProtection,
        PvVisualZone.regulationStorage,
        PvVisualZone.conversion,
        PvVisualZone.acDistributionLoad,
      ],
    );
    expect(
      plan.bounds[PvVisualZone.regulationStorage]!.right,
      lessThan(plan.bounds[PvVisualZone.conversion]!.left),
    );
    expect(
      plan.bounds[PvVisualZone.conversion]!.right,
      lessThan(plan.bounds[PvVisualZone.acDistributionLoad]!.left),
    );
  });
}
