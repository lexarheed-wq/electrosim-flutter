import 'dart:ui' as ui;
import 'package:electrosim/reference_components/disjoncteur_3d.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    expect(await Disjoncteur3D.prechargerTextures(), isTrue);
  });
  testWidgets('physical screw wells remain under all four electrical anchors', (
    tester,
  ) async {
    for (final size in [
      const Size(160, 260),
      const Size(320, 520),
      const Size(280, 430),
    ]) {
      for (final vue in VueDisjoncteur.values) {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: RepaintBoundary(
                key: key,
                child: Disjoncteur3D(
                  width: size.width,
                  height: size.height,
                  vue: vue,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          try {
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            final anchors = Disjoncteur3D.positionsBornes(size, vue: vue);
            for (final entry in anchors.entries) {
              final point = entry.value * 2;
              final x = point.dx.round(), y = point.dy.round();
              final offset = (y * image.width + x) * 4;
              final luminance =
                  (bytes.getUint8(offset) +
                      bytes.getUint8(offset + 1) +
                      bytes.getUint8(offset + 2)) /
                  3;
              expect(
                bytes.getUint8(offset + 3),
                greaterThan(240),
                reason: '${entry.key} at $size/$vue',
              );
              expect(
                luminance,
                lessThan(190),
                reason:
                    'The electrical anchor must land in the screw drive, not white polymer: ${entry.key} at $size/$vue',
              );
            }
          } finally {
            image.dispose();
          }
        });
        expect(tester.takeException(), isNull);
      }
    }
  });
}
