import 'dart:math' as math;
import 'dart:ui';

/// Display-only smoothing. Saved routes and electrical endpoints are unchanged.
/// A bend never consumes more than half either adjacent segment.
Path buildPhysicalWirePath(List<Offset> points, {double bendRadius = 6}) {
  final clean = <Offset>[];
  for (final point in points) {
    if (clean.isEmpty || clean.last != point) clean.add(point);
  }
  final path = Path();
  if (clean.isEmpty) return path;
  path.moveTo(clean.first.dx, clean.first.dy);
  final radius = bendRadius.isFinite ? math.max(0.0, bendRadius) : 0.0;
  for (var i = 1; i < clean.length - 1; i++) {
    final corner = clean[i];
    final incoming = corner - clean[i - 1];
    final outgoing = clean[i + 1] - corner;
    final a = incoming / incoming.distance;
    final b = outgoing / outgoing.distance;
    final cross = a.dx * b.dy - a.dy * b.dx;
    if (cross.abs() < .000001 || radius == 0) {
      path.lineTo(corner.dx, corner.dy);
      continue;
    }
    final trim = math.min(
      radius,
      math.min(incoming.distance, outgoing.distance) / 2,
    );
    final entry = corner - a * trim;
    final exit = corner + b * trim;
    path.lineTo(entry.dx, entry.dy);
    path.quadraticBezierTo(corner.dx, corner.dy, exit.dx, exit.dy);
  }
  if (clean.length > 1) path.lineTo(clean.last.dx, clean.last.dy);
  return path;
}
