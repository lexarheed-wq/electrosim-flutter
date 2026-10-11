import 'dart:io';
import 'dart:ui' as ui;

import 'package:electrosim/f18_voltmeter_3d_assets.dart';
import 'package:electrosim/f9_component_palette.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    expect(await F18Voltmeter3dAssets.preload(), isTrue);
    expect(F18Voltmeter3dAssets.front, isNotNull);
    expect(F18Voltmeter3dAssets.palette, isNotNull);
    expect(identical(F18Voltmeter3dAssets.palette, F18Voltmeter3dAssets.front),
        isFalse, reason: 'Palette uses perspective, not front image');
    final fontRoot =
        '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
    final loader = FontLoader('Roboto');
    for (final name in [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
    ]) {
      loader.addFont(Future.value(ByteData.sublistView(
        await File('$fontRoot/$name').readAsBytes(),
      )));
    }
    await loader.load();
    await (FontLoader('MaterialIcons')..addFont(
      Future.value(ByteData.sublistView(
        await File('$fontRoot/MaterialIcons-Regular.otf').readAsBytes(),
      )),
    )).load();
  });

  for (final mode in <ElectricalMode>[
    ElectricalMode.dc,
    ElectricalMode.ac1,
    ElectricalMode.ac3,
    ElectricalMode.pv,
  ]) {
    testWidgets('voltmeter is in compact 3/4 palette in ${mode.name}',
        (WidgetTester t) async {
      t.view.physicalSize = const Size(1100, 770);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      String? added;
      String? status;
      final key = GlobalKey();
      final rootKey = GlobalKey();
      await t.pumpWidget(RepaintBoundary(key: rootKey, child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFF2F4F7),
          body: RepaintBoundary(
            key: key,
            child: Row(
              children: [
                SizedBox(
                  width: 440,
                  child: F9ComponentPalette(
                    mode: mode,
                    onStatus: (message) => status = message,
                    onQuickAdd: (definition) => added = definition.keyName,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text('ElectroSim • vue palette 3/4',
                      style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      )));
      await t.pump(const Duration(milliseconds: 20));

      const item = Key('palette-item-instrument-voltmeter');
      const add = Key('palette-quick-add-instrument-voltmeter');
      const preview = Key('component-identity-preview-instrument-voltmeter');
      expect(find.byKey(item), findsOneWidget,
          reason: 'Voltmeter must be visible without searching');
      expect(find.byKey(preview), findsOneWidget);
      final raw = t.widget<RawImage>(find.descendant(
        of: find.byKey(item),
        matching: find.byType(RawImage),
      ));
      expect(raw.image, same(F18Voltmeter3dAssets.palette),
          reason: 'The true Cycles 3/4 asset must be shown in the palette');
      expect(raw.image, isNot(same(F18Voltmeter3dAssets.front)));
      expect(find.byKey(add), findsOneWidget);
      expect(find.text('Voltmètre physique'), findsOneWidget);
      expect(t.takeException(), isNull);

      if (mode == ElectricalMode.dc) {
        final out = Directory('build/g5-voltmeter-real-palette-proof');
        out.createSync(recursive: true);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await t.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1.4);
          try {
            final data =
                await image.toByteData(format: ui.ImageByteFormat.png);
            File('${out.path}/palette-3d-default-visible.png')
                .writeAsBytesSync(data!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
        expect(File('${out.path}/palette-3d-default-visible.png').existsSync(),
            isTrue);
        // The expanded detail is rendered by the REAL Tooltip overlay, not
        // an externally assembled image or a Blender-only product picture.
        const detailKey = Key('g5-voltmeter-3d-detail-preview');
        expect(find.byKey(detailKey), findsOneWidget);
        final mouse = await t.createGesture(kind: ui.PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(1, 1));
        await mouse.moveTo(t.getCenter(find.byKey(detailKey)));
        await t.pump(const Duration(milliseconds: 500));
        await t.pump(const Duration(milliseconds: 100));
        expect(find.text('Voltmètre — vue 3/4'), findsOneWidget);
        final expanded = rootKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        await t.runAsync(() async {
          final image = await expanded.toImage(pixelRatio: 1.5);
          try {
            final data =
                await image.toByteData(format: ui.ImageByteFormat.png);
            File('${out.path}/palette-3d-detail-zoom.png')
                .writeAsBytesSync(data!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
        expect(File('${out.path}/palette-3d-detail-zoom.png').existsSync(),
            isTrue);
        await mouse.removePointer();
        await t.pump();

        await t.enterText(
            find.byKey(const Key('palette-search-field')), 'voltmètre');
        await t.pump();
        expect(find.byKey(item), findsOneWidget);
        expect(find.descendant(
          of: find.byKey(item), matching: find.byKey(preview),
        ), findsOneWidget);
        expect(find.descendant(
          of: find.byKey(item), matching: find.byType(RawImage),
        ), findsOneWidget);
        await t.ensureVisible(find.byKey(add));
        await t.tap(find.byKey(add));
        expect(added, 'instrument-voltmeter');
        expect(t.takeException(), isNull);
        File('${out.path}/verification.txt').writeAsStringSync(
          'Flutter F9ComponentPalette real widget; category default Tous; '
          'instrument-voltmeter visible without search in modes DC, AC1, AC3, PV; '
          'uses decoded instrument-voltmeter-palette.png Cycles perspective '
          '(not the front texture). Button quick-add dispatches keyName. '
          'Status: ${status ?? "none"}\n',
        );
      }
      await t.pumpWidget(const SizedBox());
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
}
