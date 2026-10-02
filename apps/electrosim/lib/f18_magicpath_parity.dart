import 'dart:math' as math;

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';

import 'f18_component_archetypes.dart';

@immutable
final class F18MagicPathReference {
  const F18MagicPathReference({
    required this.name,
    required this.componentId,
    required this.revisionId,
    required this.size,
  });

  final String name;
  final String componentId;
  final String revisionId;
  final Size size;
}

abstract final class F18MagicPathReferences {
  static const String projectId = '456415562449448960';
  static const String projectName =
      'ElectroSim F18 — Professional Design System';

  static const F18MagicPathReference homeDesktop = F18MagicPathReference(
    name: 'Reference/Home/Desktop',
    componentId: '456415638643150848',
    revisionId: '456415638643150849',
    size: Size(1440, 900),
  );

  static const F18MagicPathReference workspaceDesktop =
      F18MagicPathReference(
    name: 'Reference/Workspace/Desktop',
    componentId: '456417407095963648',
    revisionId: '456417407095963649',
    size: Size(1440, 900),
  );

  static const F18MagicPathReference workspaceCompact =
      F18MagicPathReference(
    name: 'Reference/Workspace/Compact',
    componentId: '456417656019521536',
    revisionId: '456417656019521537',
    size: Size(390, 844),
  );

  static const F18MagicPathReference troubleshootingStudent =
      F18MagicPathReference(
    name: 'Reference/Troubleshooting/Student',
    componentId: '456418021750222848',
    revisionId: '456418021750222849',
    size: Size(820, 1180),
  );

  static const F18MagicPathReference wireArchitecture =
      F18MagicPathReference(
    name: 'Reference/Wire Architecture G2A',
    componentId: '456432394111688704',
    revisionId: '456432394111688705',
    size: Size(1440, 1100),
  );
}

@immutable
final class F18ViewportFitResult {
  const F18ViewportFitResult({
    required this.scale,
    required this.translation,
    required this.worldBounds,
  });

  final double scale;
  final Offset translation;
  final Rect worldBounds;
}

/// Fits the complete committed F18 scene, including routed wire bends, inside
/// the visible Canvas region. This is intentionally stricter than the legacy
/// viewport clamp, which only guarantees that part of an element stays visible.
abstract final class F18MagicPathViewportFitter {
  static const double defaultPadding = 48;
  static const double routingSafetyMargin = 18;
  static const double maximumInitialScale = 1;
  static const double minimumInitialScale = .45;

  static Rect contentBounds({
    required CircuitState circuit,
    required CircuitVisualLayout layout,
  }) {
    final CircuitGeometryIndex geometry =
        CircuitGeometryIndex.build(circuit, layout);
    Rect? bounds;

    void includeRect(Rect rect) {
      bounds = bounds == null ? rect : bounds!.expandToInclude(rect);
    }

    void includePoint(Offset point) {
      includeRect(Rect.fromCircle(center: point, radius: 1));
    }

    for (final Rect rect in geometry.elementRects.values) {
      includeRect(rect);
    }
    for (final Connection connection in circuit.connections) {
      final Offset? start =
          geometry.terminalPositions[connection.fromTerminalId];
      final Offset? end = geometry.terminalPositions[connection.toTerminalId];
      if (start == null || end == null) {
        continue;
      }
      includePoint(start);
      for (final Offset point in layout.routeFor(connection.id.value)) {
        includePoint(point);
      }
      includePoint(end);
    }

    return (bounds ?? Rect.zero).inflate(routingSafetyMargin);
  }

  static F18ViewportFitResult fit({
    required CircuitState circuit,
    required CircuitVisualLayout layout,
    required Size viewportSize,
    double padding = defaultPadding,
    double minScale = minimumInitialScale,
    double maxScale = maximumInitialScale,
    double horizontalAlignment = .5,
    double verticalAlignment = .32,
  }) {
    final Rect worldBounds = contentBounds(circuit: circuit, layout: layout);
    if (viewportSize.isEmpty || worldBounds.isEmpty) {
      return F18ViewportFitResult(
        scale: maxScale,
        translation: Offset.zero,
        worldBounds: worldBounds,
      );
    }

    final double availableWidth =
        math.max(1, viewportSize.width - padding * 2);
    final double availableHeight =
        math.max(1, viewportSize.height - padding * 2);
    final double widthScale = availableWidth / worldBounds.width;
    final double heightScale = availableHeight / worldBounds.height;
    final double scale = math
        .min(maxScale, math.min(widthScale, heightScale))
        .clamp(minScale, maxScale)
        .toDouble();
    final double scaledWidth = worldBounds.width * scale;
    final double scaledHeight = worldBounds.height * scale;
    final double freeWidth = math.max(0, viewportSize.width - scaledWidth);
    final double freeHeight = math.max(0, viewportSize.height - scaledHeight);
    final double x = freeWidth * horizontalAlignment;
    final double y = freeHeight * verticalAlignment;
    final Offset translation = Offset(
      x - worldBounds.left * scale,
      y - worldBounds.top * scale,
    );

    return F18ViewportFitResult(
      scale: scale,
      translation: translation,
      worldBounds: worldBounds,
    );
  }

  static Rect screenBounds(F18ViewportFitResult fit) {
    return Rect.fromLTRB(
      fit.worldBounds.left * fit.scale + fit.translation.dx,
      fit.worldBounds.top * fit.scale + fit.translation.dy,
      fit.worldBounds.right * fit.scale + fit.translation.dx,
      fit.worldBounds.bottom * fit.scale + fit.translation.dy,
    );
  }
}

String f18ReferenceDesignator(String elementId, String modelType) {
  final String id = elementId.toLowerCase();
  final String type = modelType.toLowerCase();
  if (id.contains('source') || type.contains('voltage_source')) return 'G1';
  if (id.contains('breaker') || type.contains('breaker')) return 'QF1';
  if (id.contains('fuse') || type.contains('fuse')) return 'F1';
  if (id.contains('switch') || type.contains('switch')) return 'S1';
  if (id.contains('push') || type.contains('push_button')) return 'S2';
  if (id.contains('lamp') || type.contains('lamp')) return 'H1';
  if (id.contains('motor') || type.contains('motor')) return 'M1';
  if (id.contains('meter') || type.contains('meter')) return 'X1';
  final String compact = elementId
      .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
      .toUpperCase();
  return compact.length <= 5 ? compact : compact.substring(0, 5);
}

String f18DisplayNameForModel(String modelType) {
  final String type = modelType.toLowerCase();
  if (type.contains('dc_voltage_source') || type == 'source_dc') {
    return 'Source CC';
  }
  if (type.contains('ac_voltage_source') || type == 'source_ac') {
    return 'Source CA';
  }
  if (type.contains('breaker') || type.contains('disjoncteur')) {
    return 'Disjoncteur';
  }
  if (type.contains('fuse') || type.contains('fusible')) {
    return 'Fusible';
  }
  if (type.contains('push_button') || type.contains('bouton')) {
    return 'Bouton-poussoir';
  }
  if (type.contains('switch') || type.contains('interrupteur')) {
    return 'Interrupteur';
  }
  if (type.contains('relay') || type.contains('relais')) {
    return 'Relais';
  }
  if (type.contains('contactor') || type.contains('contacteur')) {
    return 'Contacteur';
  }
  if (type.contains('lamp') || type.contains('lampe')) {
    return 'Lampe';
  }
  if (type.contains('resistor') || type.contains('resistance')) {
    return 'Résistance';
  }
  if (type.contains('motor') || type.contains('moteur')) {
    return 'Moteur';
  }
  if (type.contains('fan') || type.contains('ventilateur')) {
    return 'Ventilateur';
  }
  if (type.contains('voltmeter')) {
    return 'Voltmètre';
  }
  if (type.contains('ammeter')) {
    return 'Ampèremètre';
  }
  if (type.contains('meter') || type.contains('multimeter')) {
    return 'Appareil de mesure';
  }
  if (type.contains('inverter') || type.contains('onduleur')) {
    return 'Onduleur';
  }
  if (type.contains('pv') || type.contains('solar')) {
    return 'Module PV';
  }
  return modelType
      .replaceAll('_', ' ')
      .split(' ')
      .where((String part) => part.isNotEmpty)
      .map(
        (String part) => '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}

/// Canvas renderer used only by the F18 product routes. Labels are rendered in
/// a dedicated lower band instead of on top of the electrical symbol, which
/// prevents the raw model identifier from obscuring the device drawing.
void paintF18MagicPathCanvasElement(
  Canvas canvas,
  Rect screenRect,
  String elementId,
  String modelType,
  bool source,
  bool selected,
  double viewportScale,
) {
  final double labelHeight =
      (16 * viewportScale).clamp(12, 18).toDouble();
  final Rect bodyRect = Rect.fromLTRB(
    screenRect.left + 4,
    screenRect.top + 2,
    screenRect.right - 4,
    math.max(screenRect.top + 28, screenRect.bottom - labelHeight - 5),
  );

  if (selected) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        screenRect.inflate(4),
        const Radius.circular(ElectroSimRadii.panel),
      ),
      Paint()
        ..color = ElectroSimColors.focus.withValues(alpha: .16)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        screenRect.inflate(3),
        const Radius.circular(ElectroSimRadii.panel),
      ),
      Paint()
        ..color = ElectroSimColors.focus
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  paintF18ElectricalArchetype(
    canvas,
    bodyRect,
    modelType,
    source ? ElectroSimColors.primaryStrong : ElectroSimColors.primary,
    drawTerminals: false,
  );

  final TextPainter label = TextPainter(
    text: TextSpan(
      text: f18ReferenceDesignator(elementId, modelType),
      style: TextStyle(
        color: ElectroSimColors.textPrimary,
        fontSize: (11 * viewportScale).clamp(9, 12).toDouble(),
        fontWeight: FontWeight.w600,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
    textAlign: TextAlign.center,
  )..layout(maxWidth: math.max(36, screenRect.width - 8).toDouble());
  label.paint(
    canvas,
    Offset(
      screenRect.center.dx - label.width / 2,
      screenRect.bottom - label.height - 1,
    ),
  );
}


class F18CircuitZoneOverlay extends StatelessWidget {
  const F18CircuitZoneOverlay({
    super.key,
    required this.circuit,
    required this.layout,
    required this.viewport,
    required this.title,
    this.horizontalPadding = 26,
    this.verticalPadding = 26,
  });

  final CircuitState circuit;
  final CircuitVisualLayout layout;
  final ViewportController viewport;
  final String title;
  final double horizontalPadding;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: viewport,
        builder: (BuildContext context, Widget? child) {
          final Rect base = F18MagicPathViewportFitter.contentBounds(
            circuit: circuit,
            layout: layout,
          );
          final Rect world = Rect.fromLTRB(
            base.left - horizontalPadding,
            base.top - verticalPadding,
            base.right + horizontalPadding,
            base.bottom + verticalPadding,
          );
          final Rect screen = Rect.fromLTRB(
            world.left * viewport.scale + viewport.translation.dx,
            world.top * viewport.scale + viewport.translation.dy,
            world.right * viewport.scale + viewport.translation.dx,
            world.bottom * viewport.scale + viewport.translation.dy,
          );
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned.fromRect(
                rect: screen,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFD7E0EA),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
              Positioned(
                left: screen.left + 18,
                top: screen.top + 12,
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF7B8DA3),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .9,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class F18CanvasToolbar extends StatelessWidget {
  const F18CanvasToolbar({
    super.key,
    required this.onRecenter,
    required this.onStatus,
  });

  final VoidCallback onRecenter;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ElectroSimColors.surfaceElevated,
      elevation: 2,
      borderRadius: BorderRadius.circular(ElectroSimRadii.compact),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD7E0EA)),
          borderRadius: BorderRadius.circular(ElectroSimRadii.compact),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              tooltip: 'Annuler',
              onPressed: () => onStatus('Historique : aucune action à annuler.'),
              iconSize: 17,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              tooltip: 'Rétablir',
              onPressed: () => onStatus('Historique : aucune action à rétablir.'),
              iconSize: 17,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.redo),
            ),
            const SizedBox(
              height: 22,
              child: VerticalDivider(width: 10),
            ),
            IconButton(
              tooltip: 'Recentrer',
              onPressed: onRecenter,
              iconSize: 17,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.center_focus_strong),
            ),
            const SizedBox(
              height: 22,
              child: VerticalDivider(width: 10),
            ),
            TextButton.icon(
              onPressed: () => onStatus(
                'Mode câblage : sélectionnez deux bornes compatibles.',
              ),
              icon: const Icon(Icons.cable, size: 16),
              label: const Text('Câbler'),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                foregroundColor: ElectroSimColors.primary,
                backgroundColor: const Color(0xFFEFF4FF),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class F18SelectionToolbar extends StatelessWidget {
  const F18SelectionToolbar({
    super.key,
    required this.onRotate,
    required this.onDelete,
  });

  final VoidCallback? onRotate;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ElectroSimColors.surfaceElevated,
      elevation: 2,
      borderRadius: BorderRadius.circular(ElectroSimRadii.compact),
      child: Container(
        height: 42,
        padding: const EdgeInsets.only(left: 12, right: 4),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD7E0EA)),
          borderRadius: BorderRadius.circular(ElectroSimRadii.compact),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              '1 sélection',
              style: TextStyle(
                color: ElectroSimColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(
              height: 22,
              child: VerticalDivider(width: 14),
            ),
            IconButton(
              key: const Key('workspace-rotate-action'),
              tooltip: 'Rotation 90°',
              onPressed: onRotate,
              iconSize: 17,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.rotate_right_outlined),
            ),
            IconButton(
              key: const Key('workspace-delete-action'),
              tooltip: 'Supprimer la sélection',
              onPressed: onDelete,
              iconSize: 16,
              visualDensity: VisualDensity.compact,
              color: ElectroSimColors.danger,
              icon: const Icon(Icons.delete_outline),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text(
                'Supprimer',
                style: TextStyle(
                  color: ElectroSimColors.danger,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class F18ZoomChip extends StatelessWidget {
  const F18ZoomChip({
    super.key,
    required this.viewport,
  });

  final ViewportController viewport;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewport,
      builder: (BuildContext context, Widget? child) {
        final int percent = (viewport.scale * 100).round();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: ElectroSimColors.surfaceElevated,
            border: Border.all(color: const Color(0xFFD7E0EA)),
            borderRadius: BorderRadius.circular(ElectroSimRadii.compact),
          ),
          child: Text(
            '$percent%',
            style: const TextStyle(
              color: ElectroSimColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }
}


class F18TroubleshootingProgressCard extends StatelessWidget {
  const F18TroubleshootingProgressCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: ElectroSimColors.surfaceElevated,
        border: Border.all(color: const Color(0xFFD7E0EA)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'PROGRESSION',
                  style: TextStyle(
                    color: ElectroSimColors.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .9,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Étape 2 / 3',
                  style: TextStyle(
                    color: ElectroSimColors.info,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Méthode de diagnostic',
            style: TextStyle(
              color: ElectroSimColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              _F18ProgressStep(
                label: 'Observer',
                icon: Icons.visibility_outlined,
                state: _F18ProgressState.complete,
              ),
              _F18ProgressConnector(active: true),
              _F18ProgressStep(
                label: 'Mesurer',
                icon: Icons.straighten_outlined,
                state: _F18ProgressState.active,
              ),
              _F18ProgressConnector(active: false),
              _F18ProgressStep(
                label: 'Conclure',
                icon: Icons.fact_check_outlined,
                state: _F18ProgressState.pending,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _F18ProgressState { complete, active, pending }

class _F18ProgressStep extends StatelessWidget {
  const _F18ProgressStep({
    required this.label,
    required this.icon,
    required this.state,
  });

  final String label;
  final IconData icon;
  final _F18ProgressState state;

  @override
  Widget build(BuildContext context) {
    final bool active = state != _F18ProgressState.pending;
    return SizedBox(
      width: 70,
      child: Column(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: state == _F18ProgressState.complete
                  ? const Color(0xFFECFDF3)
                  : state == _F18ProgressState.active
                      ? const Color(0xFFEFF6FF)
                      : const Color(0xFFF8FAFC),
              shape: BoxShape.circle,
              border: Border.all(
                color: active
                    ? (state == _F18ProgressState.complete
                        ? ElectroSimColors.success
                        : ElectroSimColors.info)
                    : const Color(0xFFD7E0EA),
              ),
            ),
            child: Icon(
              state == _F18ProgressState.complete ? Icons.check : icon,
              size: 16,
              color: active
                  ? (state == _F18ProgressState.complete
                      ? ElectroSimColors.success
                      : ElectroSimColors.info)
                  : ElectroSimColors.textDisabled,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: active
                  ? ElectroSimColors.textPrimary
                  : ElectroSimColors.textDisabled,
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _F18ProgressConnector extends StatelessWidget {
  const _F18ProgressConnector({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 1,
        margin: const EdgeInsets.only(bottom: 20),
        color: active
            ? ElectroSimColors.info
            : const Color(0xFFD7E0EA),
      ),
    );
  }
}
