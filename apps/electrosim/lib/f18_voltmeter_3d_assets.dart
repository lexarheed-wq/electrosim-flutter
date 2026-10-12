import 'dart:ui' as ui;

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/services.dart';

/// Experimental pre-rendered Cycles artwork. No solver or terminal ownership.
///
/// Asset failure leaves the old 2D instrument completely intact. Front is
/// placed on the board while the perspective image is reserved for the palette.
abstract final class F18Voltmeter3dAssets {
  static const String frontPath =
      'assets/g5_industrial/instrument-voltmeter-front.png';
  static const String palettePath =
      'assets/g5_industrial/instrument-voltmeter-palette.png';
  static const Size designSize = Size(112, 152);

  // Derived from the Blender construction recipe; NOT the old generic LCD.
  static const Rect glassNormalized = Rect.fromLTWH(
    0.2792694611,
    0.1282894737,
    0.4414610777,
    0.1644736842,
  );

  // Slight inset ensures all runtime text remains inside the physical bezel.
  static const Rect readoutNormalized = Rect.fromLTWH(
    0.3060551754,
    0.1480263158,
    0.3878896491,
    0.125,
  );

  static ui.Image? _front;
  static ui.Image? _palette;
  static Future<bool>? _pending;
  static ui.Image? get front => _front;
  static ui.Image? get palette => _palette;
  static bool get ready => _front != null && _palette != null;

  static bool uses3d(InstrumentInstance instrument) =>
      ready && instrument.kind == InstrumentKind.voltmeter;

  static Rect projectReadout(Rect rect) => Rect.fromLTWH(
    rect.left + readoutNormalized.left * rect.width,
    rect.top + readoutNormalized.top * rect.height,
    readoutNormalized.width * rect.width,
    readoutNormalized.height * rect.height,
  );

  static Future<bool> preload() => _pending ??= _load();

  static Future<bool> _load() async {
    ui.Image? newFront;
    ui.Image? newPalette;
    try {
      newFront = await _decode(frontPath);
      newPalette = await _decode(palettePath);
      final bool original = newFront.width == 280 && newFront.height == 380;
      final bool premium = newFront.width == 1120 && newFront.height == 1520;
      if ((!original && !premium) ||
          newPalette.width != newFront.width ||
          newPalette.height != newFront.height) {
        throw const FormatException('Unexpected G5 voltmeter texture size');
      }
      _front = newFront;
      _palette = newPalette;
      return true;
    } catch (_) {
      newFront?.dispose();
      newPalette?.dispose();
      // Preserve the former vector instrument if textures are unavailable.
      return false;
    }
  }

  static Future<ui.Image> _decode(String asset) async {
    final ByteData bytes = await rootBundle.load(asset);
    final ui.Codec codec = await ui.instantiateImageCodec(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }
}
