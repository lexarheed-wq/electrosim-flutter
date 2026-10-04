import 'package:flutter/material.dart';

import 'f18_component_archetypes.dart';
import 'f18_v1_component_visuals.dart';

/// Legacy generated assets are retained in the repository only for audit/history.
/// The five Point 5 pilot families are rendered from the V1 C31 visual language.
@Deprecated('Point 5 V1 parity uses F18V1PilotVisuals instead.')
abstract final class F18AdobeComponentAssets {
  static const String _root = 'assets/components/adobe';

  static const Map<String, String> _byModelType = <String, String>{
    'dc_voltage_source': '$_root/power24v.png',
    'voltage_source': '$_root/power24v.png',
    'switch': '$_root/switch.png',
    'switch_spst': '$_root/switch.png',
    'lamp': '$_root/lamp.png',
    'breaker_dc': '$_root/breaker.png',
    'breaker_ac1': '$_root/breaker.png',
    'breaker': '$_root/breaker.png',
    'push_button_no': '$_root/push_button_no.png',
  };

  static String? pathForModelType(String modelType) =>
      _byModelType[modelType.toLowerCase()];

  static bool hasAsset(String modelType) =>
      pathForModelType(modelType) != null;

  static Set<String> get coveredModelTypes =>
      Set<String>.unmodifiable(_byModelType.keys);
}

/// Shared representation entry point used by palette, drag feedback and board.
///
/// Despite its historical name, the wrapper no longer renders the generated
/// Adobe assets for the Point 5 pilot. Those models are painted natively from
/// the V1 C31 visual contract so the same geometry remains crisp at every zoom.
class F18ComponentAssetVisual extends StatelessWidget {
  const F18ComponentAssetVisual({
    super.key,
    required this.modelType,
    required this.size,
    this.active = true,
    this.energized = false,
    this.closed,
    this.tripped = false,
    this.pressed = false,
    this.animationValue = 0,
    this.showTerminals = true,
  });

  final String modelType;
  final Size size;
  final bool active;
  final bool energized;
  final bool? closed;
  final bool tripped;
  final bool pressed;
  final double animationValue;
  final bool showTerminals;

  @override
  Widget build(BuildContext context) {
    if (F18V1PilotVisuals.supports(modelType)) {
      final String type = modelType.toLowerCase();
      final bool defaultClosed =
          type == 'breaker_dc' || type == 'breaker_ac1' || type == 'breaker';
      return F18V1ComponentVisual(
        modelType: modelType,
        size: size,
        enabled: active,
        energized: energized,
        closed: closed ?? defaultClosed,
        tripped: tripped,
        pressed: pressed,
        animationValue: animationValue,
        showTerminals: showTerminals,
      );
    }

    return F18ComponentIdentityVisual(
      modelType: modelType,
      size: size,
      active: active,
    );
  }
}
