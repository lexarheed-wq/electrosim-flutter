import 'dart:math' as math;
import 'dart:ui';

/// Pure visual placement helper used by F9 quick-add.
///
/// It has no electrical responsibility: it only chooses a free world-space
/// position so a newly created element does not visually imply a connection by
/// overlapping an existing element or wire.
final class F9AutoPlacement {
  const F9AutoPlacement._();

  static Offset? findPosition({
    required Rect visibleWorldRect,
    required Size elementSize,
    required Iterable<Rect> occupiedElements,
    required Iterable<List<Offset>> occupiedPolylines,
    double clearance = 18,
  }) {
    final double halfWidth = elementSize.width / 2;
    final double halfHeight = elementSize.height / 2;
    final Rect safe = Rect.fromLTRB(
      visibleWorldRect.left + halfWidth + clearance,
      visibleWorldRect.top + halfHeight + clearance,
      visibleWorldRect.right - halfWidth - clearance,
      visibleWorldRect.bottom - halfHeight - clearance,
    );
    if (safe.width <= 0 || safe.height <= 0) {
      return null;
    }

    // Sampling must not scale one-for-one with the component dimensions:
    // large realistic components would otherwise skip viable gaps entirely.
    // Keep a bounded world-space lattice, with a little adaptation for very
    // small items, then rank candidates by distance from the preferred zone.
    final double stepX = math.max(24, math.min(72, elementSize.width / 3));
    final double stepY = math.max(24, math.min(72, elementSize.height / 3));
    final Offset preferred = Offset(
      safe.center.dx,
      (safe.center.dy + math.min(120, stepY * 2))
          .clamp(safe.top, safe.bottom)
          .toDouble(),
    );

    final List<Offset> candidates = <Offset>[preferred, safe.center];
    for (double y = safe.top; y <= safe.bottom + 1e-6; y += stepY) {
      for (double x = safe.left; x <= safe.right + 1e-6; x += stepX) {
        candidates.add(Offset(x, y));
      }
    }
    candidates
      ..add(Offset(safe.left, safe.bottom))
      ..add(Offset(safe.right, safe.bottom))
      ..add(Offset(safe.left, safe.top))
      ..add(Offset(safe.right, safe.top));
    candidates.sort((Offset a, Offset b) {
      final double da = (a - preferred).distanceSquared;
      final double db = (b - preferred).distanceSquared;
      if (da != db) {
        return da.compareTo(db);
      }
      // For equal distance, prefer lower rows, then left-to-right. This keeps
      // quick-added elements away from the demonstration circuit when possible.
      if (a.dy != b.dy) {
        return b.dy.compareTo(a.dy);
      }
      return a.dx.compareTo(b.dx);
    });

    final List<Rect> occupied = occupiedElements.toList(growable: false);
    final List<List<Offset>> polylines = occupiedPolylines.toList(
      growable: false,
    );
    for (final Offset candidate in candidates) {
      final Rect rect = Rect.fromCenter(
        center: candidate,
        width: elementSize.width,
        height: elementSize.height,
      );
      if (_overlapsElement(rect, occupied, clearance)) {
        continue;
      }
      if (_overlapsPolyline(rect, polylines, clearance)) {
        continue;
      }
      return candidate;
    }

    // Never force an ambiguous overlap. The caller can ask the user to drag
    // manually when the visible viewport has no safe automatic slot.
    return null;
  }

  static bool _overlapsElement(
    Rect candidate,
    List<Rect> occupied,
    double clearance,
  ) {
    final Rect padded = candidate.inflate(clearance);
    for (final Rect rect in occupied) {
      if (padded.overlaps(rect.inflate(clearance / 2))) {
        return true;
      }
    }
    return false;
  }

  static bool _overlapsPolyline(
    Rect candidate,
    List<List<Offset>> polylines,
    double clearance,
  ) {
    final Rect padded = candidate.inflate(clearance);
    for (final List<Offset> points in polylines) {
      for (int index = 0; index + 1 < points.length; index += 1) {
        if (_segmentIntersectsRect(points[index], points[index + 1], padded)) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _segmentIntersectsRect(Offset a, Offset b, Rect rect) {
    if (rect.contains(a) || rect.contains(b)) {
      return true;
    }
    final Offset topLeft = rect.topLeft;
    final Offset topRight = rect.topRight;
    final Offset bottomRight = rect.bottomRight;
    final Offset bottomLeft = rect.bottomLeft;
    return _segmentsIntersect(a, b, topLeft, topRight) ||
        _segmentsIntersect(a, b, topRight, bottomRight) ||
        _segmentsIntersect(a, b, bottomRight, bottomLeft) ||
        _segmentsIntersect(a, b, bottomLeft, topLeft);
  }

  static bool _segmentsIntersect(Offset a, Offset b, Offset c, Offset d) {
    const double epsilon = 1e-9;
    double cross(Offset p, Offset q, Offset r) =>
        (q.dx - p.dx) * (r.dy - p.dy) - (q.dy - p.dy) * (r.dx - p.dx);

    bool onSegment(Offset p, Offset q, Offset r) {
      final double minX = p.dx < r.dx ? p.dx : r.dx;
      final double maxX = p.dx > r.dx ? p.dx : r.dx;
      final double minY = p.dy < r.dy ? p.dy : r.dy;
      final double maxY = p.dy > r.dy ? p.dy : r.dy;
      return q.dx >= minX - epsilon &&
          q.dx <= maxX + epsilon &&
          q.dy >= minY - epsilon &&
          q.dy <= maxY + epsilon;
    }

    final double abC = cross(a, b, c);
    final double abD = cross(a, b, d);
    final double cdA = cross(c, d, a);
    final double cdB = cross(c, d, b);

    if (((abC > epsilon && abD < -epsilon) ||
            (abC < -epsilon && abD > epsilon)) &&
        ((cdA > epsilon && cdB < -epsilon) ||
            (cdA < -epsilon && cdB > epsilon))) {
      return true;
    }
    if (abC.abs() <= epsilon && onSegment(a, c, b)) {
      return true;
    }
    if (abD.abs() <= epsilon && onSegment(a, d, b)) {
      return true;
    }
    if (cdA.abs() <= epsilon && onSegment(c, a, d)) {
      return true;
    }
    if (cdB.abs() <= epsilon && onSegment(c, b, d)) {
      return true;
    }
    return false;
  }
}
