import 'dart:ui' as ui;
import 'package:electrosim/f18_component_asset_visual.dart';
import 'package:electrosim/f18_industrial_physical_plate.dart';
import 'package:electrosim/f9_component_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const tenEquipmentKeys = [
  'switch-no',
  'source-dc-24v',
  'source-dc-current',
  'source-ac1-230v',
  'source-ac1-current',
  'pv-array',
  'pv-controller-mppt',
  'pv-controller-pwm',
  'pv-battery',
  'pv-inverter',
];
void main() {
  testWidgets('ten real catalogue entries receive their own physical palette', (
    t,
  ) async {
    expect(await t.runAsync(F18PhysicalPlateAssets.preload), isTrue);
    for (final key in tenEquipmentKeys) {
      final d = f9PaletteCatalog.firstWhere((d) => d.keyName == key);
      await t.pumpWidget(MaterialApp(home: F9ComponentPreview(definition: d)));
      await t.pumpAndSettle();
      expect(
        find.byType(F18IndustrialPhysicalPlate),
        findsOneWidget,
        reason: key,
      );
      final plate = t.widget<F18IndustrialPhysicalPlate>(
        find.byType(F18IndustrialPhysicalPlate),
      );
      expect(plate.perspective, isTrue, reason: key);
      expect(plate.variantKey, d.visualVariant);
      if (key == 'pv-battery') expect(plate.accessibleState, 'charge 60 %');
      if (key == 'source-dc-24v') expect(plate.voltageV, 24);
      if (key == 'source-ac1-230v') expect(plate.voltageV, 230);
      if (key == 'source-ac1-current') expect(plate.currentA, 1);
    }
  });
  testWidgets('PV rear junction detail opens without changing the board view', (
    t,
  ) async {
    expect(await t.runAsync(F18PhysicalPlateAssets.preload), isTrue);
    await t.pumpWidget(
      const MaterialApp(
        home: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              F18PvRearJunctionAction(),
              F18ComponentAssetVisual(
                modelType: 'pv_array',
                size: Size(220, 170),
              ),
            ],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Voir le bornier arrière'));
    await t.pumpAndSettle();
    expect(find.text('Bornier arrière du panneau'), findsOneWidget);
    expect(find.byType(RawImage), findsOneWidget);
    await t.tap(find.text('Fermer'));
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      t
          .widget<F18IndustrialPhysicalPlate>(
            find.byType(F18IndustrialPhysicalPlate),
          )
          .perspective,
      isFalse,
    );
  });
  testWidgets('rear junction dialog remains usable on a compact screen', (
    t,
  ) async {
    t.view.physicalSize = const Size(360, 480);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    expect(await t.runAsync(F18PhysicalPlateAssets.preload), isTrue);
    await t.pumpWidget(
      const MaterialApp(
        home: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              F18PvRearJunctionAction(),
              F18ComponentAssetVisual(
                modelType: 'pv_array',
                size: Size(220, 170),
              ),
            ],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Voir le bornier arrière'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Fermer'), findsOneWidget);
    await t.tap(find.text('Fermer'));
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('battery display preserves supplied state of charge', (t) async {
    expect(await t.runAsync(F18PhysicalPlateAssets.preload), isTrue);
    for (final soc in [.25, .75]) {
      await t.pumpWidget(
        MaterialApp(
          home: F18ComponentAssetVisual(
            modelType: 'pv_battery',
            size: const Size(210, 170),
            batterySoc: soc,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(F18IndustrialPhysicalPlate), findsOneWidget);
      expect(
        t
            .widget<F18IndustrialPhysicalPlate>(
              find.byType(F18IndustrialPhysicalPlate),
            )
            .accessibleState,
        'charge ${(soc * 100).round()} %',
      );
    }
  });
  testWidgets('physical switch lever changes and restores its actual pixels', (
    t,
  ) async {
    expect(await t.runAsync(F18PhysicalPlateAssets.preload), isTrue);
    final key = GlobalKey();
    final frames = <List<int>>[];
    for (final closed in [false, true, false]) {
      await t.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: F18ComponentAssetVisual(
                modelType: 'switch',
                size: const Size(90, 140),
                closed: closed,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(F18IndustrialPhysicalPlate), findsOneWidget);
      frames.add(
        (await t.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          try {
            final b = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            return b.buffer
                .asUint8List(b.offsetInBytes, b.lengthInBytes)
                .toList();
          } finally {
            image.dispose();
          }
        }))!,
      );
    }
    expect(frames[1], isNot(orderedEquals(frames[0])));
    expect(frames[2], orderedEquals(frames[0]));
  });
}
