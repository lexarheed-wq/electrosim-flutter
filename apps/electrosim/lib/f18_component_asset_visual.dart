import 'package:flutter/material.dart';

import 'f18_component_archetypes.dart';

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

class F18ComponentAssetVisual extends StatelessWidget {
  const F18ComponentAssetVisual({
    super.key,
    required this.modelType,
    required this.size,
    this.active = true,
  });

  final String modelType;
  final Size size;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final String? assetPath =
        F18AdobeComponentAssets.pathForModelType(modelType);
    if (assetPath == null) {
      return F18ComponentIdentityVisual(
        modelType: modelType,
        size: size,
        active: active,
      );
    }

    return SizedBox(
      width: size.width,
      height: size.height,
      child: Opacity(
        opacity: active ? 1 : .42,
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
          semanticLabel: modelType,
        ),
      ),
    );
  }
}
