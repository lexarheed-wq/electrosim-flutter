import 'dart:ui' as ui;
import 'package:flutter/services.dart';

/// Original Cycles textures, published together only after all decode checks.
abstract final class F18Crusher3dAssets {
  static const root = 'assets/g5_industrial/external-crusher';
  static ui.Image? front, palette, service;
  static Future<bool>? _pending;
  static bool get ready => front != null && palette != null && service != null;
  static bool matches(String type, String? variant) =>
      type == 'catalog_motor_driven_6t' && variant == 'crusher';
  static Future<bool> preload() => _pending ??= _load();
  static Future<bool> _load() async {
    final decoded = <ui.Image>[];
    try {
      for (final suffix in ['front', 'palette', 'service']) {
        final bytes = await rootBundle.load('$root-$suffix.png');
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        try {
          final image = (await codec.getNextFrame()).image;
          decoded.add(image);
          if (image.width != 1440 || image.height != 1320) {
            throw StateError('Wrong crusher texture dimensions');
          }
        } finally {
          codec.dispose();
        }
      }
      front = decoded[0];
      palette = decoded[1];
      service = decoded[2];
      return true;
    } on Object {
      for (final image in decoded) {
        image.dispose();
      }
      return false;
    }
  }
}
