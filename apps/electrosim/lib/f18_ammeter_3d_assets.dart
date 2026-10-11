import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:electrosim_domain/electrosim_domain.dart';

/// Component 02: independent fused ammeter render and safe 2D fallback.
abstract final class F18Ammeter3dAssets {
  static const frontPath = 'assets/g5_industrial/instrument-ammeter-front.png';
  static const palettePath = 'assets/g5_industrial/instrument-ammeter-palette.png';
  static ui.Image? front;
  static ui.Image? palette;
  static Future<bool>? _pending;
  static bool get ready => front != null && palette != null;
  static bool uses3d(InstrumentInstance i) =>
      ready && i.kind == InstrumentKind.ammeter;
  static Future<bool> preload() => _pending ??= _load();
  static Future<bool> _load() async {
    try {
      final a = await _decode(frontPath);
      final b = await _decode(palettePath);
      if (a.width != 1120 || a.height != 1520 ||
          b.width != 1120 || b.height != 1520) {
        a.dispose();
        b.dispose();
        return false;
      }
      front = a;
      palette = b;
      return true;
    } on Object {
      return false;
    }
  }
  static Future<ui.Image> _decode(String p) async {
    final bytes = await rootBundle.load(p);
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }
}
