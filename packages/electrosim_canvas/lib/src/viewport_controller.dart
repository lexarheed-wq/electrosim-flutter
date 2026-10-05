import 'dart:ui';

import 'package:flutter/foundation.dart';

final class ViewportController extends ChangeNotifier {
  ViewportController({
    double scale = 1,
    Offset translation = Offset.zero,
    this.minScale = 0.35,
    this.maxScale = 4,
  }) : _scale = scale.clamp(minScale, maxScale).toDouble(),
       _translation = translation;

  final double minScale;
  final double maxScale;

  double _scale;
  Offset _translation;

  double get scale => _scale;
  Offset get translation => _translation;

  Offset worldToScreen(Offset world) => Offset(
    world.dx * _scale + _translation.dx,
    world.dy * _scale + _translation.dy,
  );

  Offset screenToWorld(Offset screen) => Offset(
    (screen.dx - _translation.dx) / _scale,
    (screen.dy - _translation.dy) / _scale,
  );

  void panBy(Offset screenDelta) {
    if (screenDelta == Offset.zero) {
      return;
    }
    _translation += screenDelta;
    notifyListeners();
  }

  void zoomAt(Offset screenFocalPoint, double factor) {
    if (!factor.isFinite || factor <= 0) {
      return;
    }
    final Offset worldBefore = screenToWorld(screenFocalPoint);
    final double nextScale = (_scale * factor)
        .clamp(minScale, maxScale)
        .toDouble();
    if (nextScale == _scale) {
      return;
    }
    _scale = nextScale;
    _translation = Offset(
      screenFocalPoint.dx - worldBefore.dx * _scale,
      screenFocalPoint.dy - worldBefore.dy * _scale,
    );
    notifyListeners();
  }

  void reset({double scale = 1, Offset translation = Offset.zero}) {
    final double nextScale = scale.clamp(minScale, maxScale).toDouble();
    if (nextScale == _scale && translation == _translation) {
      return;
    }
    _scale = nextScale;
    _translation = translation;
    notifyListeners();
  }
}
