import 'dart:ui';
import 'package:flutter/foundation.dart';

/// Physical cabinet dimensions use millimetres: one authored world unit = 1 mm.
/// These generic envelopes are independent from electrical simulation models.
enum CabinetSurface { interior, door, exterior }

@immutable
final class CabinetEnvelope {
  CabinetEnvelope({
    required this.widthMm,
    required this.heightMm,
    required this.depthMm,
    this.marginMm = 24,
    this.origin = Offset.zero,
  }) {
    if (![
          widthMm,
          heightMm,
          depthMm,
          marginMm,
          origin.dx,
          origin.dy,
        ].every((v) => v.isFinite) ||
        widthMm <= 0 ||
        heightMm <= 0 ||
        depthMm <= 0 ||
        marginMm < 0 ||
        widthMm <= 2 * marginMm ||
        heightMm <= 2 * marginMm) {
      throw ArgumentError(
        'Cabinet dimensions and usable mounting plate must be finite and positive.',
      );
    }
  }
  static const double worldUnitsPerMillimeter = 1;
  final double widthMm, heightMm, depthMm, marginMm;
  final Offset origin;
  Rect get bounds => origin & Size(widthMm, heightMm);
  Rect get plateBounds => bounds.deflate(marginMm);
  Rect? boundsFor(CabinetSurface surface) => switch (surface) {
    CabinetSurface.interior => plateBounds,
    CabinetSurface.door => bounds,
    CabinetSurface.exterior => null,
  };
  bool contains(Rect rect, {CabinetSurface surface = CabinetSurface.interior}) {
    final b = boundsFor(surface);
    return b == null ||
        (rect.left >= b.left &&
            rect.top >= b.top &&
            rect.right <= b.right &&
            rect.bottom <= b.bottom);
  }

  @override
  bool operator ==(Object other) =>
      other is CabinetEnvelope &&
      widthMm == other.widthMm &&
      heightMm == other.heightMm &&
      depthMm == other.depthMm &&
      marginMm == other.marginMm &&
      origin == other.origin;
  @override
  int get hashCode => Object.hash(widthMm, heightMm, depthMm, marginMm, origin);
}

@immutable
final class CabinetMount {
  CabinetMount({
    this.surface = CabinetSurface.interior,
    this.railId,
    this.anchorOffset = Offset.zero,
    this.depthMm = 45,
  }) {
    if (!anchorOffset.dx.isFinite ||
        !anchorOffset.dy.isFinite ||
        !depthMm.isFinite ||
        depthMm <= 0 ||
        (railId != null && railId!.trim().isEmpty) ||
        (railId != null && surface != CabinetSurface.interior)) {
      throw ArgumentError('Invalid mounting surface, DIN attachment or depth.');
    }
  }
  final CabinetSurface surface;
  final String? railId;
  final Offset anchorOffset;
  final double depthMm;
  CabinetMount withoutRail() => CabinetMount(
    surface: surface,
    anchorOffset: anchorOffset,
    depthMm: depthMm,
  );
  @override
  bool operator ==(Object other) =>
      other is CabinetMount &&
      surface == other.surface &&
      railId == other.railId &&
      anchorOffset == other.anchorOffset &&
      depthMm == other.depthMm;
  @override
  int get hashCode => Object.hash(surface, railId, anchorOffset, depthMm);
}
