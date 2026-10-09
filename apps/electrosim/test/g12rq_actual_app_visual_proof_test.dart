import 'dart:io';
import 'package:flutter/services.dart';
import 'package:electrosim/f9_component_palette.dart';
import 'package:electrosim/f18_component_asset_visual.dart';
import 'package:electrosim/reference_components/disjoncteur_3d.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    expect(await Disjoncteur3D.prechargerTextures(), isTrue);
  });
  testWidgets('G5 proof uses the actual palette and board widgets', (tester) async {
    // Render readable typography in test mode, as in the G5 native showcase.
    final font = File('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');
    if (font.existsSync()) {
      final bytes = font.readAsBytesSync();
      await (FontLoader('Roboto')
        ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)))).load();
    }
    tester.view.physicalSize = const Size(1100, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final definition = f9PaletteCatalog.singleWhere(
      (item) => item.modelType == 'rcd_2p_ac1',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFFEDF1F4),
          body: RepaintBoundary(
            key: const Key('g5-actual-widgets-proof'),
            child: ColoredBox(
              color: const Color(0xFFEDF1F4),
              child: Center(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.center,
                spacing: 62,
                runSpacing: 32,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('CARTE PALETTE'),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 72,
                        height: 108,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: F9ComponentPreview(
                            definition: definition, compact: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('GLISSER SUR PLATINE'),
                      const SizedBox(height: 12),
                      F9ComponentPreview(definition: definition),
                    ],
                  ),
                  const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('PLATINE ELECTROSIM'),
                      SizedBox(height: 12),
                      F18ComponentAssetVisual(
                        modelType: 'rcd_2p_ac1',
                        size: Size(160, 260),
                        closed: false,
                        ratedCurrentA: 16,
                        residualTripCurrentA: 0.03,
                        showTerminals: false,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final views = tester.widgetList<Disjoncteur3D>(
      find.byType(Disjoncteur3D),
    ).toList();
    expect(views, hasLength(3));
    expect(views[0].vue, VueDisjoncteur.palette);
    expect(views[1].vue, VueDisjoncteur.palette);
    expect(views[2].vue, VueDisjoncteur.platine);
    expect(views[0].width, 66);
    expect(views[0].height, 107);
    expect(views[1].width, 112);
    expect(views[1].height, 182);
    expect(views[2].sensibiliteMA, 30);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const Key('g5-actual-widgets-proof')),
      matchesGoldenFile('goldens/g12rq_actual_widgets_palette_board.png'),
    );
  });
}
