import 'package:flutter/services.dart';

/// Loads the app's bundled Roboto faces for screenshot tests.
///
/// This avoids Flutter's replacement test font and makes text rendering
/// independent of fonts installed on the runner.
Future<void> loadElectroSimGoldenFont() async {
  final loader = FontLoader('Roboto')
    ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
  await loader.load();
}
