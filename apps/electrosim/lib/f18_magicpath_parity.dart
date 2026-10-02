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
    final Offset translation = Offset(
      viewportSize.width / 2 - worldBounds.center.dx * scale,
      viewportSize.height / 2 - worldBounds.center.dy * scale,
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
      text: f18DisplayNameForModel(modelType),
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
