import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';

enum EtatDisjoncteur { ouvert, ferme, declenche }

enum VueDisjoncteur {
  palette(-14.0, -12.0),
  platine(0.0, 0.0);

  const VueDisjoncteur(this.angleHorizontal, this.angleVertical);
  final double angleHorizontal;
  final double angleVertical;
}

enum BorneDisjoncteur { neutreEntree, phaseEntree, neutreSortie, phaseSortie }

class Disjoncteur3D extends StatefulWidget {
  const Disjoncteur3D({
    super.key,
    this.width = 280,
    this.height = 480,
    this.etat = EtatDisjoncteur.ouvert,
    this.vue = VueDisjoncteur.platine,
    this.calibreA,
    this.sensibiliteMA,
    this.estDifferentiel = true,
    this.afficherBornes = false,
    this.onCommande,
    this.onTest,
    this.onBorne,
    this.marque,
    this.gamme,
    this.reference,
  }) : assert(width > 0),
       assert(height > 0),
       assert(calibreA == null || calibreA > 0),
       assert(sensibiliteMA == null || sensibiliteMA > 0);
  final double width;
  final double height;
  final EtatDisjoncteur etat;
  final VueDisjoncteur vue;
  final double? calibreA;
  final double? sensibiliteMA;
  final bool estDifferentiel;
  final bool afficherBornes;
  final ValueChanged<EtatDisjoncteur>? onCommande;
  final VoidCallback? onTest;
  final ValueChanged<BorneDisjoncteur>? onBorne;
  final String? marque;
  final String? gamme;
  final String? reference;
  static bool hitsLever(Size size, Offset point) {
    return _Projection(size, 0, 0).rect(-17, 5, 34, 30, 51).contains(point);
  }

  static bool hitsTestButton(Size size, Offset point) {
    return _Projection(size, 0, 0).rect(5.5, -14.5, 10, 8, 41).contains(point);
  }

  static Map<BorneDisjoncteur, Offset> positionsBornes(
    Size size, {
    VueDisjoncteur vue = VueDisjoncteur.platine,
  }) {
    assert(size.width > 0 && size.height > 0);
    final projection = _Projection(
      size,
      vue.angleHorizontal,
      vue.angleVertical,
    );
    return Map<BorneDisjoncteur, Offset>.unmodifiable({
      for (final entry in _bornes.entries)
        entry.key: projection.project(entry.value),
    });
  }

  @override
  State<Disjoncteur3D> createState() => _Disjoncteur3DState();
}

class _Disjoncteur3DState extends State<Disjoncteur3D>
    with SingleTickerProviderStateMixin {
  late final AnimationController _levier = AnimationController(
    vsync: this,
    value: _position,
    duration: const Duration(milliseconds: 170),
  );
  bool _testEnfonce = false;
  bool _focus = false;
  Offset? _doubleTapPosition;
  double get _position => switch (widget.etat) {
    EtatDisjoncteur.ouvert => 0.0,
    EtatDisjoncteur.ferme => 1.0,
    EtatDisjoncteur.declenche => 0.48,
  };
  bool get _testDisponible => widget.estDifferentiel && widget.onTest != null;
  void _commande() {
    final commande = widget.onCommande;
    if (commande == null) return;
    final prochain = widget.etat == EtatDisjoncteur.ouvert
        ? EtatDisjoncteur.ferme
        : EtatDisjoncteur.ouvert;
    commande(prochain);
  }

  @override
  void didUpdateWidget(covariant Disjoncteur3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.etat != widget.etat) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _levier.value = _position;
      } else {
        _levier.animateTo(_position, curve: Curves.easeOutCubic);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _levier.value = _position;
  }

  @override
  void dispose() {
    _levier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final projection = _Projection(
            size,
            widget.vue.angleHorizontal,
            widget.vue.angleVertical,
          );
          final testArea = projection.rect(5.5, -14.5, 10, 8, 41);
          final leverArea = projection.rect(-17, 5, 34, 30, 51);
          final bornes = Disjoncteur3D.positionsBornes(size, vue: widget.vue);
          final rayon = math.max(9.0, math.min(20.0, projection.scale * 3.5));
          void tapSimple(Offset point) {
            for (final entry in bornes.entries) {
              if ((point - entry.value).distance <= rayon) {
                widget.onBorne?.call(entry.key);
                return;
              }
            }
            if (_testDisponible && testArea.contains(point)) {
              widget.onTest!.call();
            }
          }

          return Focus(
            onFocusChange: (focused) {
              if (mounted) setState(() => _focus = focused);
            },
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if ((event.logicalKey == LogicalKeyboardKey.enter ||
                      event.logicalKey == LogicalKeyboardKey.space) &&
                  widget.onCommande != null) {
                _commande();
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.keyT &&
                  _testDisponible) {
                widget.onTest!.call();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                if (_testDisponible &&
                    testArea.contains(details.localPosition)) {
                  setState(() => _testEnfonce = true);
                }
              },
              onTapCancel: () {
                if (_testEnfonce) setState(() => _testEnfonce = false);
              },
              onTapUp: (details) {
                if (_testEnfonce) setState(() => _testEnfonce = false);
                tapSimple(details.localPosition);
              },
              onDoubleTapDown: (details) {
                _doubleTapPosition = details.localPosition;
              },
              onDoubleTap: () {
                final point = _doubleTapPosition;
                _doubleTapPosition = null;
                if (point != null && leverArea.contains(point)) _commande();
              },
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _levier,
                  builder: (context, _) => CustomPaint(
                    painter: _DisjoncteurPainter(
                      widget: widget,
                      position: _levier.value,
                      testEnfonce: _testEnfonce,
                      focus: _focus,
                      onCommande: widget.onCommande == null ? null : _commande,
                      onTest: _testDisponible ? widget.onTest : null,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

const Map<BorneDisjoncteur, _V> _bornes = {
  BorneDisjoncteur.neutreEntree: _V(-8.3, -31.5, 36.6),
  BorneDisjoncteur.phaseEntree: _V(8.3, -31.5, 36.6),
  BorneDisjoncteur.neutreSortie: _V(-8.3, 35, 36.6),
  BorneDisjoncteur.phaseSortie: _V(8.3, 35, 36.6),
};

class _V {
  const _V(this.x, this.y, this.z);
  final double x, y, z;
  _V operator +(_V b) => _V(x + b.x, y + b.y, z + b.z);
  _V operator -(_V b) => _V(x - b.x, y - b.y, z - b.z);
  _V operator *(double s) => _V(x * s, y * s, z * s);
  double dot(_V b) => x * b.x + y * b.y + z * b.z;
  _V cross(_V b) => _V(y * b.z - z * b.y, z * b.x - x * b.z, x * b.y - y * b.x);
  _V get unit {
    final n = math.sqrt(dot(this));
    return n < 1e-9 ? const _V(0, 0, 1) : this * (1 / n);
  }
}

class _Projection {
  _Projection(this.size, double yaw, double pitch)
    : cy = math.cos(yaw * math.pi / 180),
      sy = math.sin(yaw * math.pi / 180),
      cp = math.cos(pitch * math.pi / 180),
      sp = math.sin(pitch * math.pi / 180) {
    final bounds = <Offset>[
      for (final x in [-18.5, 18.5])
        for (final y in [-43.0, 43.0])
          for (final z in [-34.0, 56.0]) raw(_V(x, y, z)),
      raw(const _V(-15, -46, -28)),
      raw(const _V(0, -46, -10)),
    ];
    final minX = bounds.map((p) => p.dx).reduce(math.min);
    final maxX = bounds.map((p) => p.dx).reduce(math.max);
    final minY = bounds.map((p) => p.dy).reduce(math.min);
    final maxY = bounds.map((p) => p.dy).reduce(math.max);
    scale = math.max(
      .001,
      math.min(
        math.max(1, size.width - 16) / (maxX - minX),
        math.max(1, size.height - 16) / (maxY - minY),
      ),
    );
    origin = Offset(
      (size.width - (maxX - minX) * scale) / 2 - minX * scale,
      (size.height - (maxY - minY) * scale) / 2 - minY * scale,
    );
  }
  final Size size;
  final double cy, sy, cp, sp;
  late final double scale;
  late final Offset origin;
  _V view(_V p) {
    final x = p.x * cy + p.z * sy;
    final z = -p.x * sy + p.z * cy;
    return _V(x, p.y * cp - z * sp, p.y * sp + z * cp);
  }

  Offset raw(_V p) {
    final v = view(p);
    final k = 500 / (500 - v.z);
    return Offset(v.x * k, v.y * k);
  }

  Offset project(_V p) => origin + raw(p) * scale;
  Path polygon(List<_V> points) {
    final path = Path();
    final first = project(points.first);
    path.moveTo(first.dx, first.dy);
    for (final v in points.skip(1)) {
      final q = project(v);
      path.lineTo(q.dx, q.dy);
    }
    return path..close();
  }

  Path rect(double x, double y, double w, double h, double z) => polygon([
    _V(x, y, z),
    _V(x + w, y, z),
    _V(x + w, y + h, z),
    _V(x, y + h, z),
  ]);
}

class _Face {
  const _Face(this.points, this.color);
  final List<_V> points;
  final Color color;
  _V get normal => (points[1] - points[0]).cross(points[2] - points[0]).unit;
  _V get center => points.reduce((a, b) => a + b) * (1 / points.length);
}

class _Scene {
  const _Scene(this.canvas, this.p);
  final Canvas canvas;
  final _Projection p;
  static const blanc = Color(0xFFFAFBF7);
  static const graphite = Color(0xFF25292D);
  static const accent = Color(0xFF098D43);
  Color shade(Color c, double factor) => Color.fromARGB(
    255,
    (c.r * 255 * factor).round().clamp(0, 255).toInt(),
    (c.g * 255 * factor).round().clamp(0, 255).toInt(),
    (c.b * 255 * factor).round().clamp(0, 255).toInt(),
  );
  void faces(List<_Face> mesh) {
    mesh.sort((a, b) => p.view(a.center).z.compareTo(p.view(b.center).z));
    for (final face in mesh) {
      if (p.view(face.normal).z <= 0) continue;
      final shape = p.polygon(face.points);
      final light =
          .76 + .24 * math.max(0, face.normal.dot(const _V(-.65, -.8, 1).unit));
      final bounds = shape.getBounds();
      if (bounds.isEmpty) continue;
      canvas.drawPath(
        shape,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              shade(face.color, light + .035),
              shade(face.color, light - .035),
            ],
          ).createShader(bounds),
      );
      canvas.drawPath(
        shape,
        Paint()
          ..color = shade(face.color, light - .01)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .3,
      );
    }
  }

  List<_V> outline(
    double x,
    double y,
    double w,
    double h,
    double z,
    double radius,
  ) {
    final r = math.max(.001, math.min(radius, math.min(w, h) / 2));
    final corners = [
      (x - w / 2 + r, y - h / 2 + r, math.pi),
      (x + w / 2 - r, y - h / 2 + r, -math.pi / 2),
      (x + w / 2 - r, y + h / 2 - r, 0.0),
      (x - w / 2 + r, y + h / 2 - r, math.pi / 2),
    ];
    return [
      for (final corner in corners)
        for (var i = 0; i <= 8; i++)
          _V(
            corner.$1 + r * math.cos(corner.$3 + i * math.pi / 16),
            corner.$2 + r * math.sin(corner.$3 + i * math.pi / 16),
            z,
          ),
    ];
  }

  void box(
    double x,
    double y,
    double w,
    double h,
    double front,
    double depth,
    Color color, {
    double radius = .4,
    double bevel = .22,
    _V Function(_V)? transform,
  }) {
    final back = outline(x, y, w, h, front - depth, radius);
    final rim = outline(x, y, w, h, front - bevel, radius);
    final face = outline(
      x,
      y,
      w - 2 * bevel,
      h - 2 * bevel,
      front,
      math.max(.05, radius - bevel),
    );
    _V map(_V v) => transform == null ? v : transform(v);
    final mesh = <_Face>[_Face(face.map(map).toList(), color)];
    for (var i = 0; i < back.length; i++) {
      final j = (i + 1) % back.length;
      mesh.add(
        _Face([back[i], back[j], rim[j], rim[i]].map(map).toList(), color),
      );
      mesh.add(
        _Face([rim[i], rim[j], face[j], face[i]].map(map).toList(), color),
      );
    }
    faces(mesh);
  }

  void disc(_V center, double radius, List<Color> colors, {bool side = false}) {
    final points = [
      for (var i = 0; i < 64; i++)
        side
            ? _V(
                center.x,
                center.y + radius * math.cos(i * math.pi / 32),
                center.z + radius * math.sin(i * math.pi / 32),
              )
            : _V(
                center.x + radius * math.cos(i * math.pi / 32),
                center.y + radius * math.sin(i * math.pi / 32),
                center.z,
              ),
    ];
    final path = p.polygon(points);
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.45, -.6),
          radius: 1.2,
          colors: colors,
        ).createShader(path.getBounds()),
    );
  }

  void line(_V a, _V b, Color color, double width) {
    canvas.drawLine(
      p.project(a),
      p.project(b),
      Paint()
        ..color = color
        ..strokeWidth = math.max(.3, width * p.scale)
        ..strokeCap = StrokeCap.round,
    );
  }

  void text(
    String value,
    double x,
    double y,
    double z,
    double height, {
    Color color = const Color(0xFF34403B),
    FontWeight weight = FontWeight.w500,
    bool center = false,
  }) {
    if (value.isEmpty) return;
    final a = p.project(_V(x, y, z));
    final b = p.project(_V(x + 1, y, z));
    final c = p.project(_V(x, y + 1, z));
    canvas.save();
    canvas.translate(a.dx, a.dy);
    canvas.transform(
      Float64List.fromList([
        b.dx - a.dx,
        b.dy - a.dy,
        0,
        0,
        c.dx - a.dx,
        c.dy - a.dy,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        1,
      ]),
    );
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: height,
          fontWeight: weight,
          color: color,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    painter.paint(
      canvas,
      Offset(center ? -painter.width / 2 : 0, -painter.height / 2),
    );
    canvas.restore();
  }

  void screw(_V at) {
    // Nested rings: white countersink, deep graphite well, dark steel
    // crosshead. Dark cores retain contrast at compact palette scales.
    disc(_V(at.x, at.y, at.z - 1.3), 4.7, [
      const Color(0xFFF9F9F7), const Color(0xFFA8ACAE),
      const Color(0xFF5E666B),
    ]);
    disc(_V(at.x, at.y, at.z - .5), 3.75, [
      const Color(0xFF060708), const Color(0xFF292D30),
    ]);
    disc(_V(at.x, at.y, at.z - .1), 2.78, [
      const Color(0xFF333B40), const Color(0xFF090C10),
      const Color(0xFF555B60),
    ]);
    final crossAngle = at.y < 0 ? math.pi / 4 : -math.pi / 4;
    for (final extra in [0.0, math.pi / 2]) {
      final theta = crossAngle + extra;
      final dx = math.cos(theta) * 2.15;
      final dy = math.sin(theta) * 2.15;
      line(_V(at.x - dx, at.y - dy, at.z + .15),
          _V(at.x + dx, at.y + dy, at.z + .15),
          const Color(0xFFB8BCC0), .65);
      line(_V(at.x - dx * .7, at.y - dy * .7, at.z + .19),
          _V(at.x + dx * .7, at.y + dy * .7, at.z + .19),
          const Color(0xFF252C32), .24);
    }
  }
}

class _DisjoncteurPainter extends CustomPainter {
  const _DisjoncteurPainter({
    required this.widget,
    required this.position,
    required this.testEnfonce,
    required this.focus,
    this.onCommande,
    this.onTest,
  });
  final Disjoncteur3D widget;
  final double position;
  final bool testEnfonce;
  final bool focus;
  final VoidCallback? onCommande;
  final VoidCallback? onTest;
  static String _nombre(double? n) {
    if (n == null || !n.isFinite) return '';
    return n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(1);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final p = _Projection(
      size,
      widget.vue.angleHorizontal,
      widget.vue.angleVertical,
    );
    final scene = _Scene(canvas, p);
    final shadow = p.polygon([
      const _V(-18, -42.5, -34),
      const _V(18, -42.5, 35),
      const _V(18, 42.5, 35),
      const _V(-18, 42.5, 35),
      const _V(-18, 42.5, -34),
    ]);
    canvas.drawPath(
      shadow.shift(const Offset(5, 8)),
      Paint()
        ..color = const Color(0x24000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    const verrou = Color(0xFFE4C231);
    // Yellow U-shaped top release tabs: both uprights and bridging lip.
    for (final x in [-8.3, 8.3]) {
      scene.box(x - 2.75, -44.7, 1.65, 4.4, 20.5, 4.2,
          verrou, radius: .48, bevel: .28);
      scene.box(x + 2.75, -44.7, 1.65, 4.4, 20.5, 4.2,
          verrou, radius: .48, bevel: .28);
      scene.box(x, -46.85, 7.1, 1.65, 21.5, 3.3,
          const Color(0xFFFFD51B), radius: .65, bevel: .28);
    }
    scene.box(-12, 43.5, 7, 2.2, -22, 9, verrou);
    scene.box(0, 0, 36, 85, 34, 68, _Scene.blanc, radius: 1, bevel: .65);
    // Right side shell relief is drawn on the side plane with real occlusion:
    // panel seams, mounting sockets and stepped injection-moulded shoulders.
    // None of this touches front-face hit regions or electrical geometry.
    final sidePlates = <_Face>[
      const _Face([
        _V(18.25, -34, -27), _V(18.25, -1, -27),
        _V(18.25, -1, 3), _V(18.25, -34, 3),
      ], Color(0xFFF2F3F0)),
      const _Face([
        _V(18.26, 1, -26), _V(18.26, 31, -26),
        _V(18.26, 31, -1), _V(18.26, 1, -1),
      ], Color(0xFFE3E5E2)),
      const _Face([
        _V(18.27, 10, 2), _V(18.27, 22, 2),
        _V(18.27, 22, 24), _V(18.27, 10, 24),
      ], Color(0xFFE8EAE7)),
    ];
    scene.faces(sidePlates);
    // Mechanical slots and mould separation lines are drawn on the visible
    // right flank, without changing the canonical frontal terminal offsets.
    for (final y in [-30.0, -16.0, 3.0, 29.0]) {
      scene.disc(_V(18.12, y, -9.0), 1.9, [
        const Color(0xFF50575A), const Color(0xFFBDC3C3),
        const Color(0xFFE8E9E6),
      ], side: true);
    }
    scene.line(const _V(18.14, -30, -28),
        const _V(18.14, 34, -28), const Color(0xFF9EA4A2), .12);
    scene.line(const _V(18.14, 17, -26),
        const _V(18.14, 17, 10), const Color(0xFFACB1AE), .14);
    for (final y in [-32.0, -20.0, -5.0, 10.0, 25.0, 36.0]) {
      scene.disc(_V(-18.06, y, -16), 1.55, [
        const Color(0xFF929E97),
        const Color(0xFFE0E7E0),
      ], side: true);
    }
    scene.box(0, -30, 35.5, 24, 35.2, 3, _Scene.blanc, radius: 1.35, bevel: .7);
    // Upper terminal housing extends beyond the printed facade and leaves
    // a lower moulding step just above the label face.
    scene.box(0, -18.4, 35.7, 1.1, 36.5, 1.2,
        const Color(0xFFE1E5E1), radius: .25, bevel: .18);
    // Front-visible yellow release catches in both camera projections.
    for (final x in [-8.3, 8.3]) {
      scene.box(x, -43.2, 3.4, 2.7, 35.5, 2.1,
          const Color(0xFFF0C31A), radius: .5, bevel: .28);
    }
    scene.box(0, 34.8, 35.5, 14, 35.2, 3, _Scene.blanc, radius: 1.15, bevel: .55);
    scene.box(0, 42.05, 35.4, .85, 35.5, 1,
        const Color(0xFFD7DBD7), radius: .2, bevel: .12);
    for (final x in [-8.3, 8.3]) {
      scene.box(x, -41.3, 10, 2.2, 26, 9, const Color(0xFFC4CAC4), radius: .5);
      scene.box(
        x,
        -41.3,
        7.6,
        1.3,
        26.2,
        1,
        const Color(0xFF9DA7A1),
        radius: .35,
      );
    }
    for (final x in [-8.3, 8.3]) {
      final rim = p.polygon([
        _V(x - 4.5, -42.65, 4),
        _V(x + 4.5, -42.65, 4),
        _V(x + 4.5, -42.65, 21),
        _V(x - 4.5, -42.65, 21),
      ]);
      final hole = p.polygon([
        _V(x - 3.4, -42.68, 6),
        _V(x + 3.4, -42.68, 6),
        _V(x + 3.4, -42.68, 19),
        _V(x - 3.4, -42.68, 19),
      ]);
      canvas.drawPath(rim, Paint()..color = const Color(0xFFC9D1CA));
      canvas.drawPath(
        hole,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF86968B), Color(0xFFD8DFD6)],
          ).createShader(hole.getBounds()),
      );
    }
    for (final borne in _bornes.values) {
      scene.screw(borne);
    }
    scene.text('N', -13.2, -37.2, 35.5, 2.8, weight: FontWeight.w700);
    scene.text('N', -13.2, 40.4, 35.5, 2.8, weight: FontWeight.w700);
    scene.text('1', 9, -37.2, 35.5, 2.5);
    scene.text('2', 9, 40.4, 35.5, 2.5);
    scene.box(0, -6, 35, 28, 40, 6, _Scene.blanc, radius: 1.25, bevel: .65);
    scene.box(0, -19.3, 35.4, 1.5, 39.6, 3.4,
        const Color(0xFFF0F2EE), radius: .45, bevel: .24);
    scene.box(
      0,
      -15,
      32.8,
      1.3,
      40.2,
      .15,
      _Scene.accent,
      radius: .05,
      bevel: .02,
    );
    scene.text(
      'PROTECTION',
      -14,
      -11.7,
      40.4,
      2.75,
      color: const Color(0xFF252D36),
      weight: FontWeight.w800,
    );
    scene.text(
      widget.estDifferentiel ? 'DIFFÉRENTIELLE' : 'MAGNÉTOTHERMIQUE',
      -14,
      -8.2,
      40.4,
      2.15,
      weight: FontWeight.w700,
    );
    scene.text('Type : 2P', -14, -4.6, 40.4, 2.35, weight: FontWeight.w600);
    if (widget.calibreA != null) {
      scene.text(
        'Calibre : ${_nombre(widget.calibreA)} A',
        -14,
        -.4,
        40.4,
        2.45,
        weight: FontWeight.w700,
      );
    }
    if (widget.estDifferentiel && widget.sensibiliteMA != null) {
      scene.text('Sensibilité : ${_nombre(widget.sensibiliteMA)} mA',
          -14, 3.0, 40.4, 1.95);
    }
    if (widget.estDifferentiel) {
      // Tiny differential symbol belongs on the rigid face, not an overlay.
      // Simplified paired poles and test circuit on the right of text.
      for (final dx in [8.0, 12.0]) {
        scene.line(_V(dx, -.3, 40.65), _V(dx, 6.6, 40.65),
            const Color(0xFF2D3339), .18);
        scene.disc(_V(dx, 6.6, 40.7), .22,
            [const Color(0xFF202831), const Color(0xFF202831)]);
      }
      scene.line(const _V(7.3, 2.7, 40.69),
          const _V(12.8, 3.9, 40.69),
          const Color(0xFF2D3339), .2);
      scene.line(const _V(8, 5.25, 40.69),
          const _V(12, 5.25, 40.69),
          const Color(0xFF2D3339), .16);
      scene.box(
        10.5,
        -10.6,
        9.8,
        6.4,
        40.7,
        1,
        const Color(0xFF555B61),
        radius: .35,
      );
      scene.box(
        10.5,
        -10.6,
        8.3,
        4.9,
        testEnfonce ? 40.8 : 41.5,
        .9,
        const Color(0xFF9BA0A6),
        radius: .25,
      );
      scene.text(
        'T',
        10.5,
        -10.6,
        testEnfonce ? 40.85 : 41.55,
        3,
        color: _Scene.graphite,
        weight: FontWeight.w700,
        center: true,
      );
      scene.text('Test', 7.8, -5.3, 40.55, 1.8,
          color: _Scene.graphite, weight: FontWeight.w500);
    }
    scene.line(
      const _V(-16, 7.1, 40.1),
      const _V(16, 7.1, 40.1),
      const Color(0xFFB3BFB8),
      .16,
    );
    for (final x in [-8.3, 8.3]) {
      scene.box(
        x,
        6.5,
        9.5,
        2.4,
        40.4,
        .6,
        const Color(0xFFD8E0D9),
        radius: .2,
      );
      scene.box(
        x,
        6.5,
        5.3,
        1,
        40.6,
        .2,
        const Color(0xFF6A7970),
        radius: .06,
        bevel: .02,
      );
      scene.box(
        x,
        19.3,
        14.7,
        23.5,
        40.8,
        2.5,
        _Scene.blanc,
        radius: 6.2,
        bevel: .6,
      );
      scene.box(
        x,
        19.1,
        10.5,
        18.8,
        41,
        1,
        const Color(0xFFC2CEC6),
        radius: 4.1,
        bevel: .3,
      );
    }
    final angle = (position * 64 - 32) * math.pi / 180;
    _V rotate(_V point) {
      final y = point.y - 18;
      final z = point.z - 42;
      return _V(
        point.x,
        18 + y * math.cos(angle) - z * math.sin(angle),
        42 + y * math.sin(angle) + z * math.cos(angle),
      );
    }

    // Independent matte-black rockers linked by one mechanical bridge.
    for (final x in [-8.3, 8.3]) {
      scene.box(x, 19.8, 10.8, 17.8, 46.6, 5.2,
          const Color(0xFF1C2125), radius: 2.25, bevel: .75,
          transform: rotate);
      scene.box(x, 14.5, 9.3, 5.4, 48.25, .9,
          widget.etat == EtatDisjoncteur.declenche
              ? const Color(0xFFC08A25)
              : widget.etat == EtatDisjoncteur.ferme
                  ? const Color(0xFFBA3F37)
                  : const Color(0xFF08A15A),
          radius: .4, bevel: .2, transform: rotate);
      scene.line(rotate(_V(x - 3.7, 21.8, 47.0)),
          rotate(_V(x + 3.7, 21.8, 47.0)),
          const Color(0xFF343C40), .28);
      scene.line(rotate(_V(x - 3.7, 24.2, 47.0)),
          rotate(_V(x + 3.7, 24.2, 47.0)),
          const Color(0xFF343C40), .22);
      scene.text(
        widget.etat == EtatDisjoncteur.ferme ? 'I · ON'
            : widget.etat == EtatDisjoncteur.declenche ? 'TRIP' : 'O · OFF',
        x - 4.0, 14.5, 49.0, 1.55,
        color: const Color(0xFFF8FCF8), weight: FontWeight.w700);
    }
    final voyant = switch (widget.etat) {
      EtatDisjoncteur.declenche => const Color(0xFFE2A642),
      EtatDisjoncteur.ferme => const Color(0xFFC63B36),
      EtatDisjoncteur.ouvert => const Color(0xFF2C9465),
    };
    scene.box(
      -8.3,
      12.9,
      8.1,
      1.8,
      45.95,
      .2,
      voyant,
      radius: .08,
      bevel: .03,
      transform: rotate,
    );
    scene.box(
      0,
      26.1,
      30.2,
      2.5,
      48.4,
      2.3,
      const Color(0xFF454A4F),
      radius: .35,
      transform: rotate,
    );
    scene.box(
      0,
      26,
      30,
      6.3,
      50,
      4.8,
      _Scene.graphite,
      radius: .65,
      bevel: .35,
      transform: rotate,
    );
    for (final y in [24.3, 25.1, 25.9, 26.7, 27.5]) {
      scene.line(
        rotate(_V(-14.0, y, 50.06)),
        rotate(_V(14.0, y, 50.06)),
        const Color(0xFF4C5550),
        .12,
      );
    }
    scene.box(0, 31, 15, 1.7, 39.4, .6, const Color(0xFFC7D0C8), radius: .2);
    if (widget.afficherBornes) {
      for (final b in _bornes.values) {
        canvas.drawCircle(
          p.project(b),
          math.max(2.0, p.scale * 4.1),
          Paint()
            ..color = const Color(0xAA1385A1)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
    }
    if (focus) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(9)),
        Paint()
          ..color = const Color(0xFF147A9F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DisjoncteurPainter old) =>
      old.position != position ||
      old.testEnfonce != testEnfonce ||
      old.focus != focus ||
      old.widget.vue != widget.vue ||
      old.widget.etat != widget.etat ||
      old.widget.calibreA != widget.calibreA ||
      old.widget.sensibiliteMA != widget.sensibiliteMA ||
      old.widget.estDifferentiel != widget.estDifferentiel ||
      old.widget.afficherBornes != widget.afficherBornes;
  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) {
    final p = _Projection(
      size,
      widget.vue.angleHorizontal,
      widget.vue.angleVertical,
    );
    Rect bounds(Path path) =>
        path.getBounds().inflate(3).intersect(Offset.zero & size);
    return [
      CustomPainterSemantics(
        rect: bounds(p.rect(-17, 5, 34, 30, 51)),
        properties: SemanticsProperties(
          textDirection: TextDirection.ltr,
          button: onCommande != null,
          enabled: onCommande != null,
          label: 'Disjoncteur ${widget.etat.name}',
          onTap: onCommande,
        ),
      ),
      if (widget.estDifferentiel)
        CustomPainterSemantics(
          rect: bounds(p.rect(5.5, -14.5, 10, 8, 41)),
          properties: SemanticsProperties(
            textDirection: TextDirection.ltr,
            button: onTest != null,
            enabled: onTest != null,
            label: 'Test différentiel',
            onTap: onTest,
          ),
        ),
      if (widget.onBorne != null)
        for (final entry in _bornes.entries)
          CustomPainterSemantics(
            rect: Rect.fromCircle(
              center: p.project(entry.value),
              radius: math.max(9.0, p.scale * 3.5),
            ).intersect(Offset.zero & size),
            properties: SemanticsProperties(
              textDirection: TextDirection.ltr,
              button: true,
              label: switch (entry.key) {
                BorneDisjoncteur.neutreEntree => 'Borne N entrée',
                BorneDisjoncteur.phaseEntree => 'Borne phase entrée',
                BorneDisjoncteur.neutreSortie => 'Borne N sortie',
                BorneDisjoncteur.phaseSortie => 'Borne phase sortie',
              },
              onTap: () => widget.onBorne!.call(entry.key),
            ),
          ),
    ];
  };
  @override
  bool shouldRebuildSemantics(covariant _DisjoncteurPainter old) =>
      old.widget.onCommande != widget.onCommande ||
      old.widget.onTest != widget.onTest ||
      old.widget.onBorne != widget.onBorne ||
      old.widget.etat != widget.etat ||
      old.widget.estDifferentiel != widget.estDifferentiel ||
      old.widget.vue != widget.vue;
}
