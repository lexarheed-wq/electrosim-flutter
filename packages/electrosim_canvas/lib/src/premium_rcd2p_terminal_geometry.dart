import 'dart:math' as math;
import 'dart:ui';

/// Read-only mirror of Disjoncteur3D's FRONTAL optical projection.
///
/// The Canvas package cannot depend on the Flutter app painter. This small
/// contract reproduces only its 0°/0° camera, the immutable bounding points
/// and the four screw centers. Palette projection is owned by the painter.
abstract final class PremiumRcd2pTerminalGeometry {
  static const Size designSize = Size(160, 260);

  static List<Offset> offsets(Size size) {
    Offset raw(double x, double y, double z) {
      final double k = 500 / (500 - z);
      return Offset(x * k, y * k);
    }

    final bounds = <Offset>[
      for (final x in [-18.5, 18.5])
        for (final y in [-43.0, 43.0])
          for (final z in [-34.0, 36.0]) raw(x, y, z),
      for (final x in [-17.0, 17.0])
        for (final y in [4.0, 33.0]) raw(x, y, 55.0),
      raw(-15, -46, -28),
      raw(0, -46, -10),
    ];
    final minX = bounds.map((p) => p.dx).reduce(math.min);
    final maxX = bounds.map((p) => p.dx).reduce(math.max);
    final minY = bounds.map((p) => p.dy).reduce(math.min);
    final maxY = bounds.map((p) => p.dy).reduce(math.max);
    final scale = math.max(
      .001,
      math.min(
        math.max(1.0, size.width - 16) / (maxX - minX),
        math.max(1.0, size.height - 16) / (maxY - minY),
      ),
    );
    final origin = Offset(
      (size.width - (maxX - minX) * scale) / 2 - minX * scale,
      (size.height - (maxY - minY) * scale) / 2 - minY * scale,
    );
    Offset project(double x, double y) =>
        origin + raw(x, y, 36.6) * scale - Offset(size.width/2, size.height/2);
    // Index order is the canonical electrical order:
    // N input, L input, N output, L output.
    return <Offset>[
      project(-8.3, -31.5),
      project(8.3, -31.5),
      project(-8.3, 35.0),
      project(8.3, 35.0),
    ];
  }
}
