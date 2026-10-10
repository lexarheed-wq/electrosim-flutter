import 'dart:ui';

import 'package:electrosim_canvas/electrosim_canvas.dart';

/// Versioned, geometry-only snapshot. No electrical state is derived here.
final class ElectroSimLayoutPersistence {
  const ElectroSimLayoutPersistence._();

  static const int schemaVersion = 3;

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
    'cabinetFixtures': [
      for (final fixture in layout.cabinetLayout.fixtures)
        <String, Object?>{
          'id': fixture.id,
          'kind': fixture.kind.name,
          'bounds': <double>[
            fixture.bounds.left,
            fixture.bounds.top,
            fixture.bounds.width,
            fixture.bounds.height,
          ],
        },
    ],
    'cabinetEnvelope': layout.cabinetLayout.envelope == null
        ? null
        : <String, Object?>{
            'widthMm': layout.cabinetLayout.envelope!.widthMm,
            'heightMm': layout.cabinetLayout.envelope!.heightMm,
            'depthMm': layout.cabinetLayout.envelope!.depthMm,
            'marginMm': layout.cabinetLayout.envelope!.marginMm,
            'origin': [
              layout.cabinetLayout.envelope!.origin.dx,
              layout.cabinetLayout.envelope!.origin.dy,
            ],
          },
    'cabinetMounts': {
      for (final entry in layout.cabinetLayout.mounts.entries)
        entry.key: <String, Object?>{
          'surface': entry.value.surface.name,
          'railId': entry.value.railId,
          'anchorOffset': [
            entry.value.anchorOffset.dx,
            entry.value.anchorOffset.dy,
          ],
          'depthMm': entry.value.depthMm,
        },
    },
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
    // Old V2 saves used schema 1, which contained no cabinet geometry.
    // Keep them loadable without reinterpreting any electrical data.
    final int? version = data['schemaVersion'] is int
        ? data['schemaVersion'] as int
        : null;
    if (version != 1 && version != 2 && version != schemaVersion) {
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

    final List<CabinetFixture> fixtures = <CabinetFixture>[];
    if (version! >= 2) {
      final Object? rawFixtures = data['cabinetFixtures'];
      if (rawFixtures is! List) {
        throw const FormatException('Invalid cabinetFixtures.');
      }
      for (final item in rawFixtures) {
        if (item is! Map) {
          throw const FormatException('Invalid cabinet fixture record.');
        }
        final fixture = Map<String, dynamic>.from(item);
        final id = fixture['id'];
        final kind = fixture['kind'];
        final rawBounds = fixture['bounds'];
        if (id is! String ||
            id.trim().isEmpty ||
            kind is! String ||
            rawBounds is! List ||
            rawBounds.length != 4 ||
            rawBounds.any((value) => value is! num)) {
          throw const FormatException('Malformed cabinet fixture.');
        }
        final values = rawBounds.cast<num>().map((v) => v.toDouble()).toList();
        if (values.any((v) => !v.isFinite)) {
          throw const FormatException('Non-finite cabinet geometry.');
        }
        final type = CabinetFixtureKind.values
            .where((v) => v.name == kind)
            .toList();
        if (type.length != 1) {
          throw FormatException('Unknown cabinet fixture type: $kind.');
        }
        try {
          fixtures.add(
            CabinetFixture(
              id: id,
              kind: type.single,
              bounds: Rect.fromLTWH(values[0], values[1], values[2], values[3]),
            ),
          );
        } on ArgumentError catch (error) {
          throw FormatException('Invalid cabinet fixture $id: $error');
        }
      }
    }
    late final CabinetLayout cabinet;
    try {
      CabinetEnvelope? envelope;
      final mounts = <String, CabinetMount>{};
      if (version == 3) {
        final rawEnvelope = data['cabinetEnvelope'];
        if (rawEnvelope != null) {
          final e = _map(rawEnvelope, 'cabinetEnvelope');
          envelope = CabinetEnvelope(
            widthMm: _number(e['widthMm'], 'widthMm'),
            heightMm: _number(e['heightMm'], 'heightMm'),
            depthMm: _number(e['depthMm'], 'depthMm'),
            marginMm: _number(e['marginMm'], 'marginMm'),
            origin: _point(e['origin'], 'cabinetEnvelope.origin'),
          );
        }
        for (final e in _map(data['cabinetMounts'], 'cabinetMounts').entries) {
          if (e.key.trim().isEmpty) {
            throw const FormatException('Empty mounting element ID.');
          }
          final m = _map(e.value, 'cabinetMounts.${e.key}');
          final surface = CabinetSurface.values
              .where((s) => s.name == m['surface'])
              .toList();
          final rail = m['railId'];
          if (surface.length != 1 || (rail != null && rail is! String)) {
            throw const FormatException('Invalid mounting surface or rail ID.');
          }
          if (rail != null &&
              !fixtures.any(
                (f) => f.id == rail && f.kind == CabinetFixtureKind.dinRail,
              )) {
            throw const FormatException(
              'Mount references an unknown DIN rail.',
            );
          }
          mounts[e.key] = CabinetMount(
            surface: surface.single,
            railId: rail as String?,
            anchorOffset: _point(
              m['anchorOffset'],
              'cabinetMounts.${e.key}.anchorOffset',
            ),
            depthMm: _number(m['depthMm'], 'mount.depthMm'),
          );
        }
      }
      cabinet = CabinetLayout(fixtures, envelope: envelope, mounts: mounts);
    } on ArgumentError catch (error) {
      throw FormatException('Invalid cabinet layout: $error');
    }
    return CircuitVisualLayout(
      cabinetLayout: cabinet,
      elementPositions: positions,
      elementSizes: sizes,
      wireRoutes: routes,
      elementQuarterTurns: turns,
      defaultElementSize: _size(data['defaultSize'], 'defaultSize'),
    );
  }

  static double _number(Object? raw, String field) {
    if (raw is! num || !raw.isFinite) {
      throw FormatException('Invalid physical dimensions at $field.');
    }
    return raw.toDouble();
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
