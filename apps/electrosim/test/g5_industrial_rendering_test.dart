import 'dart:ui' as ui;
import 'package:electrosim/f18_component_asset_visual.dart';
import 'package:electrosim/f18_industrial_physical_plate.dart';
import 'package:electrosim/f18_industrial_dual_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    expect(await F18PhysicalPlateAssets.preload(), isTrue);
  });
  Future<List<int>> pixels(
    WidgetTester t,
    String type, {
    bool closed = true,
    bool tripped = false,
    bool pressed = false,
    bool actuated = false,
    bool energized = false,
    double phase = 0,
    double voltageV = 24,
    bool perspective = false,
  }) async {
    final key = GlobalKey();
    final size = F18ReferenceComponentMetrics.boardSizeFor(type);
    Widget view = F18ComponentAssetVisual(
      modelType: type,
      size: size,
      closed: closed,
      tripped: tripped,
      pressed: pressed,
      actuated: actuated,
      energized: energized,
      voltageV: voltageV,
      animationValue: phase,
    );
    if (perspective) {
      view = F18IndustrialDualView(
        modelType: type,
        size: size,
        presentation: F18IndustrialPresentation.palettePerspective,
        child: view,
      );
    }
    await t.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(key: key, child: view),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    final plate = t.widget<F18IndustrialPhysicalPlate>(
      find.byType(F18IndustrialPhysicalPlate),
    );
    expect(plate.perspective, perspective);
    return (await t.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      try {
        return (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List().toList();
      } finally {
        image.dispose();
      }
    }))!;
  }

  testWidgets('physical controls still reflect live engine states', (t) async {
    for (final type in [
      'breaker_ac1',
      'breaker_3p',
      'breaker_4p',
      'isolator_3p',
    ]) {
      final on = await pixels(t, type);
      final off = await pixels(t, type, closed: false);
      expect(off, isNot(equals(on)), reason: type);
      if (type.startsWith('breaker')) {
        final trip = await pixels(t, type, tripped: true);
        expect(trip, isNot(equals(on)), reason: type);
        expect(trip, isNot(equals(off)), reason: type);
      }
    }
    for (final type in ['push_button_no', 'push_button_nc']) {
      expect(
        await pixels(t, type, pressed: true),
        isNot(equals(await pixels(t, type))),
        reason: type,
      );
    }
    expect(
      await pixels(t, 'contactor_3p', actuated: true),
      isNot(equals(await pixels(t, 'contactor_3p'))),
    );
    expect(
      await pixels(t, 'thermal_overload_3p', tripped: true),
      isNot(equals(await pixels(t, 'thermal_overload_3p'))),
    );
  });
  testWidgets('new industrial families retain live electrical indications', (
    t,
  ) async {
    for (final type in [
      'contactor_aux_no',
      'contactor_aux_nc',
      'relay_contact_no',
      'relay_contact_nc',
    ]) {
      expect(
        await pixels(t, type, actuated: false),
        isNot(equals(await pixels(t, type, actuated: true))),
        reason: type,
      );
    }
    expect(
      await pixels(t, 'relay_coil', energized: true),
      isNot(equals(await pixels(t, 'relay_coil'))),
    );
    for (final type in ['fuse_dc', 'fuse_ac1', 'fuse']) {
      expect(
        await pixels(t, type, tripped: true),
        isNot(equals(await pixels(t, type))),
        reason: type,
      );
    }
    for (final type in [
      'fuse_dc',
      'contactor_aux_no',
      'contactor_aux_nc',
      'relay_coil',
      'terminal_block_5',
    ]) {
      expect(
        await pixels(t, type, perspective: true),
        isNot(equals(await pixels(t, type))),
        reason: type,
      );
    }
  });
  testWidgets('incandescent filament brightness follows voltage', (t) async {
    final off = await pixels(t, 'lamp', voltageV: 0);
    final six = await pixels(t, 'lamp', energized: true, voltageV: 6);
    final twelve = await pixels(t, 'lamp', energized: true, voltageV: 12);
    final rated = await pixels(t, 'lamp', energized: true, voltageV: 24);
    expect(six, isNot(equals(off)));
    expect(twelve, isNot(equals(six)));
    expect(rated, isNot(equals(twelve)));
    expect(
      await pixels(t, 'lamp', energized: true, voltageV: -24),
      equals(rated),
    );
  });
  testWidgets('palette has a real camera while board stays frontal', (t) async {
    for (final type in [
      'breaker_ac1',
      'contactor_3p',
      'push_button_nc',
      'motor_3p_6t',
    ]) {
      expect(
        await pixels(t, type, perspective: true),
        isNot(equals(await pixels(t, type))),
        reason: type,
      );
    }
  });
  testWidgets('moving receiver keeps its housing stationary', (t) async {
    final a = await pixels(t, 'motor_3p_6t', energized: true, phase: 0);
    final b = await pixels(t, 'motor_3p_6t', energized: true, phase: .25);
    expect(a, isNot(equals(b)));
    final size = F18ReferenceComponentMetrics.boardSizeFor('motor_3p_6t');
    // The animation must not alter the centre of the cast motor body.
    final i =
        ((size.height * .48).round() * size.width.toInt() +
            (size.width * .5).round()) *
        4;
    expect(a.sublist(i, i + 4), b.sublist(i, i + 4));
  });
  testWidgets('animation phase does not repaint stationary industrial parts', (
    t,
  ) async {
    for (final type in [
      'breaker_3p',
      'contactor_3p',
      'push_button_no',
      'fuse_dc',
      'contactor_aux_no',
      'contactor_aux_nc',
      'relay_coil',
      'terminal_block_5',
    ]) {
      await pixels(t, type, phase: 0);
      final finder = find.descendant(
        of: find.byType(F18IndustrialPhysicalPlate),
        matching: find.byType(CustomPaint),
      );
      final before = t.widget<CustomPaint>(finder).painter!;
      await pixels(t, type, phase: .25);
      final after = t.widget<CustomPaint>(finder).painter!;
      expect(after.shouldRepaint(before), isFalse, reason: type);
    }
    await pixels(t, 'motor_3p_6t', energized: true, phase: 0);
    final finder = find.descendant(
      of: find.byType(F18IndustrialPhysicalPlate),
      matching: find.byType(CustomPaint),
    );
    final before = t.widget<CustomPaint>(finder).painter!;
    await pixels(t, 'motor_3p_6t', energized: true, phase: .25);
    expect(
      t.widget<CustomPaint>(finder).painter!.shouldRepaint(before),
      isTrue,
    );
  });
}
