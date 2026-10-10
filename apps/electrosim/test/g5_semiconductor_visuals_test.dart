import 'dart:ui' as ui;
import 'package:electrosim/f18_component_asset_visual.dart';
import 'package:electrosim/f18_industrial_physical_plate.dart';
import 'package:electrosim/f9_component_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'all six real semiconductor palette variants retain their identity',
    (t) async {
      expect(await t.runAsync(F18PhysicalPlateAssets.preload), isTrue);
      for (final key in [
        'diode',
        'diode-schottky',
        'zener-5v1',
        'tvs-12v',
        'led-red',
        'led-green',
      ]) {
        final definition = f9PaletteCatalog.firstWhere((d) => d.keyName == key);
        await t.pumpWidget(
          MaterialApp(home: F9ComponentPreview(definition: definition)),
        );
        await t.pumpAndSettle();
        expect(
          find.byType(F18IndustrialPhysicalPlate),
          findsOneWidget,
          reason: key,
        );
        final plate = t.widget<F18IndustrialPhysicalPlate>(
          find.byType(F18IndustrialPhysicalPlate),
        );
        expect(plate.variantKey, definition.visualVariant, reason: key);
        expect(plate.perspective, isTrue);
      }
    },
  );
  testWidgets('LED board state follows supplied engine state', (t) async {
    expect(await t.runAsync(F18PhysicalPlateAssets.preload), isTrue);
    final boundaryKey = GlobalKey();
    final frames = <List<int>>[];
    for (final energized in [false, true, false]) {
      await t.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: F18ComponentAssetVisual(
                modelType: 'diode',
                size: const Size(270, 105),
                variantKey: 'led-green',
                energized: energized,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(F18IndustrialPhysicalPlate), findsOneWidget);
      final plate = t.widget<F18IndustrialPhysicalPlate>(
        find.byType(F18IndustrialPhysicalPlate),
      );
      expect(plate.energized, energized);
      expect(plate.perspective, isFalse);
      expect(plate.accessibleState, energized ? 'allumée' : 'éteinte');
      expect(plate.accessibleName, 'LED verte');
      frames.add(
        (await t.runAsync(() async {
          final image =
              await (boundaryKey.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          try {
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            return bytes.buffer
                .asUint8List(bytes.offsetInBytes, bytes.lengthInBytes)
                .toList();
          } finally {
            image.dispose();
          }
        }))!,
      );
    }
    expect(
      frames[1],
      isNot(orderedEquals(frames[0])),
      reason: 'Powered LED must actually repaint its light',
    );
    expect(
      frames[2],
      orderedEquals(frames[0]),
      reason: 'Unpowered LED must recover the original appearance',
    );
  });
}
