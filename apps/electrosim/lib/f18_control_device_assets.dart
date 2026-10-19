import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Original Blender/Cycles product views for the remaining control hardware.
/// These are presentation only: runtime contacts, PLC outputs and timer state
/// continue to come from the electrical/control engines. Missing or invalid
/// images keep the established interactive Dart renderer.
abstract final class F18ControlDeviceAssets {
  static const _base = 'assets/g5_control';
  static final Map<String, ui.Image> _images = <String, ui.Image>{};
  static Future<bool>? _pending;

  static bool get ready => _images.isNotEmpty;

  static String? imageKey(String modelType, String? variantKey) {
    final type = modelType.toLowerCase();
    if (type == 'timer_star_delta') return 'timer-star-delta';
    if (type == 'plc_ac3') return 'plc-ac3';
    if (type == 'plc_dc') return 'plc-dc';
    if (type == 'mechanical_interlock_ac3') return 'mechanical-interlock-ac3';
    if (type == 'catalog_sensor_2t') {
      return switch (variantKey) {
        'sensor-proximity' => 'sensor-proximity',
        'limit-switch-no' => 'limit-switch-no',
        'limit-switch-nc' => 'limit-switch-nc',
        _ => null,
      };
    }
    return null;
  }

  static ui.Image? image(
    String model, {
    required bool palette,
    bool actuated = false,
    String? activeSide,
  }) =>
      _images['$model${activeSide == null ? '' : '-active-$activeSide'}${actuated ? '-actuated' : ''}-${palette ? 'palette' : 'front'}'] ??
      _images['$model-${palette ? 'palette' : 'front'}'];

  static Future<bool> preload() => _pending ??= _load();

  static Future<bool> _load() async {
    final staged = <String, ui.Image>{};
    const models = <String>[
      'timer-star-delta',
      'plc-ac3',
      'plc-dc',
      'mechanical-interlock-ac3',
      'sensor-proximity',
      'limit-switch-no',
      'limit-switch-nc',
    ];
    try {
      for (final model in models) {
        for (final view in const ['front', 'palette']) {
          final data = await rootBundle.load('$_base/$model-$view.png');
          final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
          try {
            final image = (await codec.getNextFrame()).image;
            _validateDimensions(model, image);
            staged['$model-$view'] = image;
          } finally {
            codec.dispose();
          }
        }
      }
      for (final model in const [
        'sensor-proximity',
        'limit-switch-no',
        'limit-switch-nc',
      ]) {
        final variantImages = <String, ui.Image>{};
        try {
          for (final view in const ['front', 'palette']) {
            final key = '$model-actuated-$view';
            final data = await rootBundle.load('$_base/$key.png');
            final codec = await ui.instantiateImageCodec(
              data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
            );
            try {
              final image = (await codec.getNextFrame()).image;
              _validateDimensions(model, image);
              variantImages[key] = image;
            } finally {
              codec.dispose();
            }
          }
          staged.addAll(variantImages);
        } on Object {
          for (final image in variantImages.values) {
            image.dispose();
          }
        }
      }
      for (final side in const ['a', 'b']) {
        const model = 'mechanical-interlock-ac3';
        final variantImages = <String, ui.Image>{};
        try {
          for (final view in const ['front', 'palette']) {
            final key = '$model-active-$side-$view';
            final data = await rootBundle.load('$_base/$key.png');
            final codec = await ui.instantiateImageCodec(
              data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
            );
            try {
              final image = (await codec.getNextFrame()).image;
              _validateDimensions(model, image);
              variantImages[key] = image;
            } finally {
              codec.dispose();
            }
          }
          staged.addAll(variantImages);
        } on Object {
          for (final image in variantImages.values) {
            image.dispose();
          }
        }
      }
      _images.addAll(staged);
      return true;
    } on Object {
      for (final image in staged.values) {
        image.dispose();
      }
      // A partial lot must never mix camera-rendered assets with fallbacks.
      _images.clear();
      return false;
    }
  }

  static void _validateDimensions(String model, ui.Image image) {
    final bool portrait =
        model == 'timer-star-delta' ||
        model == 'sensor-proximity' ||
        model.startsWith('limit-switch-');
    final int expectedWidth = portrait ? 700 : 900;
    final int expectedHeight = portrait ? 900 : 700;
    if (image.width != expectedWidth || image.height != expectedHeight) {
      image.dispose();
      throw StateError(
        'Unexpected image size for $model: ${image.width}×${image.height}',
      );
    }
  }
}
