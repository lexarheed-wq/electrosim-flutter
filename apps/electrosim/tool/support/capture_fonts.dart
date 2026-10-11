import 'dart:io';
import 'package:flutter/services.dart';

Future<void> loadCaptureFonts() async {
  final fonts =
      Platform.environment['ELECTROSIM_FONT_DIR'] ??
      '${Platform.environment['FLUTTER_ROOT'] ?? '/workspace/toolchains/flutter'}/bin/cache/artifacts/material_fonts';
  final loader = FontLoader('Roboto');
  for (final name in [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ]) {
    loader.addFont(
      Future.value(
        ByteData.sublistView(await File('$fonts/$name').readAsBytes()),
      ),
    );
  }
  await loader.load();
  await (FontLoader('MaterialIcons')..addFont(
        Future.value(
          ByteData.sublistView(
            await File('$fonts/MaterialIcons-Regular.otf').readAsBytes(),
          ),
        ),
      ))
      .load();
}
