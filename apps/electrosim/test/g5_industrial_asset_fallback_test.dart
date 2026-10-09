import 'dart:io';
import 'dart:ui' as ui;
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/rendering.dart';
import 'package:electrosim/f18_component_asset_visual.dart';
import 'package:electrosim/f18_industrial_physical_plate.dart';
import 'package:electrosim/f18_industrial_physical_devices.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  var loads = 0;
  setUpAll(() async {
    binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (
      message,
    ) async {
      final path = String.fromCharCodes(
        message!.buffer.asUint8List(
          message.offsetInBytes,
          message.lengthInBytes,
        ),
      );
      loads++;
      if (path == 'assets/g5_industrial/breaker1-palette.png' ||
          path == 'assets/g5_industrial/button-no-controls-front.png' ||
          path == 'assets/g5_industrial/lamp-palette.png') {
        return null;
      }
      final file = File(path);
      return file.existsSync()
          ? ByteData.sublistView(await file.readAsBytes())
          : null;
    });
    expect(await F18PhysicalPlateAssets.preload(), isFalse);
  });
  tearDownAll(
    () => binding.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      null,
    ),
  );
  testWidgets('missing palette texture retains native front and controls', (
    t,
  ) async {
    expect(F18PhysicalPlateAssets.ready('breaker_ac1'), isFalse);
    expect(F18PhysicalPlateAssets.ready('contactor_3p'), isTrue);
    expect(F18PhysicalPlateAssets.ready('push_button_no'), isFalse);
    await t.pumpWidget(
      const MaterialApp(
        home: F18ComponentAssetVisual(
          modelType: 'breaker_ac1',
          size: Size(72, 160),
          closed: false,
          tripped: true,
        ),
      ),
    );
    final native = t.widget<IndustrialPhysicalView>(
      find.byType(IndustrialPhysicalView),
    );
    expect(native.closed, isFalse);
    expect(native.tripped, isTrue);
    expect(find.byType(F18IndustrialPhysicalPlate), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('missing lamp texture retains the new Canvas port positions', (
    t,
  ) async {
    final size = F18ReferenceComponentMetrics.boardSizeFor('lamp');
    final key = GlobalKey();
    await t.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: F18ComponentAssetVisual(modelType: 'lamp', size: size),
          ),
        ),
      ),
    );
    expect(F18PhysicalPlateAssets.ready('lamp'), isFalse);
    expect(find.byType(IndustrialPhysicalView), findsOneWidget);
    await t.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      for (var i = 0; i < 2; i++) {
        final p =
            size.center(Offset.zero) +
            TerminalVisualProfile.terminalOffset(
              modelType: 'lamp',
              size: size,
              index: i,
              count: 2,
            );
        final pixel = (p.dy.round() * image.width + p.dx.round()) * 4;
        expect(
          bytes.getUint8(pixel + 3),
          greaterThan(240),
          reason: 'Native lamp port $i must be on its terminal',
        );
      }
      image.dispose();
    });
  });
  test('preload is memoized even after a failed pair', () async {
    final before = loads;
    final a = F18PhysicalPlateAssets.preload(),
        b = F18PhysicalPlateAssets.preload();
    expect(identical(a, b), isTrue);
    expect(await a, isFalse);
    expect(loads, before);
  });
}
