import 'dart:ui' as ui;
import 'package:electrosim/reference_components/disjoncteur_3d.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'perspective housing has no transparent holes through its flank',
    (t) async {
      final key = GlobalKey();
      await t.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: const Disjoncteur3D(
                width: 280,
                height: 430,
                vue: VueDisjoncteur.palette,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await t.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        for (final y in [140, 180, 220]) {
          final i = (y * image.width + 215) * 4;
          expect(
            bytes.getUint8(i + 3),
            greaterThan(240),
            reason: 'Closed moulded side at (215,$y)',
          );
        }
        image.dispose();
      });
      expect(t.takeException(), isNull);
    },
  );
}
