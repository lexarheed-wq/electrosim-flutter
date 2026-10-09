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
    base: Color(0xFFF4F5F2), roughness: .81, specular: .16,
  );
  static const recess = _Rcd2pMaterial(
    base: Color(0xFFCAD0CC), roughness: .88, specular: .1,
  );
  static const graphite = _Rcd2pMaterial(
    base: Color(0xFF24292E), roughness: .7, specular: .23,
  );
  static const steel = _Rcd2pMaterial(
    base: Color(0xFF626A6F), roughness: .38, specular: .58,
  );
  static const yellow = _Rcd2pMaterial(
    base: Color(0xFFF4C817), roughness: .55, specular: .27,
  );

  static _Rcd2pMaterial forColor(Color color) {
    if (color == graphite.base) return graphite;
    if (color == polymer.base) return polymer;
    if (color == recess.base) return recess;
    if (color == steel.base) return steel;
    if (color == yellow.base) return yellow;
    return const _Rcd2pMaterial(
      base: Color(0xFFFFFFFF), roughness: .78, specular: .12,
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
    final highlight = math.pow(
      math.max(0, normal.dot(half)),
      3 + (material.roughness * 22),
    ).toDouble();
    final value = .69 + .24 * diffuse + .09 * bounce +
        material.specular * .15 * highlight;
    return value.clamp(.45, 1.08).toDouble();
  }
}

/// The side contour is a genuine 3D mesh (not an image pasted onto the
/// device). Batches use the same stable projection as the electrical ports.
abstract final class _Rcd2pMeshFactory {
  static _Face rightPanel(double y1, double y2, double z1, double z2,
      Color color, {double x = 18.17}) {
    return _Face([
      _V(x, y1, z1), _V(x, y2, z1),
      _V(x, y2, z2), _V(x, y1, z2),
    ], color);
  }

  static void housing(_Scene scene) {
    scene.box(0, 0, 36, 85, 34, 68,
        _Rcd2pMaterials.polymer.base, radius: 1.55, bevel: 1.2);

    // Raised flanks and mould separation lines. z denotes front depth.
    // Stepped mechanical mounting panel as an eight-vertex real polygon on
    // the X-positive side. Its contour follows the shoulders and recesses
    // instead of overlaying a flat rectangular sticker.
    scene.faces([
      const _Face([
        _V(18.37, -27, -28), _V(18.37, 31, -28),
        _V(18.37, 31, -8), _V(18.37, 17, -8),
        _V(18.37, 17, 11), _V(18.37, -9, 11),
        _V(18.37, -9, 2), _V(18.37, -27, 2),
      ], Color(0xFFE9EBE8)),
    ]);
    scene.faces([
      rightPanel(-39.8, -21, -30, 27,
          const Color(0xFFEAEBE8), x: 18.18),
      rightPanel(-20.5, 8, -32, 4,
          const Color(0xFFDDE0DC), x: 18.20),
      rightPanel(9, 39.8, -27, 0,
          const Color(0xFFE8EAE6), x: 18.21),
      rightPanel(-12, 20, 4, 19,
          const Color(0xFFF3F4F0), x: 18.25),
      rightPanel(-4, 14, 19.5, 22,
          const Color(0xFFD6DAD5), x: 18.29),
    ]);
    // The two modular shells are separated by a narrow mould seam.
    scene.line(const _V(0, -41.1, 34.25),
        const _V(0, -19.9, 34.25), const Color(0xFFAAB0AB), .16);
    scene.line(const _V(0, 27, 34.25),
        const _V(0, 42, 34.25), const Color(0xFFAAB0AB), .16);

    // Clipped edges and a recessed DIN release seat on the side.
    for (final y in [-32.0, 24.0]) {
      scene.box(17.9, y, 1.45, 4.6, -21, 8.5,
          const Color(0xFFD4DAD5), radius: .65, bevel: .28);
    }
    scene.line(const _V(18.43, -9, 11.3),
        const _V(18.43, 17, 11.3),
        const Color(0xFFADB5AE), .23);
    scene.line(const _V(18.43, 17, -8),
        const _V(18.43, 31, -8),
        const Color(0xFFB0B8B1), .23);
    // Vent slots and small lateral fastener wells in the right-side mesh.
    for (final y in [-30.0, -16.0, 3.0, 29.0]) {
      scene.disc(_V(18.35, y, -9), 1.45, [
        const Color(0xFF363E40), const Color(0xFF808A87),
        const Color(0xFFEAEBE8),
      ], side: true);
    }
    scene.line(const _V(18.36, -38, -25),
        const _V(18.36, 35, -25), const Color(0xFF99A3A0), .12);
    for (final y in [-28.0, -16.0, 17.0, 30.0]) {
      scene.line(_V(18.38, y, -21), _V(18.38, y + 3, -21),
          const Color(0xFFB4BCB7), .22);
    }

    // Relief visible beneath the top terminal block.
    scene.box(0, -30.4, 35.6, 24.4, 35.3, 3.4,
        _Rcd2pMaterials.polymer.base, radius: 1.2, bevel: .75);
    scene.box(0, -18.3, 35.6, 1.5, 36.3, 1.3,
        const Color(0xFFDFE3DF), radius: .35, bevel: .2);
    scene.box(0, 34.8, 35.6, 14.4, 35.4, 3.3,
        _Rcd2pMaterials.polymer.base, radius: 1.0, bevel: .65);
    scene.box(0, 41.9, 35.4, .95, 36.2, 1.0,
        const Color(0xFFDEE2DE), radius: .18, bevel: .15);
  }

  static void yellowReleaseTabs(_Scene scene) {
    // Individually modelled U-shaped release clips (two uprights + bridge).
    for (final x in [-8.3, 8.3]) {
      for (final dx in [-2.4, 2.4]) {
        scene.box(x + dx, -44.7, 1.8, 5.7, 25, 5.0,
            _Rcd2pMaterials.yellow.base, radius: .55, bevel: .28);
      }
      scene.box(x, -46.95, 6.85, 1.8, 25.9, 3.1,
          const Color(0xFFFFDA20), radius: .55, bevel: .25);
      scene.box(x, -43.2, 3.1, 2.9, 35.7, 2.0,
          const Color(0xFFE9BD15), radius: .48, bevel: .25);
    }
    scene.box(-12, 43.5, 7, 2.2, -22, 9,
        _Rcd2pMaterials.yellow.base, radius: .55, bevel: .25);
  }

  static void terminalEnclosures(_Scene scene) {
    for (final x in [-8.3, 8.3]) {
      scene.box(x, -41.3, 10, 2.2, 26, 9,
          _Rcd2pMaterials.recess.base, radius: .6, bevel: .34);
      scene.box(x, -41.3, 7.6, 1.3, 26.2, 1,
          const Color(0xFF909B95), radius: .35);
    }
  }
}
