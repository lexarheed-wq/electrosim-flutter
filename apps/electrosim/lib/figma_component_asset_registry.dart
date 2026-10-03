import 'package:flutter/foundation.dart';

@immutable
final class FigmaComponentTerminalAnchor {
  const FigmaComponentTerminalAnchor({
    required this.label,
    required this.x,
    required this.y,
  })  : assert(x >= 0 && x <= 1),
        assert(y >= 0 && y <= 1);

  final String label;
  final double x;
  final double y;
}

enum FigmaComponentVisualState {
  normal,
  active,
  selected,
  fault,
}

@immutable
final class FigmaComponentAssetSpec {
  const FigmaComponentAssetSpec({
    required this.modelType,
    required this.displayName,
    required this.assetBaseName,
    required this.nativeWidth,
    required this.nativeHeight,
    required this.terminals,
    this.figmaNodeId,
  });

  final String modelType;
  final String displayName;

  /// File stem only. Actual files are expected under
  /// assets/figma/components/<assetBaseName>__<state>.svg.
  final String assetBaseName;

  /// Native artboard size exported from Figma.
  final double nativeWidth;
  final double nativeHeight;

  /// Electrical anchors are normalized to the exported artwork bounds.
  final List<FigmaComponentTerminalAnchor> terminals;

  /// Must remain null until a real Figma node ID has been read from the file.
  final String? figmaNodeId;

  double get aspectRatio => nativeWidth / nativeHeight;

  String assetPath(FigmaComponentVisualState state) =>
      'assets/figma/components/${assetBaseName}__${state.name}.svg';
}

abstract final class ElectroSimFigmaComponentRegistry {
  static const String sourceFileKey = 'TyYIfxMB0jPVIEcJPGsOwI';

  /// Node IDs are intentionally not guessed. They are filled only after
  /// successful Figma MCP discovery.
  static const Map<String, FigmaComponentAssetSpec> byModel =
      <String, FigmaComponentAssetSpec>{
    'dc_voltage_source': FigmaComponentAssetSpec(
      modelType: 'dc_voltage_source',
      displayName: 'Source CC 24 V',
      assetBaseName: 'source_dc_24v',
      nativeWidth: 160,
      nativeHeight: 110,
      terminals: <FigmaComponentTerminalAnchor>[
        FigmaComponentTerminalAnchor(label: '+', x: 0.06, y: 0.50),
        FigmaComponentTerminalAnchor(label: '−', x: 0.94, y: 0.50),
      ],
    ),
    'switch': FigmaComponentAssetSpec(
      modelType: 'switch',
      displayName: 'Interrupteur NO',
      assetBaseName: 'switch_no',
      nativeWidth: 150,
      nativeHeight: 100,
      terminals: <FigmaComponentTerminalAnchor>[
        FigmaComponentTerminalAnchor(label: '1', x: 0.06, y: 0.50),
        FigmaComponentTerminalAnchor(label: '2', x: 0.94, y: 0.50),
      ],
    ),
    'push_button_no': FigmaComponentAssetSpec(
      modelType: 'push_button_no',
      displayName: 'Bouton-poussoir NO',
      assetBaseName: 'push_button_no',
      nativeWidth: 150,
      nativeHeight: 110,
      terminals: <FigmaComponentTerminalAnchor>[
        FigmaComponentTerminalAnchor(label: '13', x: 0.06, y: 0.50),
        FigmaComponentTerminalAnchor(label: '14', x: 0.94, y: 0.50),
      ],
    ),
    'lamp': FigmaComponentAssetSpec(
      modelType: 'lamp',
      displayName: 'Lampe',
      assetBaseName: 'lamp',
      nativeWidth: 150,
      nativeHeight: 120,
      terminals: <FigmaComponentTerminalAnchor>[
        FigmaComponentTerminalAnchor(label: 'A', x: 0.06, y: 0.50),
        FigmaComponentTerminalAnchor(label: 'B', x: 0.94, y: 0.50),
      ],
    ),
    'resistor': FigmaComponentAssetSpec(
      modelType: 'resistor',
      displayName: 'Résistance',
      assetBaseName: 'resistor',
      nativeWidth: 160,
      nativeHeight: 84,
      terminals: <FigmaComponentTerminalAnchor>[
        FigmaComponentTerminalAnchor(label: '1', x: 0.04, y: 0.50),
        FigmaComponentTerminalAnchor(label: '2', x: 0.96, y: 0.50),
      ],
    ),
    'breaker_dc': FigmaComponentAssetSpec(
      modelType: 'breaker_dc',
      displayName: 'Disjoncteur',
      assetBaseName: 'breaker_dc',
      nativeWidth: 140,
      nativeHeight: 150,
      terminals: <FigmaComponentTerminalAnchor>[
        FigmaComponentTerminalAnchor(label: 'IN', x: 0.06, y: 0.50),
        FigmaComponentTerminalAnchor(label: 'OUT', x: 0.94, y: 0.50),
      ],
    ),
    'fuse_dc': FigmaComponentAssetSpec(
      modelType: 'fuse_dc',
      displayName: 'Fusible',
      assetBaseName: 'fuse_dc',
      nativeWidth: 160,
      nativeHeight: 84,
      terminals: <FigmaComponentTerminalAnchor>[
        FigmaComponentTerminalAnchor(label: 'IN', x: 0.04, y: 0.50),
        FigmaComponentTerminalAnchor(label: 'OUT', x: 0.96, y: 0.50),
      ],
    ),
    'motor_dc': FigmaComponentAssetSpec(
      modelType: 'motor_dc',
      displayName: 'Moteur CC',
      assetBaseName: 'motor_dc',
      nativeWidth: 160,
      nativeHeight: 120,
      terminals: <FigmaComponentTerminalAnchor>[
        FigmaComponentTerminalAnchor(label: '+', x: 0.06, y: 0.50),
        FigmaComponentTerminalAnchor(label: '−', x: 0.94, y: 0.50),
      ],
    ),
    'fan_dc': FigmaComponentAssetSpec(
      modelType: 'fan_dc',
      displayName: 'Ventilateur CC',
      assetBaseName: 'fan_dc',
      nativeWidth: 160,
      nativeHeight: 120,
      terminals: <FigmaComponentTerminalAnchor>[
        FigmaComponentTerminalAnchor(label: '+', x: 0.06, y: 0.50),
        FigmaComponentTerminalAnchor(label: '−', x: 0.94, y: 0.50),
      ],
    ),
    'relay_coil': FigmaComponentAssetSpec(
      modelType: 'relay_coil',
      displayName: 'Bobine relais',
      assetBaseName: 'relay_coil',
      nativeWidth: 150,
      nativeHeight: 105,
      terminals: <FigmaComponentTerminalAnchor>[
        FigmaComponentTerminalAnchor(label: 'A1', x: 0.06, y: 0.50),
        FigmaComponentTerminalAnchor(label: 'A2', x: 0.94, y: 0.50),
      ],
    ),
    'buzzer': FigmaComponentAssetSpec(
      modelType: 'buzzer',
      displayName: 'Buzzer',
      assetBaseName: 'buzzer',
      nativeWidth: 150,
      nativeHeight: 110,
      terminals: <FigmaComponentTerminalAnchor>[
        FigmaComponentTerminalAnchor(label: '+', x: 0.06, y: 0.50),
        FigmaComponentTerminalAnchor(label: '−', x: 0.94, y: 0.50),
      ],
    ),
  };
}
