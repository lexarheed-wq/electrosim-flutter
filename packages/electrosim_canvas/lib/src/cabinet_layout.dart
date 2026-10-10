import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'cabinet_physical_model.dart';

/// Cabinet fixtures are geometry only, never electrical components.
/// A rail or duct MUST NOT change CircuitState, TopologyEngine or a solver.
enum CabinetFixtureKind { dinRail, wireDuct, terminalZone }

enum CabinetPlacementMode { free, assistedDin }

@immutable
final class CabinetFixture {
  CabinetFixture({required this.id, required this.kind, required this.bounds}) {
    if (id.trim().isEmpty ||
        !bounds.left.isFinite ||
        !bounds.top.isFinite ||
        !bounds.width.isFinite ||
        !bounds.height.isFinite ||
        bounds.width <= 0 ||
        bounds.height <= 0) {
      throw ArgumentError(
        'Cabinet fixture requires a valid id and finite positive rectangle.',
      );
    }
    if (kind == CabinetFixtureKind.dinRail &&
        (bounds.width < 60 || bounds.height < 16)) {
      throw ArgumentError('DIN rail must be at least 60 x 16 world units.');
    }
    if (kind == CabinetFixtureKind.wireDuct &&
        (bounds.width < 24 || bounds.height < 24)) {
      throw ArgumentError('Wiring duct must be at least 24 x 24 world units.');
    }
  }

  final String id;
  final CabinetFixtureKind kind;
  final Rect bounds;

  CabinetFixture withBounds(Rect next) =>
      CabinetFixture(id: id, kind: kind, bounds: next);
}

@immutable
final class CabinetLayout {
  const CabinetLayout.empty()
    : fixtures = const <CabinetFixture>[],
      envelope = null,
      mounts = const {};

  CabinetLayout(
    Iterable<CabinetFixture> fixtures, {
    this.envelope,
    Map<String, CabinetMount> mounts = const {},
  }) : mounts = Map<String, CabinetMount>.unmodifiable(mounts),
       fixtures = List<CabinetFixture>.unmodifiable(fixtures) {
    final ids = <String>{};
    for (final fixture in this.fixtures) {
      if (!ids.add(fixture.id)) {
        throw ArgumentError('Duplicate cabinet fixture id: ${fixture.id}');
      }
    }
  }

  final List<CabinetFixture> fixtures;
  final CabinetEnvelope? envelope;
  final Map<String, CabinetMount> mounts;
  CabinetLayout withEnvelope(CabinetEnvelope? next) =>
      CabinetLayout(fixtures, envelope: next, mounts: mounts);
  CabinetLayout withMount(String id, CabinetMount mount) => CabinetLayout(
    fixtures,
    envelope: envelope,
    mounts: {...mounts, id: mount},
  );
  CabinetLayout retainMounts(Set<String> ids) => CabinetLayout(
    fixtures,
    envelope: envelope,
    mounts: {
      for (final e in mounts.entries)
        if (ids.contains(e.key)) e.key: e.value,
    },
  );

  CabinetFixture? fixture(String id) {
    for (final fixture in fixtures) {
      if (fixture.id == id) return fixture;
    }
    return null;
  }

  CabinetLayout add(CabinetFixture fixture) {
    if (this.fixture(fixture.id) != null) {
      throw ArgumentError('Cabinet fixture already exists: ${fixture.id}');
    }
    return CabinetLayout(
      [...fixtures, fixture],
      envelope: envelope,
      mounts: mounts,
    );
  }

  CabinetLayout remove(String id) => CabinetLayout(
    fixtures.where((f) => f.id != id),
    envelope: envelope,
    mounts: {
      for (final e in mounts.entries)
        e.key: e.value.railId == id ? e.value.withoutRail() : e.value,
    },
  );

  CabinetLayout move(String id, Offset topLeft) {
    final old = fixture(id);
    if (old == null) throw ArgumentError('Unknown cabinet fixture: $id');
    return replace(old.withBounds(topLeft & old.bounds.size));
  }

  CabinetLayout resize(String id, Size size) {
    final old = fixture(id);
    if (old == null) throw ArgumentError('Unknown cabinet fixture: $id');
    return replace(old.withBounds(old.bounds.topLeft & size));
  }

  CabinetLayout replace(CabinetFixture replacement) {
    if (fixture(replacement.id) == null) {
      throw ArgumentError('Unknown cabinet fixture: ${replacement.id}');
    }
    return CabinetLayout(
      [
        for (final old in fixtures)
          if (old.id == replacement.id) replacement else old,
      ],
      envelope: envelope,
      mounts: {
        for (final e in mounts.entries)
          e.key:
              e.value.railId == replacement.id &&
                  fixture(replacement.id)!.bounds != replacement.bounds
              ? e.value.withoutRail()
              : e.value,
      },
    );
  }
}

@immutable
final class CabinetPlacementResult {
  const CabinetPlacementResult({
    required this.position,
    required this.snapped,
    required this.isValid,
    required this.intersectingIds,
    this.railId,
  });

  final Offset position;
  final bool snapped;
  final bool isValid;
  final List<String> intersectingIds;
  final String? railId;
}

/// Non-destructive placement assistance. Does not add or move any electrical
/// component; the authoring layer must explicitly apply a valid suggestion.
///
/// Geometry is in world coordinates, independent of screen scale and pan.
abstract final class CabinetPlacementPlanner {
  static CabinetPlacementResult plan({
    required CabinetLayout cabinet,
    required String elementId,
    required Size deviceSize,
    required Offset proposedCenter,
    required Map<String, Rect> existingDevices,
    CabinetPlacementMode mode = CabinetPlacementMode.free,
    bool dinMountable = false,
    double snapDistance = 32,
    Offset mountingAnchorOffset = Offset.zero,
    CabinetSurface surface = CabinetSurface.interior,
  }) {
    if (!deviceSize.width.isFinite ||
        !deviceSize.height.isFinite ||
        deviceSize.width <= 0 ||
        deviceSize.height <= 0 ||
        !proposedCenter.dx.isFinite ||
        !proposedCenter.dy.isFinite ||
        !snapDistance.isFinite ||
        snapDistance < 0 ||
        !mountingAnchorOffset.dx.isFinite ||
        !mountingAnchorOffset.dy.isFinite) {
      throw ArgumentError('Invalid device geometry or snap tolerance.');
    }
    Offset center = proposedCenter;
    bool snapped = false;
    String? mountedRailId;
    if (mode == CabinetPlacementMode.assistedDin && dinMountable) {
      double nearest = double.infinity;
      for (final fixture in cabinet.fixtures) {
        if (fixture.kind != CabinetFixtureKind.dinRail ||
            deviceSize.width > fixture.bounds.width) {
          continue;
        }
        final distance =
            (proposedCenter.dy +
                    mountingAnchorOffset.dy -
                    fixture.bounds.center.dy)
                .abs();
        if (distance > snapDistance || distance >= nearest) {
          continue;
        }
        nearest = distance;
        center = Offset(
          center.dx
              .clamp(
                fixture.bounds.left + deviceSize.width / 2,
                fixture.bounds.right - deviceSize.width / 2,
              )
              .toDouble(),
          fixture.bounds.center.dy - mountingAnchorOffset.dy,
        );
        snapped = true;
        mountedRailId = fixture.id;
      }
    }
    final rectangle = Rect.fromCenter(
      center: center,
      width: deviceSize.width,
      height: deviceSize.height,
    );
    final collisions = <String>[];
    if (cabinet.envelope != null &&
        !cabinet.envelope!.contains(rectangle, surface: surface)) {
      collisions.add('cabinet:bounds');
    }
    for (final fixture in cabinet.fixtures) {
      // A DIN rail lies behind the mounted device and is not an obstruction.
      if (surface == CabinetSurface.interior &&
          fixture.kind != CabinetFixtureKind.dinRail &&
          rectangle.overlaps(fixture.bounds)) {
        collisions.add('fixture:${fixture.id}');
      }
    }
    for (final entry in existingDevices.entries) {
      if (entry.key != elementId &&
          (cabinet.mounts[entry.key]?.surface ?? CabinetSurface.interior) ==
              surface &&
          rectangle.overlaps(entry.value)) {
        collisions.add('device:${entry.key}');
      }
    }
    collisions.sort();
    return CabinetPlacementResult(
      position: center,
      snapped: snapped,
      railId: mountedRailId,
      isValid: collisions.isEmpty,
      intersectingIds: List.unmodifiable(collisions),
    );
  }

  /// Finite, bounded world-coordinate clamp for fixtures. Used for moving a
  /// support without moving any wired device or mutating the circuit.
  static Offset boundedTopLeft(
    CabinetFixture fixture,
    Offset proposed,
    Rect workspace,
  ) {
    if (workspace.width < fixture.bounds.width ||
        workspace.height < fixture.bounds.height) {
      throw ArgumentError('Fixture is larger than cabinet workspace.');
    }
    return Offset(
      math.max(
        workspace.left,
        math.min(proposed.dx, workspace.right - fixture.bounds.width),
      ),
      math.max(
        workspace.top,
        math.min(proposed.dy, workspace.bottom - fixture.bounds.height),
      ),
    );
  }
}
