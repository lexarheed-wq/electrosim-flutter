import 'package:flutter/painting.dart';

/// Decorative supports for already aligned front-view DIN housings.
/// Does not snap, move or electrically connect devices. Different mounting
/// heights retain independent supports rather than inventing an alignment.
List<Rect> layoutDinRails(List<Rect> mounts) {
  final rows = <double, List<Rect>>{};
  for (final mount in mounts) {
    rows.putIfAbsent(mount.center.dy, () => []).add(mount);
  }
  final result = <Rect>[];
  for (final row in rows.entries) {
    final spans =
        row.value
            .map(
              (r) => Rect.fromLTRB(
                r.left - 48,
                row.key - 27,
                r.right + 48,
                row.key + 27,
              ),
            )
            .toList()
          ..sort((a, b) => a.left.compareTo(b.left));
    Rect? current;
    for (final span in spans) {
      if (current == null) {
        current = span;
      } else if (span.left <= current.right) {
        current = current.expandToInclude(span);
      } else {
        result.add(current);
        current = span;
      }
    }
    if (current != null) result.add(current);
  }
  return result;
}

void paintDinRail(Canvas canvas, Rect rect, {required double scale}) {
  final border = Paint()
    ..color = const Color(0xFF7A858C)
    ..style = PaintingStyle.stroke
    ..strokeWidth = .8;
  canvas.drawRect(
    rect.shift(Offset(0, 2 * scale)),
    Paint()..color = const Color(0x24000000),
  );
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFF4F6F7),
          Color(0xFF919BA2),
          Color(0xFFD6DCE0),
          Color(0xFFB7C0C6),
          Color(0xFF747F87),
          Color(0xFFE5E9EC),
        ],
        stops: [0, .12, .22, .76, .9, 1],
      ).createShader(rect),
  );
  canvas.drawRect(rect, border);
  for (final y in [rect.top + 8 * scale, rect.bottom - 8 * scale]) {
    canvas.drawLine(
      Offset(rect.left, y),
      Offset(rect.right, y),
      Paint()
        ..color = const Color(0xFF6E7C86)
        ..strokeWidth = .8,
    );
    canvas.drawLine(
      Offset(rect.left, y + scale),
      Offset(rect.right, y + scale),
      Paint()
        ..color = const Color(0xC0FFFFFF)
        ..strokeWidth = .8,
    );
  }
  if (scale < .5) return;
  for (
    double x = rect.left + 18 * scale;
    x < rect.right - 10 * scale;
    x += 42 * scale
  ) {
    final slot = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(x, rect.center.dy),
        width: 24 * scale,
        height: 6 * scale,
      ),
      Radius.circular(3 * scale),
    );
    canvas.drawRRect(
      slot.shift(Offset(0, scale)),
      Paint()..color = const Color(0xC0FFFFFF),
    );
    canvas.drawRRect(slot, Paint()..color = const Color(0xFF89949C));
    canvas.drawRRect(slot, border);
  }
  for (final x in [rect.left + 9 * scale, rect.right - 9 * scale]) {
    final centre = Offset(x, rect.center.dy);
    final radius = 4.5 * scale;
    canvas.drawCircle(
      centre,
      radius + scale,
      Paint()..color = const Color(0xFF69757E),
    );
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.4, -.4),
          colors: [Color(0xFFF8FAFA), Color(0xFFA0ADB5), Color(0xFF61717D)],
        ).createShader(Rect.fromCircle(center: centre, radius: radius)),
    );
    final screw = Paint()
      ..color = const Color(0xFF354650)
      ..strokeWidth = scale;
    canvas.drawLine(
      centre + Offset(-radius * .6, 0),
      centre + Offset(radius * .6, 0),
      screw,
    );
    canvas.drawLine(
      centre + Offset(0, -radius * .6),
      centre + Offset(0, radius * .6),
      screw,
    );
  }
}
