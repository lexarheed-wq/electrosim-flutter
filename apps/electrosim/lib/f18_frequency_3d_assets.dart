import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:electrosim_domain/electrosim_domain.dart';

/// Component 03: dedicated frequency instrument render and safe 2D fallback.
abstract final class F18Frequency3dAssets {
  static const frontPath =
      'assets/g5_industrial/instrument-frequency-front.png';
  static const palettePath =
      'assets/g5_industrial/instrument-frequency-palette.png';
  static ui.Image? front;
  static ui.Image? palette;
  static Future<bool>? _pending;
  static bool get ready => front != null && palette != null;

  /// Frequency glass at (26,22.5)..(86,53.5); readable inset below.
  static ui.Rect projectReadout(ui.Rect body) => ui.Rect.fromLTWH(
    body.left + body.width * (28 / 112),
    body.top + body.height * (26 / 152),
    body.width * (56 / 112),
    body.height * (24 / 152),
  );
  static bool uses3d(InstrumentInstance i) =>
      ready && i.kind == InstrumentKind.frequencyMeter;
  static Future<bool> preload() => _pending ??= _load();
  static Future<bool> _load() async {
    ui.Image? a;
    ui.Image? b;
    try {
      a = await _decode(frontPath);
      b = await _decode(palettePath);
      if (a.width != 1120 ||
          a.height != 1520 ||
          b.width != 1120 ||
          b.height != 1520) {
        a.dispose();
        b.dispose();
        return false;
      }
      front = a;
      palette = b;
      return true;
    } on Object {
      a?.dispose();
      b?.dispose();
      return false;
    }
  }

  static Future<ui.Image> _decode(String p) async {
    final bytes = await rootBundle.load(p);
    final codec = await ui.instantiateImageCodec(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }
}
