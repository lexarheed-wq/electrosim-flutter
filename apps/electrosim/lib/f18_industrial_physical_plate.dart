import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Original Cycles housing plates. Only immutable material/geometry is baked;
/// operating states and moving controls are supplied by ElectroSim's engine.
abstract final class F18PhysicalPlateAssets {
  static const models = <String, String>{
    'breaker_ac1': 'breaker1',
    'breaker_dc': 'breaker1',
    'breaker': 'breaker1',
    'push_button_no': 'button-no',
    'push_button_nc': 'button-nc',
    'contactor_ac1': 'contactor1',
    'contactor_3p': 'contactor3',
    'breaker_3p': 'breaker3',
    'thermal_overload_3p': 'overload',
    'motor_3p_6t': 'motor3',
    'isolator_3p': 'isolator3',
    'isolator_4p': 'isolator4',
    'breaker_4p': 'breaker4',
    'lamp': 'lamp',
    'fuse_dc': 'fuse-holder',
    'fuse_ac1': 'fuse-holder',
    'fuse': 'fuse-holder',
    'contactor_aux_no': 'auxiliary-no',
    'relay_contact_no': 'auxiliary-no',
    'contactor_aux_nc': 'auxiliary-nc',
    'relay_contact_nc': 'auxiliary-nc',
    'relay_coil': 'coil',
    'terminal_block_5': 'terminal5',
    'motor_dc': 'motor-dc',
    'fan_dc': 'fan',
    'buzzer': 'buzzer',
  };
  static final _images = <String, ui.Image>{};
  static final _geometry = <String, Map<String, dynamic>>{};
  static final _controlRects = <String, Rect>{};
  static Future<bool>? _loading;
  static bool supports(String type) => models.containsKey(type.toLowerCase());
  static bool ready(String type) =>
      _images.containsKey('${models[type.toLowerCase()]}-front');
  static Future<bool> preload() => _loading ??= _load();
  static Future<bool> _load() async {
    try {
      final manifest =
          jsonDecode(
                await rootBundle.loadString(
                  'assets/g5_industrial/geometry.json',
                ),
              )
              as Map<String, dynamic>;
      final controls =
          jsonDecode(
                await rootBundle.loadString(
                  'assets/g5_industrial/controls.json',
                ),
              )
              as Map<String, dynamic>;
      for (final name in models.values.toSet()) {
        final staged = <String, ui.Image>{};
        final stagedRects = <String, Rect>{};
        try {
          final moving =
              name.startsWith('breaker') ||
              name.startsWith('isolator') ||
              name.startsWith('button-') ||
              name == 'fan';
          for (final camera in ['front', 'palette']) {
            for (final layer
                in moving
                    ? [
                        '',
                        '-controls',
                        if (name.startsWith('breaker') ||
                            name.startsWith('isolator')) ...[
                          '-controls-on',
                          '-controls-trip',
                        ],
                      ]
                    : ['']) {
              final key = '$name$layer-$camera';
              final bytes = await rootBundle.load(
                'assets/g5_industrial/$key.png',
              );
              final codec = await ui.instantiateImageCodec(
                bytes.buffer.asUint8List(
                  bytes.offsetInBytes,
                  bytes.lengthInBytes,
                ),
              );
              try {
                staged[key] = (await codec.getNextFrame()).image;
              } finally {
                codec.dispose();
              }
              if (layer.isNotEmpty) {
                final pose = layer.replaceFirst('-controls', '');
                final bounds = controls['$name$pose-$camera'] as List;
                if (bounds.length != 4 ||
                    bounds.any((n) => n is! num || !n.isFinite) ||
                    (bounds[2] as num) <= 0 ||
                    (bounds[3] as num) <= 0) {
                  throw const FormatException('Invalid control bounds');
                }
                stagedRects[key] = Rect.fromLTWH(
                  (bounds[0] as num).toDouble(),
                  (bounds[1] as num).toDouble(),
                  (bounds[2] as num).toDouble(),
                  (bounds[3] as num).toDouble(),
                );
              }
            }
          }
          _geometry[name] = Map<String, dynamic>.from(manifest[name] as Map);
          _images.addAll(staged);
          _controlRects.addAll(stagedRects);
        } catch (_) {
          for (final image in staged.values) {
            image.dispose();
          }
        }
      }
    } catch (_) {
      return false;
    }
    return _geometry.length == models.values.toSet().length;
  }
}

/// Palette context replaces the former transform of a flat front drawing.
/// The board has no inherited camera and remains in its canonical coordinates.
class F18PhysicalPresentationScope extends InheritedWidget {
  const F18PhysicalPresentationScope({super.key, required super.child});
  static bool perspectiveOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<F18PhysicalPresentationScope>() !=
      null;
  @override
  bool updateShouldNotify(F18PhysicalPresentationScope oldWidget) => false;
}

class F18IndustrialPhysicalPlate extends StatelessWidget {
  const F18IndustrialPhysicalPlate({
    super.key,
    required this.modelType,
    required this.size,
    this.perspective = false,
    this.closed = true,
    this.tripped = false,
    this.pressed = false,
    this.energized = false,
    this.actuated = false,
    this.active = true,
    this.showTerminals = true,
    this.phase = 0,
    this.currentA = 0,
    this.voltageV = 0,
    this.ratedCurrentA = 0,
    this.currentLimitA = 2,
    this.variantKey,
  });
  final String modelType;
  final Size size;
  final bool perspective,
      closed,
      tripped,
      pressed,
      energized,
      actuated,
      active,
      showTerminals;
  final double phase, currentA, voltageV, ratedCurrentA, currentLimitA;
  final String? variantKey;
  double get handle => tripped
      ? 0.5
      : closed
      ? 0
      : 1;
  String get accessibleName =>
      switch (F18PhysicalPlateAssets.models[modelType.toLowerCase()]) {
        'breaker1' => 'Disjoncteur unipolaire',
        'breaker3' => 'Disjoncteur tripolaire',
        'breaker4' => 'Disjoncteur tétrapolaire',
        'isolator3' => 'Sectionneur tripolaire',
        'isolator4' => 'Sectionneur tétrapolaire',
        'contactor1' => 'Contacteur monophasé',
        'contactor3' => 'Contacteur triphasé',
        'overload' => 'Relais thermique',
        'button-no' => 'Bouton-poussoir normalement ouvert',
        'button-nc' => 'Bouton-poussoir normalement fermé',
        'motor3' => 'Moteur triphasé',
        'lamp' => 'Lampe à incandescence',
        'fuse-holder' => 'Porte-fusible',
        'auxiliary-no' => 'Contact auxiliaire normalement ouvert',
        'auxiliary-nc' => 'Contact auxiliaire normalement fermé',
        'coil' => 'Bobine de relais sur socle',
        'terminal5' => 'Bornier à cinq voies indépendantes',
        'motor-dc' => 'Moteur à courant continu',
        'fan' => 'Ventilateur axial à deux fils',
        'buzzer' => 'Avertisseur sonore',
        _ => modelType,
      };
  String get accessibleState {
    final shape = F18PhysicalPlateAssets.models[modelType.toLowerCase()] ?? '';
    if (shape.startsWith('button-')) return pressed ? 'appuyé' : 'relâché';
    if (shape.startsWith('contactor')) return actuated ? 'attiré' : 'au repos';
    if (shape.startsWith('auxiliary-')) {
      final contactClosed = shape == 'auxiliary-nc' ? !actuated : actuated;
      return contactClosed ? 'fermé' : 'ouvert';
    }
    if (shape == 'lamp') return energized ? 'allumée' : 'éteinte';
    if (shape == 'motor3' ||
        shape == 'motor-dc' ||
        shape == 'fan' ||
        shape == 'buzzer') {
      return energized ? 'alimenté' : 'au repos';
    }
    if (shape == 'supply') return active ? 'actif' : 'arrêté';
    if (shape == 'terminal5') return 'bornier de connexion';
    if (shape == 'coil') return energized || actuated ? 'excité' : 'au repos';
    if (shape == 'fuse-holder') {
      return tripped ? 'fusible fondu' : 'fusible intact';
    }
    if (shape == 'overload') return tripped ? 'déclenché' : 'au repos';
    return tripped
        ? 'déclenché'
        : closed
        ? 'fermé'
        : 'ouvert';
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$accessibleName, $accessibleState',
    child: SizedBox(
      width: size.width,
      height: size.height,
      child: RepaintBoundary(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: handle),
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
          builder: (context, position, child) =>
              CustomPaint(painter: _PhysicalPlatePainter(this, position)),
        ),
      ),
    ),
  );
}

final class _PhysicalPlatePainter extends CustomPainter {
  _PhysicalPlatePainter(this.v, this.handle)
    : super(repaint: PaintingBinding.instance.systemFonts);
  final F18IndustrialPhysicalPlate v;
  final double handle;
  static const graphite = Color(0xFF273338), green = Color(0xFF169352);
  late String name;
  late Size design;
  late List<Offset> ports;
  Offset project(Offset p, {double z = 25}) {
    if (!v.perspective) return p;
    const yaw = -24 * math.pi / 180, pitch = -16 * math.pi / 180;
    final x = p.dx - design.width / 2, y = p.dy - design.height / 2;
    final zz = -x * math.sin(yaw) + z * math.cos(yaw);
    return Offset(
      design.width / 2 + .78 * (x * math.cos(yaw) + z * math.sin(yaw)),
      design.height / 2 + .78 * (y * math.cos(pitch) - zz * math.sin(pitch)),
    );
  }

  void text(
    Canvas c,
    String s,
    Offset p, {
    double font = 8,
    Color color = graphite,
    bool center = true,
    double? z,
  }) {
    final t = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: font,
          color: color,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final faceZ =
        z ??
        (name.startsWith('contactor')
            ? 32
            : name == 'overload'
            ? 29
            : name.startsWith('button-')
            ? 20
            : 28);
    final origin = project(p, z: faceZ);
    c.save();
    c.translate(origin.dx, origin.dy);
    if (v.perspective) {
      const yaw = -24 * math.pi / 180, pitch = -16 * math.pi / 180;
      c.transform(
        (Matrix4.identity()
              ..setEntry(0, 0, .78 * math.cos(yaw))
              ..setEntry(1, 0, .78 * math.sin(yaw) * math.sin(pitch))
              ..setEntry(1, 1, .78 * math.cos(pitch)))
            .storage,
      );
    }
    t.paint(c, Offset(center ? -t.width / 2 : 0, -t.height / 2));
    c.restore();
  }

  Path rectPath(Rect r, {double z = 25}) => Path()
    ..addPolygon([
      project(r.topLeft, z: z),
      project(r.topRight, z: z),
      project(r.bottomRight, z: z),
      project(r.bottomLeft, z: z),
    ], true);
  void plate(
    Canvas c,
    Rect r,
    List<Color> colors, {
    double z = 25,
    double radius = 2,
  }) {
    final path = rectPath(r, z: z);
    // A rounded front face plus real bevel highlights, projected in the same
    // camera as the immutable housing (never rotating electrical ports).
    if (!v.perspective) {
      c.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(radius)),
        Paint()
          ..shader = LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(r),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(r.deflate(.5), Radius.circular(radius)),
        Paint()
          ..color = const Color(0x55FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7,
      );
    } else {
      c.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(path.getBounds()),
      );
      c.drawPath(
        path,
        Paint()
          ..color = const Color(0x50FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .6,
      );
    }
  }

  double get w => design.width;
  double get h => design.height;
  void controlLayer(
    Canvas c, {
    double depth = 0,
    bool depressed = false,
    String pose = '',
    double alpha = 1,
  }) {
    if (alpha <= 0) return;
    final key = '$name-controls$pose-${v.perspective ? 'palette' : 'front'}';
    final image = F18PhysicalPlateAssets._images[key]!;
    final rect = F18PhysicalPlateAssets._controlRects[key]!;
    final offset = v.perspective
        ? project(Offset.zero, z: depth) - project(Offset.zero, z: 0)
        : Offset.zero;
    c.drawImageRect(
      image,
      Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
      rect.shift(offset),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Colors.white.withValues(alpha: alpha)
        ..colorFilter = depressed
            ? const ColorFilter.mode(Color(0x22000000), BlendMode.srcATop)
            : null,
    );
  }

  void handles(Canvas c) {
    final poles = ports.length ~/ 2;
    const dy = 0.0;
    if (handle <= .5) {
      controlLayer(c, pose: '-on', alpha: 1 - handle * 2);
      controlLayer(c, pose: '-trip', alpha: handle * 2);
    } else {
      controlLayer(c, pose: '-trip', alpha: 2 - handle * 2);
      controlLayer(c, alpha: handle * 2 - 1);
    }
    final effective = v.tripped
        ? const Color(0xFFC78325)
        : v.closed
        ? const Color(0xFFB32F2C)
        : green;
    for (var i = 0; i < poles; i++) {
      final pw = poles == 1 ? w * .45 : ports[1].dx - ports[0].dx;
      plate(
        c,
        Rect.fromCenter(
          center: Offset(ports[i].dx, h * .558 + dy),
          width: pw * .51,
          height: h * .058,
        ),
        [Color.lerp(effective, Colors.white, .13)!, effective],
        z: 33,
      );
      text(
        c,
        v.tripped
            ? 'TRIP'
            : v.closed
            ? 'I · ON'
            : 'O · OFF',
        Offset(ports[i].dx, h * .558 + dy),
        font: math.min(7, pw * .19),
        color: Colors.white,
      );
    }
    final title = name.startsWith('isolator')
        ? 'SECTIONNEUR ${poles}P'
        : 'DISJONCTEUR ${poles}P';
    text(
      c,
      'ElectroSim',
      Offset(w / 2, h * .32),
      font: math.min(9, h * .034),
      color: const Color(0xFF287447),
    );
    text(
      c,
      title,
      Offset(w / 2, h * .39),
      font: math.min(9, w * (poles == 1 ? .038 : .075)),
    );
    if (v.ratedCurrentA > 0 && v.ratedCurrentA.isFinite) {
      text(
        c,
        '${v.ratedCurrentA.toStringAsFixed(1)} A',
        Offset(w / 2, h * .445),
        font: 7,
      );
    }
  }

  void contactor(Canvas c) {
    final single = name == 'contactor1';
    text(
      c,
      'CONTACTEUR',
      Offset(w / 2, h * .39),
      font: h * .035,
      color: const Color(0xFF267248),
    );
    final window = Rect.fromCenter(
      center: Offset(w / 2, h * .52),
      width: w * .42,
      height: h * .12,
    );
    for (var i = 0; i < (single ? 1 : 3); i++) {
      final x = single ? w / 2 : window.left + window.width * (.23 + i * .27);
      plate(
        c,
        Rect.fromCenter(
          center: Offset(x, h * (.52 + (v.actuated ? 0.012 : -.012))),
          width: w * .06,
          height: h * .075,
        ),
        const [Color(0xFFC1CCD0), Color(0xFF657982)],
      );
    }
    text(
      c,
      single ? '1 PÔLE' : '3 PÔLES',
      Offset(w / 2, h * .62),
      font: h * .035,
    );
    plate(
      c,
      Rect.fromCenter(
        center: Offset(w / 2, h * .72),
        width: w * .14,
        height: h * .045,
      ),
      [v.actuated ? green : const Color(0xFF5D6965), graphite],
    );
  }

  void rotationIndicator(
    Canvas c,
    Offset center,
    double radius, {
    double z = 20,
  }) {
    // Viewport motion marker: angle traverses a complete turn while the motor
    // casing, physical shaft axis and electrical terminals remain fixed.
    c.drawCircle(
      project(center, z: z),
      radius,
      Paint()
        ..color = const Color(0xFF71848D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
    final angle = (v.phase % 1) * 2 * math.pi;
    final p = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    c.drawLine(
      project(center, z: z),
      project(p, z: z),
      Paint()
        ..color = const Color(0xFF25AEBB)
        ..strokeWidth = 1.6,
    );
    c.drawCircle(
      project(p, z: z),
      1.9,
      Paint()..color = const Color(0xFF25AEBB),
    );
  }

  void overlays(Canvas c) {
    if (name.startsWith('breaker') || name.startsWith('isolator')) {
      handles(c);
      return;
    }
    if (name.startsWith('contactor')) {
      contactor(c);
      return;
    }
    switch (name) {
      case 'fan':
        c.save();
        if (!v.perspective) {
          c.translate(w / 2, h * .44);
          c.rotate((v.phase % 1) * math.pi * 2);
          c.translate(-w / 2, -h * .44);
        }
        controlLayer(c);
        c.restore();
        text(
          c,
          'CC · 2 FILS',
          Offset(w / 2, h * .80),
          z: 26,
          font: w * .040,
          color: Colors.white,
        );
      case 'motor-dc':
        text(
          c,
          'MOTEUR CC',
          Offset(w * .48, h * .31),
          z: h * .24 * .90 + 1,
          font: w * .044,
          color: Colors.white,
        );
        rotationIndicator(c, Offset(w * .91, h * .68), h * .065);
        final a = (v.phase % 1) * 2 * math.pi;
        if (math.sin(a) >= 0) {
          c.drawLine(
            project(
              Offset(w * .85, h * .43 + h * .027 * math.cos(a)),
              z: h * .027 * math.sin(a),
            ),
            project(
              Offset(w * .97, h * .43 + h * .027 * math.cos(a)),
              z: h * .027 * math.sin(a),
            ),
            Paint()
              ..color = const Color(0xFF64727B)
              ..strokeWidth = 1.2,
          );
        }
      case 'buzzer':
        text(
          c,
          'AVERTISSEUR CC',
          Offset(w / 2, h * .60),
          z: 38,
          font: w * .044,
          color: Colors.white,
        );
        if (v.energized) {
          for (var i = 0; i < 3; i++) {
            final r = w * (.055 + i * .032);
            final center = project(Offset(w * .79, h * .42), z: 38);
            c.drawArc(
              Rect.fromCircle(center: center, radius: r),
              -.65,
              1.3,
              false,
              Paint()
                ..color = const Color(0xFF22AEBB)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.2,
            );
          }
        }
      case 'fuse-holder':
        text(
          c,
          'PORTE-FUSIBLE',
          Offset(w * .49, h * .40),
          z: 35,
          font: h * .075,
        );
        text(
          c,
          v.tripped ? 'FUSIBLE FONDU' : 'FUSIBLE INTACT',
          Offset(w * .49, h * .60),
          z: 35,
          font: h * .064,
          color: v.tripped ? const Color(0xFFBA2424) : graphite,
        );
      case 'auxiliary-no':
      case 'auxiliary-nc':
        final contactClosed = name == 'auxiliary-nc' ? !v.actuated : v.actuated;
        text(
          c,
          name == 'auxiliary-no' ? 'NO' : 'NC',
          Offset(w * .46, h * .50),
          z: 28,
          font: w * .13,
          color: Colors.white,
        );
        text(
          c,
          contactClosed ? 'FERMÉ' : 'OUVERT',
          Offset(w * .46, h * .60),
          z: 28,
          font: w * .060,
          color: Colors.white,
        );
        c.drawLine(
          project(Offset(w * .73, h * (contactClosed ? .50 : .60)), z: 29),
          project(Offset(w * .73, h * (contactClosed ? .54 : .64)), z: 29),
          Paint()
            ..color = const Color(0xFFDCE0D7)
            ..strokeWidth = w * .04,
        );
      case 'coil':
        text(
          c,
          v.energized || v.actuated ? 'BOBINE · EXCITÉE' : 'BOBINE · AU REPOS',
          Offset(w * .50, h * .74),
          z: 44,
          font: w * .048,
        );
      case 'terminal5':
        for (var i = 0; i < 5; i++) {
          text(
            c,
            i == 4 ? 'PE' : '${i + 1}',
            Offset(ports[i].dx, h * .50),
            z: 22,
            font: h * .055,
          );
        }
      case 'button-no':
      case 'button-nc':
        final nc = name == 'button-nc';
        controlLayer(c, depth: v.pressed ? -3 : 0, depressed: v.pressed);
        text(
          c,
          nc ? 'ARRÊT · NC' : 'MARCHE · NO',
          Offset(w / 2, h * .71),
          font: w * .075,
        );
      case 'lamp':
        final level = (v.voltageV.abs() / 24).clamp(0.0, 1.0);
        final brightness = v.energized ? level * level : 0.0;
        if (brightness > 0) {
          final filament = Path();
          for (var i = 0; i <= 32; i++) {
            final t = i / 32;
            final p = project(
              Offset(
                w / 2 - 21 + 42 * t,
                h * (.32 + .035 * math.sin(t * math.pi)),
              ),
              z: 28,
            );
            if (i == 0) {
              filament.moveTo(p.dx, p.dy);
            } else {
              filament.lineTo(p.dx, p.dy);
            }
          }
          c.drawPath(
            filament,
            Paint()
              ..color = const Color(
                0xFFFFAF42,
              ).withValues(alpha: .4 * brightness)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
          );
          c.drawPath(
            filament,
            Paint()
              ..color = Color.lerp(
                const Color(0xFFB34117),
                const Color(0xFFFFE5B2),
                level,
              )!.withValues(alpha: brightness)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.1,
          );
        }
      case 'motor3':
        final shaftAngle = (v.phase % 1) * 2 * math.pi;
        if (math.sin(shaftAngle) >= 0) {
          final y = h * .48 + h * .035 * math.cos(shaftAngle);
          final z = h * .035 * math.sin(shaftAngle);
          c.drawLine(
            project(Offset(w * .855, y), z: z),
            project(Offset(w * .935, y), z: z),
            Paint()
              ..color = const Color(0xFF5B6871)
              ..strokeWidth = 1,
          );
        }
        rotationIndicator(c, Offset(w * .91, h * .64), h * .045);
        text(
          c,
          'M 3~',
          Offset(w * .61, h * .25),
          z: h * .34 * .77 + 2,
          font: h * .04,
          color: Colors.white,
        );
      case 'overload':
        text(
          c,
          'RELAIS THERMIQUE',
          Offset(w / 2, h * .23),
          font: h * .033,
          color: Colors.white,
        );
        text(
          c,
          'STOP',
          Offset(w * .78, h * .67),
          font: h * .032,
          color: Colors.white,
        );
        text(
          c,
          'RESET',
          Offset(w * .78, h * .37),
          font: h * .03,
          color: Colors.white,
        );
        text(
          c,
          v.tripped ? 'DÉCLENCHÉ' : '3 PÔLES',
          Offset(w / 2, h * .71),
          font: h * .04,
          color: v.tripped ? const Color(0xFFBA2424) : Colors.white,
        );
        c.drawLine(
          project(Offset(w * .34, h * .58), z: 29),
          project(Offset(w * .37, h * .545), z: 29),
          Paint()
            ..color = graphite
            ..strokeWidth = 1.2,
        );
    }
  }

  void portLabels(Canvas c) {
    if (!v.showTerminals) return;
    final labels = switch (name) {
      'supply' => ['+', '−'],
      'coil' => ['A1', 'A2'],
      'motor-dc' || 'fan' || 'buzzer' => ['+', '−'],
      'fuse-holder' => ['1', '2'],
      'auxiliary-no' => ['13', '14'],
      'auxiliary-nc' => ['21', '22'],
      'terminal5' => ['1', '2', '3', '4', 'PE', '1', '2', '3', '4', 'PE'],
      'motor3' => ['U1', 'V1', 'W1', 'U2', 'V2', 'W2'],
      'contactor1' => ['1L1', '2T1', 'A1', 'A2'],
      'contactor3' => ['1L1', '3L2', '5L3', '2T1', '4T2', '6T3', 'A1', 'A2'],
      'breaker3' ||
      'isolator3' ||
      'overload' => ['1L1', '3L2', '5L3', '2T1', '4T2', '6T3'],
      'breaker4' ||
      'isolator4' => ['1L1', '3L2', '5L3', 'N', '2T1', '4T2', '6T3', 'N'],
      _ => List<String>.filled(ports.length, ''),
    };
    for (var i = 0; i < ports.length; i++) {
      if (labels[i].isEmpty) continue;
      final p = ports[i];
      text(
        c,
        labels[i],
        p +
            Offset(
              0,
              name == 'motor3'
                  ? (p.dy < h * .5 ? -h * .035 : h * .035)
                  : (p.dy < h * .5 ? h * .052 : -h * .055),
            ),
        font: math.min(8, w * .065),
        z: name == 'motor3'
            ? h * .34 + 34
            : name.startsWith('contactor') || name == 'overload'
            ? 34
            : 29,
        color:
            name.startsWith('contactor') ||
                name == 'overload' ||
                name == 'coil' ||
                name == 'fuse-holder' ||
                name.startsWith('auxiliary-') ||
                name == 'motor3'
            ? Colors.white
            : graphite,
      );
    }
  }

  @override
  void paint(Canvas c, Size size) {
    name = F18PhysicalPlateAssets.models[v.modelType.toLowerCase()]!;
    final g = F18PhysicalPlateAssets._geometry[name]!;
    final dims = g['size'] as List;
    design = Size((dims[0] as num).toDouble(), (dims[1] as num).toDouble());
    ports = (g['ports'] as List)
        .map((p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()))
        .toList();
    final image = F18PhysicalPlateAssets
        ._images['$name-${v.perspective ? 'palette' : 'front'}']!;
    final scale = math.min(
      size.width / design.width,
      size.height / design.height,
    );
    c.save();
    c.translate(
      (size.width - design.width * scale) / 2,
      (size.height - design.height * scale) / 2,
    );
    c.scale(scale);
    c.drawImageRect(
      image,
      Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
      Offset.zero & design,
      Paint()..filterQuality = FilterQuality.medium,
    );
    overlays(c);
    portLabels(c);
    c.restore();
  }

  @override
  bool shouldRepaint(_PhysicalPlatePainter old) =>
      old.v.modelType != v.modelType ||
      old.v.size != v.size ||
      old.v.perspective != v.perspective ||
      old.handle != handle ||
      old.v.closed != v.closed ||
      old.v.tripped != v.tripped ||
      old.v.pressed != v.pressed ||
      old.v.energized != v.energized ||
      old.v.actuated != v.actuated ||
      (old.v.phase != v.phase &&
          {'motor3', 'motor-dc', 'fan'}.contains(
            F18PhysicalPlateAssets.models[v.modelType.toLowerCase()],
          )) ||
      (old.v.voltageV != v.voltageV &&
          F18PhysicalPlateAssets.models[v.modelType.toLowerCase()] == 'lamp') ||
      old.v.ratedCurrentA != v.ratedCurrentA ||
      old.v.showTerminals != v.showTerminals;
}
