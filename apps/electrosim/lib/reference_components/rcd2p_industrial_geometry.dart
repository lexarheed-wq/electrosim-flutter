part of 'disjoncteur_3d.dart';

/// Industrial polymer, steel and marking finish shared by palette and board.
/// These are appearance parameters only. Electrical terminal positions,
/// runtime states and click regions remain in disjoncteur_3d.dart.
final class _Rcd2pMaterial {
  const _Rcd2pMaterial({
    required this.base,
    required this.roughness,
    required this.specular,
  });
  final Color base;
  final double roughness;
  final double specular;
}

abstract final class _Rcd2pMaterials {
  static const polymer = _Rcd2pMaterial(
    base: Color(0xFFF4F5F2),
    roughness: .81,
    specular: .16,
  );
  static const recess = _Rcd2pMaterial(
    base: Color(0xFFCAD0CC),
    roughness: .88,
    specular: .1,
  );
  static const graphite = _Rcd2pMaterial(
    base: Color(0xFF24292E),
    roughness: .7,
    specular: .23,
  );
  static const steel = _Rcd2pMaterial(
    base: Color(0xFF626A6F),
    roughness: .38,
    specular: .58,
  );
  static const yellow = _Rcd2pMaterial(
    base: Color(0xFFF4C817),
    roughness: .55,
    specular: .27,
  );

  static _Rcd2pMaterial forColor(Color color) {
    if (color == graphite.base) return graphite;
    if (color == polymer.base) return polymer;
    if (color == recess.base) return recess;
    if (color == steel.base) return steel;
    if (color == yellow.base) return yellow;
    return const _Rcd2pMaterial(
      base: Color(0xFFFFFFFF),
      roughness: .78,
      specular: .12,
    );
  }
}

/// Fixed studio light rig in industrial product coordinates. Works for both
/// views and never depends on the electrical simulation or the Flutter theme.
abstract final class _Rcd2pLightRig {
  static final key = const _V(-.65, -.8, 1.3).unit;
  static final fill = const _V(.65, -.1, .45).unit;
  static final view = const _V(0, 0, 1).unit;

  static double brightness(_V normal, _Rcd2pMaterial material) {
    final diffuse = math.max(0, normal.dot(key));
    final bounce = math.max(0, normal.dot(fill));
    final half = (key + view).unit;
    final highlight = math
        .pow(math.max(0, normal.dot(half)), 3 + (material.roughness * 22))
        .toDouble();
    final value =
        .69 +
        .24 * diffuse +
        .09 * bounce +
        material.specular * .15 * highlight;
    return value.clamp(.45, 1.08).toDouble();
  }
}

/// The side contour is a genuine 3D mesh (not an image pasted onto the
/// device). Batches use the same stable projection as the electrical ports.
abstract final class _Rcd2pMeshFactory {
  static _Face rightPanel(
    double y1,
    double y2,
    double z1,
    double z2,
    Color color, {
    double x = 18.17,
  }) {
    return _Face([
      _V(x, y1, z1),
      _V(x, y2, z1),
      _V(x, y2, z2),
      _V(x, y1, z2),
    ], color);
  }

  static void housing(_Scene scene) {
    // One extruded moulded shell with the real DIN-mount shoulder profile.
    // Points describe its Y/Z contour; terminal and command geometry is stable.
    const corners = <(double, double)>[
      (-42.5, -32),
      (-42.5, 32),
      (-20.0, 32),
      (-18.8, 39),
      (7.5, 39),
      (9.0, 41),
      (29.5, 41),
      (31.0, 32),
      (42.5, 32),
      (42.5, -25),
      (31.0, -25),
      (31.0, -10),
      (18.0, -10),
      (18.0, -1),
      (-12.0, -1),
      (-12.0, -10),
      (-28.0, -10),
      (-28.0, -32),
    ];
    final profile = <(double, double)>[];
    for (var i = 0; i < corners.length; i++) {
      final before = corners[(i - 1 + corners.length) % corners.length];
      final corner = corners[i], after = corners[(i + 1) % corners.length];
      final a = _V(0, corner.$1 - before.$1, corner.$2 - before.$2);
      final b = _V(0, after.$1 - corner.$1, after.$2 - corner.$2);
      final radius = math.min(
        .6,
        math.min(math.sqrt(a.dot(a)), math.sqrt(b.dot(b))) / 3,
      );
      final v = _V(0, corner.$1, corner.$2);
      final start = v - a.unit * radius, end = v + b.unit * radius;
      for (var j = 0; j <= 6; j++) {
        final t = j / 6;
        final q =
            start * ((1 - t) * (1 - t)) + v * (2 * t * (1 - t)) + end * (t * t);
        profile.add((q.y, q.z));
      }
    }
    final mesh = <_Face>[
      _Face([
        for (final q in profile) _V(-18, q.$1, q.$2),
      ], const Color(0xFFE2E4DF)),
      _Face([
        for (final q in profile.reversed) _V(18, q.$1, q.$2),
      ], const Color(0xFFE2E4DF)),
    ];
    for (var i = 0; i < profile.length; i++) {
      final a = profile[i], b = profile[(i + 1) % profile.length];
      mesh.add(
        _Face([
          _V(-18, a.$1, a.$2),
          _V(18, a.$1, a.$2),
          _V(18, b.$1, b.$2),
          _V(-18, b.$1, b.$2),
        ], _Rcd2pMaterials.polymer.base),
      );
    }
    scene.faces(mesh);
    // A very fine modular seam and a shaped mounting flank, rather than
    // stacked decorative rectangles which visually flattened the old housing.
    scene.line(
      const _V(18.12, -40, -25),
      const _V(18.12, 34, -25),
      const Color(0xFFB1B7B0),
      .12,
    );
    // A raised moulding land with chamfered shoulders. The shell and land
    // share their contour, so the DIN recess stays genuinely open at the rear.
    const land = <(double, double)>[
      (-26, -27),
      (29, -27),
      (29, -10),
      (16, -10),
      (16, -1),
      (-11, -1),
      (-11, -10),
      (-26, -10),
    ];
    final flank = <_Face>[
      _Face([
        for (final q in land) _V(18.4, q.$1, q.$2),
      ], const Color(0xFFE9EBE5)),
    ];
    for (var i = 0; i < land.length; i++) {
      final a = land[i], b = land[(i + 1) % land.length];
      flank.add(
        _Face([
          _V(18.04, a.$1, a.$2),
          _V(18.04, b.$1, b.$2),
          _V(18.4, b.$1, b.$2),
          _V(18.4, a.$1, a.$2),
        ], _Rcd2pMaterials.polymer.base),
      );
    }
    scene.faces(flank);
    // The split between modular poles continues around the raised rear land.
    scene.line(
      const _V(18.42, -25.7, -26.7),
      const _V(18.42, 28.7, -26.7),
      const Color(0xFFE9EBE5),
      .12,
    );
    for (final y in [-30.0, -14.0, 12.0, 34.0]) {
      scene.disc(_V(18.19, y, 21), 1.35, [
        const Color(0xFF242A28),
        const Color(0xFF6D7770),
        const Color(0xFFD5D9D1),
      ], side: true);
    }
    for (final y in [-30.0, 26.0]) {
      scene.faces([
        rightPanel(y, y + 4.5, -25, -21, const Color(0xFF5F6B62), x: 18.2),
      ]);
    }
    // Two individual terminal blocks, softly chamfered, on the shared shell.
    for (final x in [-8.8, 8.8]) {
      scene.box(
        x,
        -30.8,
        17.6,
        23.0,
        35.4,
        3.4,
        _Rcd2pMaterials.polymer.base,
        radius: .9,
        bevel: .55,
      );
      scene.box(
        x,
        35.2,
        17.6,
        14.2,
        35.4,
        3.4,
        _Rcd2pMaterials.polymer.base,
        radius: .65,
        bevel: .4,
      );
    }
    scene.line(
      const _V(0, -42, 35.65),
      const _V(0, -20, 35.65),
      const Color(0xFFBCC2B9),
      .12,
    );
    scene.line(
      const _V(0, 28.2, 35.65),
      const _V(0, 42, 35.65),
      const Color(0xFFBCC2B9),
      .12,
    );
  }

  static void yellowReleaseTabs(_Scene scene) {
    // Individually modelled U-shaped release clips (two uprights + bridge).
    for (final x in [-8.3, 8.3]) {
      for (final dx in [-2.4, 2.4]) {
        scene.box(
          x + dx,
          -44.7,
          1.8,
          5.7,
          25,
          5.0,
          _Rcd2pMaterials.yellow.base,
          radius: .55,
          bevel: .28,
        );
      }
      scene.box(
        x,
        -46.95,
        6.85,
        1.8,
        25.9,
        3.1,
        const Color(0xFFFFDA20),
        radius: .55,
        bevel: .25,
      );
      scene.box(
        x,
        -43.2,
        3.1,
        2.9,
        35.7,
        2.0,
        const Color(0xFFE9BD15),
        radius: .48,
        bevel: .25,
      );
    }
    scene.box(
      -12,
      43.5,
      7,
      2.2,
      -22,
      9,
      _Rcd2pMaterials.yellow.base,
      radius: .55,
      bevel: .25,
    );
  }

  static void terminalEnclosures(_Scene scene) {
    for (final x in [-8.3, 8.3]) {
      scene.box(
        x,
        -41.3,
        10,
        2.2,
        26,
        9,
        _Rcd2pMaterials.recess.base,
        radius: .6,
        bevel: .34,
      );
      scene.box(
        x,
        -41.3,
        7.6,
        1.3,
        26.2,
        1,
        const Color(0xFF909B95),
        radius: .35,
      );
    }
  }
}
