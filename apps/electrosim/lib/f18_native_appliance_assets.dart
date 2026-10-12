import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';

class F18NativeApplianceImages {
  const F18NativeApplianceImages(
    this.front,
    this.palette,
    this.service, {
    this.rotor,
    this.guard,
    this.serviceGuard,
  });
  final ui.Image front, palette, service;
  final ui.Image? rotor, guard, serviceGuard;
}

/// Shared by all instances; publish one component only when all three views decode.
abstract final class F18NativeApplianceAssets {
  static final _images = <String, F18NativeApplianceImages>{};
  static final _pending = <String, Future<bool>>{};
  static F18NativeApplianceImages? images(String key) => _images[key];
  static Future<bool> load(String key) =>
      _pending.putIfAbsent(key, () => _load(key));
  static Future<void> preload() async {
    for (final key in NativeApplianceGeometry.catalogue.keys) {
      await load(key);
    }
  }

  static Future<bool> _load(String key) async {
    final spec = NativeApplianceGeometry.catalogue[key];
    if (spec == null) return false;
    final decoded = <ui.Image>[];
    try {
      final movingFan = key == 'external-fan-ac1' || key == 'external-fan-3p';
      for (final view in [
        'front',
        'palette',
        'service',
        if (movingFan) ...['rotor', 'guard'],
        if (key == 'external-fan-3p') 'guard-service',
      ]) {
        final bytes = await rootBundle.load(
          'assets/g5_industrial/$key-$view.png',
        );
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        try {
          final image = (await codec.getNextFrame()).image;
          decoded.add(image);
          if (image.width != spec.designSize.width * 4 ||
              image.height != spec.designSize.height * 4) {
            throw StateError('Wrong native appliance dimensions: $key');
          }
        } finally {
          codec.dispose();
        }
      }
      _images[key] = F18NativeApplianceImages(
        decoded[0],
        decoded[1],
        decoded[2],
        rotor: movingFan ? decoded[3] : null,
        guard: movingFan ? decoded[4] : null,
        serviceGuard: key == 'external-fan-3p' ? decoded[5] : null,
      );
      return true;
    } on Object {
      for (final image in decoded) {
        image.dispose();
      }
      return false;
    }
  }
}
