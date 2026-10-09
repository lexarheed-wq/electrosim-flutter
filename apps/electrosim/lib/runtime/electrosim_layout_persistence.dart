import 'dart:ui';

import 'package:electrosim_canvas/electrosim_canvas.dart';

/// Versioned, geometry-only snapshot. No electrical state is derived here.
final class ElectroSimLayoutPersistence {
  const ElectroSimLayoutPersistence._();

  static const int schemaVersion = 1;

  static Map<String, Object?> encode(
    CircuitVisualLayout layout,
  ) => <String, Object?>{
    'schemaVersion': schemaVersion,
    'positions': layout.elementPositions.map(
      (String id, Offset value) =>
          MapEntry<String, Object?>(id, <double>[value.dx, value.dy]),
    ),
    'sizes': layout.elementSizes.map(
      (String id, Size value) =>
          MapEntry<String, Object?>(id, <double>[value.width, value.height]),
    ),
    'routes': layout.wireRoutes.map(
      (String id, List<Offset> points) => MapEntry<String, Object?>(
        id,
        points
            .map((Offset point) => <double>[point.dx, point.dy])
            .toList(growable: false),
      ),
    ),
    'quarterTurns': layout.elementQuarterTurns,
    'defaultSize': <double>[
      layout.defaultElementSize.width,
      layout.defaultElementSize.height,
    ],
  };

  /// Null means a legacy save without geometry: the caller may auto-layout.
  /// Malformed geometry is an error, never silently replaced by a new layout.
  static CircuitVisualLayout? decode(Object? raw) {
    if (raw == null) return null;
    if (raw is! Map) {
      throw const FormatException('Invalid saved visual layout.');
    }
    final Map<String, dynamic> data = Map<String, dynamic>.from(raw);
    if (data['schemaVersion'] != schemaVersion) {
      throw FormatException(
        'Unsupported layout schemaVersion: ${data['schemaVersion']}.',
      );
    }
    final Map<String, Offset> positions = <String, Offset>{};
    for (final MapEntry<String, dynamic> item in _map(
      data['positions'],
      'positions',
    ).entries) {
      positions[item.key] = _point(item.value, 'positions.${item.key}');
    }

    final Map<String, Size> sizes = <String, Size>{};
    for (final MapEntry<String, dynamic> item in _map(
      data['sizes'],
      'sizes',
    ).entries) {
      sizes[item.key] = _size(item.value, 'sizes.${item.key}');
    }

    final Map<String, List<Offset>> routes = <String, List<Offset>>{};
    for (final MapEntry<String, dynamic> item in _map(
      data['routes'],
      'routes',
    ).entries) {
      final Object? rawPoints = item.value;
      if (rawPoints is! List) {
        throw FormatException('Invalid route for ${item.key}.');
      }
      routes[item.key] = rawPoints
          .map((Object? point) => _point(point, 'routes.${item.key}'))
          .toList(growable: false);
    }

    final Map<String, int> turns = <String, int>{};
    for (final MapEntry<String, dynamic> item in _map(
      data['quarterTurns'],
      'quarterTurns',
    ).entries) {
      if (item.value is! int || item.value < 0 || item.value > 3) {
        throw FormatException('Invalid rotation for ${item.key}.');
      }
      turns[item.key] = item.value as int;
    }

    return CircuitVisualLayout(
      elementPositions: positions,
      elementSizes: sizes,
      wireRoutes: routes,
      elementQuarterTurns: turns,
      defaultElementSize: _size(data['defaultSize'], 'defaultSize'),
    );
  }

  static Map<String, dynamic> _map(Object? raw, String field) {
    if (raw is! Map) throw FormatException('Missing layout $field.');
    try {
      return Map<String, dynamic>.from(raw);
    } on Object {
      throw FormatException('Invalid layout $field.');
    }
  }

  static List<double> _pair(Object? raw, String field) {
    if (raw is! List || raw.length != 2 || raw[0] is! num || raw[1] is! num) {
      throw FormatException('Invalid layout coordinates at $field.');
    }
    final double x = (raw[0] as num).toDouble();
    final double y = (raw[1] as num).toDouble();
    if (!x.isFinite || !y.isFinite) {
      throw FormatException('Non-finite layout coordinates at $field.');
    }
    return <double>[x, y];
  }

  static Offset _point(Object? raw, String field) {
    final List<double> p = _pair(raw, field);
    return Offset(p[0], p[1]);
  }

  static Size _size(Object? raw, String field) {
    final List<double> p = _pair(raw, field);
    if (p[0] <= 0 || p[1] <= 0) {
      throw FormatException('Invalid layout dimensions at $field.');
    }
    return Size(p[0], p[1]);
  }
}
