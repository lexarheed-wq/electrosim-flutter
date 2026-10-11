import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:electrosim_domain/electrosim_domain.dart';

/// Component 04: dedicated phase rotation tester render and safe 2D fallback.
abstract final class F18PhaseSequence3dAssets {
  static const frontPath =
      'assets/g5_industrial/instrument-phase-sequence-front.png';
  static const palettePath =
      'assets/g5_industrial/instrument-phase-sequence-palette.png';
  static ui.Image? front;
  static ui.Image? palette;
  static Future<bool>? _pending;
  static bool get ready => front != null && palette != null;

  /// Tall LCD at (31,51.5)..(81,114.5); inset below.
  static ui.Rect projectReadout(ui.Rect body) => ui.Rect.fromLTWH(
    body.left + body.width * (33 / 112),
    body.top + body.height * (54 / 152),
    body.width * (46 / 112),
    body.height * (57 / 152),
  );
  static bool uses3d(InstrumentInstance i) =>
      ready && i.kind == InstrumentKind.phaseSequenceTester;
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
