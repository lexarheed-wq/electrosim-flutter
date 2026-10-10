import 'dart:math' as math;
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';

/// Indicative generic mounting envelopes, not manufacturer-certified CAD.
abstract final class IndustrialEquipmentProfile {
  static bool dinMountable(String type) => const {
    'breaker',
    'breaker_dc',
    'breaker_ac1',
    'rcd_2p_ac1',
    'breaker_3p',
    'breaker_4p',
    'contactor_ac1',
    'contactor_3p',
    'relay_coil',
    'isolator_3p',
    'isolator_4p',
    'terminal_block_5',
    'thermal_overload_3p',
    'dc_voltage_source',
  }.contains(type);
  static CabinetSurface defaultSurface(String type) {
    if (type.contains('motor') ||
        type.contains('pump') ||
        type.contains('fan') ||
        type == 'pv_array' ||
        type.contains('generator')) {
      return CabinetSurface.exterior;
    }
    if (type.contains('button') || type.contains('indicator')) {
      return CabinetSurface.door;
    }
    return CabinetSurface.interior;
  }

  static CabinetMount mounting(String type, Size size) => CabinetMount(
    surface: defaultSurface(type),
    anchorOffset: dinMountable(type)
        ? Offset(0, size.height * .18)
        : Offset.zero,
    depthMm: dinMountable(type)
        ? 70
        : defaultSurface(type) == CabinetSurface.exterior
        ? 140
        : 45,
  );
  static Offset rotateAnchor(Offset p, int turns) => switch (turns % 4) {
    0 => p,
    1 => Offset(-p.dy, p.dx),
    2 => Offset(-p.dx, -p.dy),
    _ => Offset(p.dy, -p.dx),
  };
  static String surfaceLabel(CabinetSurface surface) => switch (surface) {
    CabinetSurface.interior => 'Intérieur',
    CabinetSurface.door => 'Porte',
    CabinetSurface.exterior => 'Extérieur',
  };
}

class IndustrialCabinetInspector extends StatefulWidget {
  const IndustrialCabinetInspector({
    super.key,
    required this.cabinet,
    required this.validate,
    this.selectedId,
    this.selectedModelType,
    this.selectedSize,
    this.selectedFixture,
  });
  final CabinetLayout cabinet;
  final String? selectedId, selectedModelType;
  final Size? selectedSize;
  final CabinetFixture? selectedFixture;
  final String? Function(CabinetLayout) validate;
  @override
  State<IndustrialCabinetInspector> createState() =>
      _IndustrialCabinetInspectorState();
}

class _IndustrialCabinetInspectorState
    extends State<IndustrialCabinetInspector> {
  late final TextEditingController width,
      height,
      depth,
      fixtureWidth,
      fixtureHeight;
  late CabinetSurface surface;
  String? error;
  @override
  void initState() {
    super.initState();
    final e = widget.cabinet.envelope;
    width = TextEditingController(
      text: (e?.widthMm ?? 1200).toStringAsFixed(0),
    );
    height = TextEditingController(
      text: (e?.heightMm ?? 1000).toStringAsFixed(0),
    );
    depth = TextEditingController(text: (e?.depthMm ?? 300).toStringAsFixed(0));
    fixtureWidth = TextEditingController(
      text: (widget.selectedFixture?.bounds.width ?? 460).toStringAsFixed(0),
    );
    fixtureHeight = TextEditingController(
      text: (widget.selectedFixture?.bounds.height ?? 34).toStringAsFixed(0),
    );
    surface =
        widget.cabinet.mounts[widget.selectedId]?.surface ??
        IndustrialEquipmentProfile.defaultSurface(
          widget.selectedModelType ?? '',
        );
  }

  @override
  void dispose() {
    for (final c in [width, height, depth, fixtureWidth, fixtureHeight]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget number(String name, String key, TextEditingController c) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      key: Key(key),
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: '$name (mm)',
        border: const OutlineInputBorder(),
      ),
    ),
  );
  void apply() {
    try {
      double value(TextEditingController c) =>
          double.tryParse(c.text.replaceAll(',', '.')) ?? double.nan;
      final e = CabinetEnvelope(
        widthMm: value(width),
        heightMm: value(height),
        depthMm: value(depth),
        marginMm: widget.cabinet.envelope?.marginMm ?? 24,
        origin: widget.cabinet.envelope?.origin ?? Offset.zero,
      );
      var cabinet = widget.cabinet.withEnvelope(e);
      if (widget.selectedFixture != null) {
        final f = widget.selectedFixture!;
        cabinet = cabinet.replace(
          f.withBounds(
            f.bounds.topLeft & Size(value(fixtureWidth), value(fixtureHeight)),
          ),
        );
      }
      if (widget.selectedId != null &&
          widget.selectedModelType != null &&
          widget.selectedSize != null) {
        final old =
            cabinet.mounts[widget.selectedId] ??
            IndustrialEquipmentProfile.mounting(
              widget.selectedModelType!,
              widget.selectedSize!,
            );
        cabinet = cabinet.withMount(
          widget.selectedId!,
          CabinetMount(
            surface: surface,
            railId: surface == CabinetSurface.interior ? old.railId : null,
            anchorOffset: old.anchorOffset,
            depthMm: old.depthMm,
          ),
        );
      }
      final problem = widget.validate(cabinet);
      if (problem != null) {
        setState(() => error = problem);
        return;
      }
      Navigator.of(context).pop(cabinet);
    } on ArgumentError {
      setState(
        () => error =
            'Dimensions invalides : utilisez des valeurs positives et une plaque utile suffisante.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Armoire électrique'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enveloppe générique · implantation en millimètres'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [
                for (final preset in [
                  (600, 800, 250),
                  (800, 1000, 300),
                  (1200, 1000, 300),
                ])
                  ActionChip(
                    label: Text('${preset.$1} × ${preset.$2} × ${preset.$3}'),
                    onPressed: () => setState(() {
                      width.text = '${preset.$1}';
                      height.text = '${preset.$2}';
                      depth.text = '${preset.$3}';
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            number('Largeur', 'workspace-cabinet-width', width),
            number('Hauteur', 'workspace-cabinet-height', height),
            number('Profondeur', 'workspace-cabinet-depth', depth),
            if (widget.selectedId != null &&
                widget.selectedModelType != null) ...[
              Text('Montage : ${widget.selectedId}'),
              const SizedBox(height: 8),
              Text(
                'Encombrement générique : ${widget.selectedSize?.width.toStringAsFixed(0)} × ${widget.selectedSize?.height.toStringAsFixed(0)} mm',
              ),
              DropdownButtonFormField<CabinetSurface>(
                key: const Key('workspace-cabinet-surface'),
                initialValue: surface,
                decoration: const InputDecoration(
                  labelText: 'Surface de montage',
                ),
                items: [
                  for (final s in CabinetSurface.values)
                    DropdownMenuItem(
                      value: s,
                      child: Text(IndustrialEquipmentProfile.surfaceLabel(s)),
                    ),
                ],
                onChanged: (s) => setState(() => surface = s ?? surface),
              ),
            ],
            if (widget.selectedFixture != null) ...[
              const SizedBox(height: 12),
              Text('Support : ${widget.selectedFixture!.id}'),
              const SizedBox(height: 8),
              number('Longueur', 'workspace-fixture-width', fixtureWidth),
              number('Largeur', 'workspace-fixture-height', fixtureHeight),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  error!,
                  key: const Key('workspace-cabinet-error'),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Annuler'),
      ),
      FilledButton(
        key: const Key('workspace-cabinet-apply'),
        onPressed: apply,
        child: const Text('Appliquer'),
      ),
    ],
  );
}

class IndustrialCabinetPreview extends StatefulWidget {
  const IndustrialCabinetPreview({
    super.key,
    required this.circuit,
    required this.layout,
  });
  final CircuitState circuit;
  final CircuitVisualLayout layout;
  @override
  State<IndustrialCabinetPreview> createState() =>
      _IndustrialCabinetPreviewState();
}

class _IndustrialCabinetPreviewState extends State<IndustrialCabinetPreview> {
  double yaw = -.38, pitch = -.22;
  @override
  Widget build(BuildContext context) => Dialog(
    child: SizedBox(
      width: 1000,
      height: 680,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Aperçu 3D de l’armoire',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  key: const Key('workspace-preview-reset'),
                  tooltip: 'Réinitialiser la caméra',
                  onPressed: () => setState(() {
                    yaw = -.38;
                    pitch = -.22;
                  }),
                  icon: const Icon(Icons.restart_alt),
                ),
                IconButton(
                  key: const Key('workspace-preview-close'),
                  tooltip: 'Fermer',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Text(
            'Glissez pour tourner · implantation et câblage conservés',
          ),
          Expanded(
            child: GestureDetector(
              onPanUpdate: (d) => setState(() {
                yaw = (yaw + d.delta.dx / 250).clamp(-1.2, 1.2);
                pitch = (pitch + d.delta.dy / 250).clamp(-.75, .3);
              }),
              child: CustomPaint(
                key: const Key('workspace-cabinet-3d-scene'),
                painter: IndustrialCabinetPreviewPainter(
                  circuit: widget.circuit,
                  layout: widget.layout,
                  yaw: yaw,
                  pitch: pitch,
                ),
                size: Size.infinite,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Volumes génériques · vue complémentaire en lecture seule',
            ),
          ),
        ],
      ),
    ),
  );
}

/// Perspective projection of the existing layout: no second circuit or editor.
class IndustrialCabinetPreviewPainter extends CustomPainter {
  IndustrialCabinetPreviewPainter({
    required this.circuit,
    required this.layout,
    required this.yaw,
    required this.pitch,
  });
  final CircuitState circuit;
  final CircuitVisualLayout layout;
  final double yaw, pitch;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF1F5F9),
    );
    final geometry = CircuitGeometryIndex.build(circuit, layout);
    var bounds =
        layout.cabinetLayout.envelope?.bounds ??
        const Rect.fromLTWH(0, 0, 1000, 800);
    for (final r in geometry.elementRects.values) {
      bounds = bounds.expandToInclude(r);
    }
    final depth = layout.cabinetLayout.envelope?.depthMm ?? 300;
    final center = bounds.center;
    final focal = math.max(1800.0, math.max(bounds.width, bounds.height) * 2);
    Offset raw(Offset p, double z) {
      final x = p.dx - center.dx, y = p.dy - center.dy, dz = z - depth / 2;
      final xx = x * math.cos(yaw) + dz * math.sin(yaw);
      final zz = -x * math.sin(yaw) + dz * math.cos(yaw);
      final yy = y * math.cos(pitch) - zz * math.sin(pitch);
      final z2 = y * math.sin(pitch) + zz * math.cos(pitch);
      final perspective = focal / (focal + z2);
      return Offset(xx * perspective, yy * perspective);
    }

    final extentPoints = [
      for (final z in [0.0, depth + 180])
        for (final p in [
          bounds.topLeft,
          bounds.topRight,
          bounds.bottomLeft,
          bounds.bottomRight,
        ])
          raw(p, z),
    ];
    var projected = Rect.fromPoints(extentPoints.first, extentPoints.first);
    for (final p in extentPoints.skip(1)) {
      projected = projected.expandToInclude(Rect.fromPoints(p, p));
    }
    final scale = math.min(
      (size.width - 60) / math.max(1, projected.width),
      (size.height - 60) / math.max(1, projected.height),
    );
    Offset project(Offset p, double z) =>
        Offset(size.width / 2, size.height / 2) +
        (raw(p, z) - projected.center) * scale;
    Path polygon(List<Offset> ps) => Path()..addPolygon(ps, true);
    void box(Rect r, double z, double height, Color color, {String? name}) {
      List<Offset> face(double at) => [
        project(r.topLeft, at),
        project(r.topRight, at),
        project(r.bottomRight, at),
        project(r.bottomLeft, at),
      ];
      final bottom = face(z), top = face(z + height);
      for (final indices in [
        [0, 1],
        [1, 2],
        [2, 3],
        [3, 0],
      ]) {
        final side = [
          bottom[indices[0]],
          bottom[indices[1]],
          top[indices[1]],
          top[indices[0]],
        ];
        canvas.drawPath(
          polygon(side),
          Paint()..color = Color.lerp(color, Colors.black, .25)!,
        );
        canvas.drawPath(
          polygon(side),
          Paint()
            ..color = const Color(0xFF475569)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .7,
        );
      }
      canvas.drawPath(polygon(top), Paint()..color = color);
      canvas.drawPath(
        polygon(top),
        Paint()
          ..color = const Color(0xFF475569)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      if (name != null) {
        final tp = TextPainter(
          text: TextSpan(
            text: name,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 11,
              color: Colors.black,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 120);
        tp.paint(
          canvas,
          project(r.center, z + height) - Offset(tp.width / 2, tp.height / 2),
        );
      }
    }

    final e = layout.cabinetLayout.envelope;
    if (e != null) {
      box(e.bounds, 0, 10, const Color(0xFFB7C2CB));
      box(e.plateBounds, 10, 5, const Color(0xFFE2E8F0));
      // Open cabinet frame exposes the mounting plate and wiring.
      for (final r in [
        Rect.fromLTWH(e.bounds.left, e.bounds.top, 16, e.bounds.height),
        Rect.fromLTWH(e.bounds.right - 16, e.bounds.top, 16, e.bounds.height),
        Rect.fromLTWH(e.bounds.left, e.bounds.top, e.bounds.width, 16),
        Rect.fromLTWH(e.bounds.left, e.bounds.bottom - 16, e.bounds.width, 16),
      ]) {
        box(r, 0, depth, const Color(0xFFCBD5E1));
      }
    }
    for (final f in layout.cabinetLayout.fixtures) {
      box(
        f.bounds,
        18,
        f.kind == CabinetFixtureKind.dinRail ? 8 : 35,
        f.kind == CabinetFixtureKind.dinRail
            ? const Color(0xFF94A3B8)
            : const Color(0xFFD5DCE5),
      );
    }
    final elementDepth = <String, double>{};
    void equipment(String id, String type) {
      final rect = geometry.elementRects[id];
      if (rect == null) return;
      final mount =
          layout.cabinetLayout.mounts[id] ??
          IndustrialEquipmentProfile.mounting(type, layout.sizeOf(id));
      final z = switch (mount.surface) {
        CabinetSurface.interior => 20.0,
        CabinetSurface.door => depth,
        CabinetSurface.exterior => depth + 100.0,
      };
      elementDepth[id] = z + mount.depthMm;
      box(
        rect,
        z,
        mount.depthMm,
        mount.surface == CabinetSurface.exterior
            ? const Color(0xFFAAC0CC)
            : const Color(0xFFF8FAFC),
        name: mount.surface == CabinetSurface.exterior
            ? 'Extérieur · $id'
            : mount.surface == CabinetSurface.door
            ? 'Porte · $id'
            : id,
      );
    }

    for (final s in circuit.sources) {
      equipment(s.id.value, s.modelType);
    }
    for (final c in circuit.components) {
      equipment(
        c.id.value,
        (c.parameters['_visualModelType'] as String?) ?? c.modelType,
      );
    }
    for (final connection in circuit.connections) {
      final a = geometry.terminalPositions[connection.fromTerminalId],
          b = geometry.terminalPositions[connection.toTerminalId];
      if (a == null || b == null) continue;
      final points = [a, ...layout.routeFor(connection.id.value), b];
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final z = i == 0
            ? elementDepth[geometry.terminalOwners[connection
                      .fromTerminalId]] ??
                  50
            : i == points.length - 1
            ? elementDepth[geometry.terminalOwners[connection.toTerminalId]] ??
                  50
            : 50.0;
        final p = project(points[i], z);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF334155)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
  }

  @override
  bool shouldRepaint(covariant IndustrialCabinetPreviewPainter oldDelegate) =>
      oldDelegate.yaw != yaw ||
      oldDelegate.pitch != pitch ||
      !identical(oldDelegate.layout, layout) ||
      !identical(oldDelegate.circuit, circuit);
}
