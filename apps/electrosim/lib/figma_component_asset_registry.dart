import 'package:flutter/foundation.dart';

@immutable
final class FigmaComponentTerminalAnchor {
  const FigmaComponentTerminalAnchor({
    required this.label,
    required this.x,
    required this.y,
  }) : assert(x >= 0 && x <= 1),
       assert(y >= 0 && y <= 1);

  final String label;
  final double x;
  final double y;
}

enum FigmaComponentVisualState { normal, active, selected, fault }

@immutable
final class FigmaComponentAssetSpec {
  const FigmaComponentAssetSpec({
    required this.modelType,
    required this.displayName,
    required this.assetBaseName,
    this.nativeWidth,
    this.nativeHeight,
    this.terminals = const <FigmaComponentTerminalAnchor>[],
    this.figmaNodeId,
    this.assetReady = false,
  });

  final String modelType;
  final String displayName;

  /// File stem only. Production SVGs are stored under
  /// `assets/figma/components/{assetBaseName}__{state}.svg`.
  final String assetBaseName;

  /// These values must come from the real Figma export. They remain null
  /// while Figma MCP access is unavailable.
  final double? nativeWidth;
  final double? nativeHeight;

  /// Electrical anchors normalized to the real exported artwork bounds.
  /// This list remains empty until the corresponding Figma node is read.
  final List<FigmaComponentTerminalAnchor> terminals;

  /// Must remain null until a real Figma node ID has been read from the file.
  final String? figmaNodeId;

  /// Turns true only after the expected production SVGs have been exported
  /// and added to the Flutter asset bundle.
  final bool assetReady;

  double? get aspectRatio {
    final double? width = nativeWidth;
    final double? height = nativeHeight;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return width / height;
  }

  String assetPath(FigmaComponentVisualState state) =>
      'assets/figma/components/${assetBaseName}__${state.name}.svg';
}

abstract final class ElectroSimFigmaComponentRegistry {
  static const String sourceFileKey = 'TyYIfxMB0jPVIEcJPGsOwI';

  /// Inventory only. Geometry, node IDs and readiness are intentionally
  /// unknown until the real Figma file can be read again.
  static const Map<String, FigmaComponentAssetSpec> byModel =
      <String, FigmaComponentAssetSpec>{
        'dc_voltage_source': FigmaComponentAssetSpec(
          modelType: 'dc_voltage_source',
          displayName: 'Source CC 24 V',
          assetBaseName: 'source_dc_24v',
        ),
        'switch': FigmaComponentAssetSpec(
          modelType: 'switch',
          displayName: 'Interrupteur NO',
          assetBaseName: 'switch_no',
        ),
        'push_button_no': FigmaComponentAssetSpec(
          modelType: 'push_button_no',
          displayName: 'Bouton-poussoir NO',
          assetBaseName: 'push_button_no',
        ),
        'lamp': FigmaComponentAssetSpec(
          modelType: 'lamp',
          displayName: 'Lampe',
          assetBaseName: 'lamp',
        ),
        'resistor': FigmaComponentAssetSpec(
          modelType: 'resistor',
          displayName: 'Résistance',
          assetBaseName: 'resistor',
        ),
        'breaker_dc': FigmaComponentAssetSpec(
          modelType: 'breaker_dc',
          displayName: 'Disjoncteur',
          assetBaseName: 'breaker_dc',
        ),
        'fuse_dc': FigmaComponentAssetSpec(
          modelType: 'fuse_dc',
          displayName: 'Fusible',
          assetBaseName: 'fuse_dc',
        ),
        'motor_dc': FigmaComponentAssetSpec(
          modelType: 'motor_dc',
          displayName: 'Moteur CC',
          assetBaseName: 'motor_dc',
        ),
        'fan_dc': FigmaComponentAssetSpec(
          modelType: 'fan_dc',
          displayName: 'Ventilateur CC',
          assetBaseName: 'fan_dc',
        ),
        'relay_coil': FigmaComponentAssetSpec(
          modelType: 'relay_coil',
          displayName: 'Bobine relais',
          assetBaseName: 'relay_coil',
        ),
        'buzzer': FigmaComponentAssetSpec(
          modelType: 'buzzer',
          displayName: 'Buzzer',
          assetBaseName: 'buzzer',
        ),
      };
}
