import 'dart:io';

/// Keeps raster references specific to the platform used to capture them.
/// Flutter's macOS text and image rasterization differs from Linux goldens.
String platformGoldenPath(String filename) =>
    Platform.isMacOS ? 'goldens/macos/$filename' : 'goldens/$filename';
