import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';

part 'rcd2p_industrial_geometry.dart';

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
  /// Optional warm-up for deterministic capture or the project-loading screen.
  /// Both shared physical plates decode once. Missing assets retain the native
  /// mesh renderer, including all controls, states and electrical anchors.
  static Future<bool> prechargerTextures() => _physicalHousing.load();

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
  void initState() {
    super.initState();
    unawaited(_physicalHousing.load());
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
  void reassemble() {
    _housingCache.clear();
    super.reassemble();
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
  _V get normal {
    // Sum oriented triangle areas. A concave contour's first corner may
    // point inward, so the first three vertices alone cannot define culling.
    var normal = const _V(0, 0, 0);
    for (var i = 1; i < points.length - 1; i++) {
      normal =
          normal + (points[i] - points[0]).cross(points[i + 1] - points[0]);
    }
    return normal.unit;
  }

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
      final material = _Rcd2pMaterials.forColor(face.color);
      final light = _Rcd2pLightRig.brightness(face.normal, material);
      final bounds = shape.getBounds();
      if (bounds.isEmpty) continue;
      final microFace =
          bounds.width < p.scale * 4 || bounds.height < p.scale * 4;
      final surface = Paint()..color = shade(face.color, light);
      if (!microFace) {
        surface.shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            shade(face.color, light + .055),
            shade(face.color, light + .01),
            shade(face.color, light - .045),
          ],
          stops: const [0, .45, 1],
        ).createShader(bounds);
      }
      canvas.drawPath(shape, surface);
      // Identical surface finish at the shared edges avoids bright "beads"
      // around each tiny chamfer segment.
      canvas.drawPath(
        shape,
        surface
          ..style = PaintingStyle.stroke
          ..strokeWidth = .25,
      );
      if (!microFace &&
          face.color.r > .85 &&
          face.color.g > .85 &&
          bounds.width > p.scale * 12 &&
          bounds.height > p.scale * 12 &&
          p.scale > 2) {
        canvas.save();
        canvas.clipPath(shape);
        final grain = Paint()..color = const Color(0x07192315);
        for (var i = 0; i < 72; i++) {
          final point = Offset(
            bounds.left + ((i * 137 + 31) % 997) / 997 * bounds.width,
            bounds.top + ((i * 307 + 67) % 991) / 991 * bounds.height,
          );
          canvas.drawCircle(point, p.scale * .055, grain);
        }
        canvas.restore();
      }
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
        for (var i = 0; i <= 16; i++)
          _V(
            corner.$1 + r * math.cos(corner.$3 + i * math.pi / 32),
            corner.$2 + r * math.sin(corner.$3 + i * math.pi / 32),
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
    double? maxWidth,
    _V Function(_V)? transform,
  }) {
    if (value.isEmpty) return;
    _V map(_V point) => transform == null ? point : transform(point);
    final a = p.project(map(_V(x, y, z)));
    final b = p.project(map(_V(x + 1, y, z)));
    final c = p.project(map(_V(x, y + 1, z)));
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
    if (maxWidth != null && painter.width > maxWidth) {
      canvas.scale(maxWidth / painter.width, 1);
    }
    painter.paint(
      canvas,
      Offset(center ? -painter.width / 2 : 0, -painter.height / 2),
    );
    canvas.restore();
  }

  void contactShadow(
    double x,
    double y,
    double w,
    double h,
    double z, {
    double radius = 1,
  }) {
    final shape = p.polygon(outline(x, y, w, h, z, radius));
    canvas.drawPath(
      shape.shift(Offset(.28 * p.scale, .55 * p.scale)),
      Paint()
        ..color = const Color(0x380B1610)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, .65 * p.scale),
    );
  }

  void screw(_V at) {
    // Moulded countersink, conical steel rim and an actual recessed PZ head.
    // The terminal centre remains exactly the canonical electrical anchor.
    disc(at, 4.65, [
      const Color(0xFFF8F9F4),
      const Color(0xFFB6BDB5),
      const Color(0xFF6A746B),
    ]);
    final ring = <_Face>[];
    for (var i = 0; i < 40; i++) {
      final a = i * math.pi / 20, b = (i + 1) * math.pi / 20;
      _V q(double angle, double r, double z) =>
          _V(at.x + r * math.cos(angle), at.y + r * math.sin(angle), z);
      ring.add(
        _Face([
          q(a, 4.15, at.z + .1),
          q(b, 4.15, at.z + .1),
          q(b, 3.35, at.z - .85),
          q(a, 3.35, at.z - .85),
        ], const Color(0xFF9CA5AA)),
      );
    }
    faces(ring);
    disc(_V(at.x, at.y, at.z - .8), 3.4, [
      const Color(0xFF121915),
      const Color(0xFF07100C),
      const Color(0xFF343E35),
    ]);
    disc(at, 2.68, [
      const Color(0xFF99A3A9),
      const Color(0xFF48545C),
      const Color(0xFF20282E),
    ]);
    // The drive has tapered walls: a bright steel lip surrounds a narrower
    // dark cavity. Its centre is recessed, rather than a black cross decal.
    const cross = <(double, double)>[
      (-.54, -2.15),
      (.54, -2.15),
      (.54, -.54),
      (2.15, -.54),
      (2.15, .54),
      (.54, .54),
      (.54, 2.15),
      (-.54, 2.15),
      (-.54, .54),
      (-2.15, .54),
      (-2.15, -.54),
      (-.54, -.54),
    ];
    final lip = p.polygon([
      for (final q in cross) _V(at.x + q.$1, at.y + q.$2, at.z + .2),
    ]);
    canvas.drawPath(
      lip,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFCDD2D2), Color(0xFF70797D), Color(0xFF151D21)],
          stops: [0, .36, 1],
        ).createShader(lip.getBounds()),
    );
    final cut = p.polygon([
      for (final q in cross)
        _V(at.x + q.$1 * .78, at.y + q.$2 * .88, at.z - .3),
    ]);
    canvas.drawPath(cut, Paint()..color = const Color(0xFF11181B));
    // Broken highlights follow the curvature of the plated screw head.
    // Short arcs and subdued machining marks avoid a uniform icon-like disk.
    for (final arc in [(-2.8, -1.6, 2.42), (-.8, .05, 2.35)]) {
      for (var i = 0; i < 12; i++) {
        final a = arc.$1 + (arc.$2 - arc.$1) * i / 12;
        final b = arc.$1 + (arc.$2 - arc.$1) * (i + 1) / 12;
        line(
          _V(
            at.x + arc.$3 * math.cos(a),
            at.y + arc.$3 * math.sin(a),
            at.z + .22,
          ),
          _V(
            at.x + arc.$3 * math.cos(b),
            at.y + arc.$3 * math.sin(b),
            at.z + .22,
          ),
          const Color(0x8FBCC3C7),
          .15,
        );
      }
    }
    // Fine secondary PZ grooves remain dark, never a drawn white X.
    for (final sign in [-1.0, 1.0]) {
      line(
        _V(at.x + sign * 1.2, at.y + sign * 1.2, at.z + .18),
        _V(at.x + sign * 1.82, at.y + sign * 1.82, at.z + .18),
        const Color(0xFF1B271E),
        .22,
      );
      line(
        _V(at.x + sign * 1.2, at.y - sign * 1.2, at.z + .18),
        _V(at.x + sign * 1.82, at.y - sign * 1.82, at.z + .18),
        const Color(0xFF1B271E),
        .22,
      );
    }
  }

  void rocker(double x, _V Function(_V) transform) {
    final facesMesh = <_Face>[];
    double depth(double y) => 46.0 + 2.1 * math.cos((y - 19) * math.pi / 23);
    for (var i = 0; i < 16; i++) {
      final a = 10.6 + i * 17.8 / 16, b = 10.6 + (i + 1) * 17.8 / 16;
      facesMesh.add(
        _Face([
          transform(_V(x - 5.25, a, depth(a))),
          transform(_V(x + 5.25, a, depth(a))),
          transform(_V(x + 5.25, b, depth(b))),
          transform(_V(x - 5.25, b, depth(b))),
        ], const Color(0xFF252B28)),
      );
      for (final side in [-1.0, 1.0]) {
        final points = [
          transform(_V(x + side * 4.85, a, depth(a) - 2.1)),
          transform(_V(x + side * 4.85, b, depth(b) - 2.1)),
          transform(_V(x + side * 5.25, b, depth(b))),
          transform(_V(x + side * 5.25, a, depth(a))),
        ];
        facesMesh.add(
          _Face(
            side > 0 ? points : points.reversed.toList(),
            const Color(0xFF202720),
          ),
        );
      }
    }
    for (final y in [10.6, 28.4]) {
      final cap = [
        transform(_V(x - 4.85, y, depth(y) - 2.1)),
        transform(_V(x + 4.85, y, depth(y) - 2.1)),
        transform(_V(x + 5.25, y, depth(y))),
        transform(_V(x - 5.25, y, depth(y))),
      ];
      facesMesh.add(
        _Face(y < 19 ? cap : cap.reversed.toList(), const Color(0xFF252B28)),
      );
    }
    faces(facesMesh);
  }
}

/// Two physically rendered transparent plates, shared by every instance.
/// They contain no electrical state, rated values, Test button or moving lever.
/// The executable geometry and hit regions remain in the native Dart renderer.
class _PhysicalHousing extends ChangeNotifier {
  final images = <VueDisjoncteur, ui.Image>{};
  Future<bool>? _loading;
  Future<bool> load() => _loading ??= _load();
  Future<bool> _load() async {
    final decoded = <VueDisjoncteur, ui.Image>{};
    try {
      for (final vue in VueDisjoncteur.values) {
        final data = await rootBundle.load(
          'assets/g5_physical/housing-${vue.name}.png',
        );
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        try {
          decoded[vue] = (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
      }
    } on FlutterError {
      for (final image in decoded.values) {
        image.dispose();
      }
      return false;
    } on Exception {
      for (final image in decoded.values) {
        image.dispose();
      }
      return false;
    }
    images.addAll(decoded);
    _housingCache.clear();
    notifyListeners();
    return true;
  }
}

final _physicalHousing = _PhysicalHousing();

typedef _HousingKey = (Size, VueDisjoncteur, double?, double?, bool, bool);

/// Bounded native display-list cache. Meshes, markings and grain are recorded
/// once; only the linked controls are redrawn during their 170 ms movement.
class _RcdHousingCache {
  _RcdHousingCache() {
    PaintingBinding.instance.systemFonts.addListener(clear);
  }
  final _entries = <_HousingKey, ui.Picture>{};
  ui.Picture obtain(_HousingKey key, ui.Picture Function() create) {
    final picture = _entries.remove(key) ?? create();
    _entries[key] = picture;
    if (_entries.length > 24) {
      _entries.remove(_entries.keys.first)!.dispose();
    }
    return picture;
  }

  void clear() {
    for (final picture in _entries.values) {
      picture.dispose();
    }
    _entries.clear();
  }
}

final _housingCache = _RcdHousingCache();

class _DisjoncteurPainter extends CustomPainter {
  _DisjoncteurPainter({
    required this.widget,
    required this.position,
    required this.testEnfonce,
    required this.focus,
    this.onCommande,
    this.onTest,
  }) : super(
         repaint: Listenable.merge([
           _physicalHousing,
           PaintingBinding.instance.systemFonts,
         ]),
       );
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
    canvas.drawPicture(
      _housingCache.obtain((
        size,
        widget.vue,
        widget.calibreA,
        widget.sensibiliteMA,
        widget.estDifferentiel,
        testEnfonce,
      ), () => _recordHousing(p)),
    );
    final scene = _Scene(canvas, p);
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
      scene.rocker(x, rotate);
      scene.box(
        x,
        14.5,
        9.3,
        5.4,
        48.25,
        .9,
        widget.etat == EtatDisjoncteur.declenche
            ? const Color(0xFFC08A25)
            : widget.etat == EtatDisjoncteur.ferme
            ? const Color(0xFFBA3F37)
            : const Color(0xFF25AC4F),
        radius: .4,
        bevel: .2,
        transform: rotate,
      );
      scene.line(
        rotate(_V(x - 3.7, 21.8, 47.0)),
        rotate(_V(x + 3.7, 21.8, 47.0)),
        const Color(0xFF343C40),
        .28,
      );
      scene.line(
        rotate(_V(x - 3.7, 24.2, 47.0)),
        rotate(_V(x + 3.7, 24.2, 47.0)),
        const Color(0xFF343C40),
        .22,
      );
      scene.text(
        widget.etat == EtatDisjoncteur.ferme
            ? 'I · ON'
            : widget.etat == EtatDisjoncteur.declenche
            ? 'TRIP'
            : 'O · OFF',
        x - 4.0,
        14.5,
        49.0,
        2.25,
        color: const Color(0xFFF8FCF8),
        weight: FontWeight.w500,
        maxWidth: 8,
        transform: rotate,
      );
    }
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
    for (final y in [25.4, 26.1, 26.8]) {
      scene.line(
        rotate(_V(-14.0, y, 50.06)),
        rotate(_V(14.0, y, 50.06)),
        const Color(0xFF4C5550),
        .12,
      );
    }
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

  ui.Picture _recordHousing(_Projection p) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final scene = _Scene(canvas, p);
    final physical = _physicalHousing.images[widget.vue];
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
    if (physical == null) {
      // Single parametric industrial assembly, shared across camera views.
      _Rcd2pMeshFactory.housing(scene);
      _Rcd2pMeshFactory.yellowReleaseTabs(scene);
      for (final y in [-32.0, -20.0, -5.0, 10.0, 25.0, 36.0]) {
        scene.disc(_V(-18.06, y, -16), 1.55, [
          const Color(0xFF929E97),
          const Color(0xFFE0E7E0),
        ], side: true);
      }
      // Moulded terminal sockets are independent meshes, not flat decals.
      _Rcd2pMeshFactory.terminalEnclosures(scene);
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
      scene.line(
        const _V(0, -40.8, 35.66),
        const _V(0, -20.0, 35.66),
        const Color(0xFFBEC4BF),
        .15,
      );
      scene.line(
        const _V(0, 28.1, 35.66),
        const _V(0, 41.7, 35.66),
        const Color(0xFFBEC4BF),
        .15,
      );
    } else {
      // Map the plate's canonical projector to the current projector. A plain
      // BoxFit would move terminal centres when the widget aspect ratio changes.
      final reference = _Projection(
        const Size(280, 430),
        widget.vue.angleHorizontal,
        widget.vue.angleVertical,
      );
      final ratio = p.scale / reference.scale;
      final offset = p.origin - reference.origin * ratio;
      canvas.drawImageRect(
        physical,
        Offset.zero &
            Size(physical.width.toDouble(), physical.height.toDouble()),
        offset & Size(280 * ratio, 430 * ratio),
        Paint()..filterQuality = FilterQuality.high,
      );
    }
    scene.text('N', -13.2, -37.2, 35.5, 2.8, weight: FontWeight.w700);
    scene.text('N', -13.2, 40.4, 35.5, 2.8, weight: FontWeight.w700);
    scene.text('1', 9, -37.2, 35.5, 2.5);
    scene.text('2', 9, 40.4, 35.5, 2.5);
    if (physical == null) {
      scene.contactShadow(0, -6, 35, 28, 39.7, radius: 1.1);
      scene.box(0, -6, 35, 28, 40, 6, _Scene.blanc, radius: 1.1, bevel: .45);
      scene.box(
        0,
        -19.3,
        35.4,
        1.5,
        39.6,
        3.4,
        const Color(0xFFF0F2EE),
        radius: .45,
        bevel: .24,
      );
      scene.box(
        -6.7,
        -15,
        18.6,
        1.3,
        40.2,
        .15,
        _Scene.accent,
        radius: .05,
        bevel: .02,
      );
    }
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
      2.65,
      maxWidth: 19,
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
      scene.text(
        'Sensibilité : ${_nombre(widget.sensibiliteMA)} mA',
        -14,
        3.0,
        40.4,
        1.95,
      );
    }
    if (widget.estDifferentiel) {
      // Printed two-pole/test circuit; decorative marking only, never a solver.
      scene.text('N', 8, -1.4, 40.7, 1.3);
      for (final x in [8.0, 11.6]) {
        scene.line(
          _V(x, -.3, 40.7),
          _V(x, 1.0, 40.7),
          const Color(0xFF29322F),
          .14,
        );
        scene.line(
          _V(x, 1.0, 40.7),
          _V(x - .7, 2.0, 40.7),
          const Color(0xFF29322F),
          .14,
        );
        scene.line(
          _V(x, 2.3, 40.7),
          _V(x, 6.8, 40.7),
          const Color(0xFF29322F),
          .14,
        );
        scene.line(
          _V(x - .25, 6.25, 40.7),
          _V(x, 6.8, 40.7),
          const Color(0xFF29322F),
          .12,
        );
        scene.line(
          _V(x + .25, 6.25, 40.7),
          _V(x, 6.8, 40.7),
          const Color(0xFF29322F),
          .12,
        );
      }
      for (final y in [2.7, 4.5]) {
        for (double x = 6.9; x < 12.5; x += .7) {
          scene.line(
            _V(x, y, 40.7),
            _V(x + .35, y, 40.7),
            const Color(0xFF29322F),
            .11,
          );
        }
      }
      scene.line(
        const _V(6.9, 2.7, 40.7),
        const _V(6.9, 4.5, 40.7),
        const Color(0xFF29322F),
        .11,
      );
      scene.line(
        const _V(12.6, 2.7, 40.7),
        const _V(12.6, 4.5, 40.7),
        const Color(0xFF29322F),
        .11,
      );
      for (final ab in [
        (const _V(13.6, 2.3, 40.7), const _V(16, 2.3, 40.7)),
        (const _V(16, 2.3, 40.7), const _V(16, 4.9, 40.7)),
        (const _V(16, 4.9, 40.7), const _V(13.6, 4.9, 40.7)),
        (const _V(13.6, 4.9, 40.7), const _V(13.6, 2.3, 40.7)),
        (const _V(11.6, 1.2, 40.7), const _V(14.8, 1.2, 40.7)),
        (const _V(14.8, 1.2, 40.7), const _V(14.8, 2.3, 40.7)),
      ]) {
        scene.line(ab.$1, ab.$2, const Color(0xFF29322F), .11);
      }
      scene.text('T', 14.8, 3.6, 40.75, 1.8, center: true);
      scene.box(
        10.5,
        -10.6,
        9.8,
        6.4,
        40.7,
        1,
        const Color(0xFF555B61),
        radius: .85,
      );
      scene.box(
        10.5,
        -10.6,
        8.3,
        4.9,
        testEnfonce ? 40.8 : 41.5,
        .9,
        const Color(0xFF9BA0A6),
        radius: .75,
        bevel: .3,
      );
      scene.text(
        'T',
        10.36,
        -10.75,
        testEnfonce ? 40.85 : 41.55,
        3,
        color: const Color(0xFFD0D3D0),
        weight: FontWeight.w700,
        center: true,
      );
      scene.text(
        'T',
        10.5,
        -10.6,
        testEnfonce ? 40.85 : 41.55,
        3,
        color: const Color(0xFF626A69),
        weight: FontWeight.w700,
        center: true,
      );
      scene.text(
        'Test',
        7.8,
        -5.3,
        40.55,
        1.8,
        color: _Scene.graphite,
        weight: FontWeight.w500,
      );
    }
    scene.line(
      const _V(-16, 7.1, 40.1),
      const _V(16, 7.1, 40.1),
      const Color(0xFFB3BFB8),
      .16,
    );
    if (physical == null) {
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
        scene.contactShadow(x, 19.3, 14.7, 23.5, 40.4, radius: 5.5);
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
          const Color(0xFFBFC2BD),
          radius: 4.1,
          bevel: .3,
        );
      }
      scene.box(0, 31, 15, 1.7, 39.4, .6, const Color(0xFFC7D0C8), radius: .2);
    }
    return recorder.endRecording();
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
