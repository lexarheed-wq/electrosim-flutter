import 'dart:io';
import 'dart:ui' as ui;
import 'package:electrosim/main.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim/reference_components/disjoncteur_3d.dart';
import 'package:electrosim/f18_premium_rcd2p_showcase.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final out = Directory(
    Platform.environment['ELECTROSIM_G5_PROOF_DIR'] ??
        'build/g5-reference-proof',
  );
  setUpAll(() async {
    await out.create(recursive: true);
    expect(await Disjoncteur3D.prechargerTextures(), isTrue);
    final fonts =
        '${Platform.environment['FLUTTER_ROOT'] ?? _flutterRoot()}/bin/cache/artifacts/material_fonts';
    final loader = FontLoader('Roboto');
    for (final file in [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
    ]) {
      loader.addFont(
        Future.value(
          ByteData.sublistView(await File('$fonts/$file').readAsBytes()),
        ),
      );
    }
    await loader.load();
    await (FontLoader('MaterialIcons')..addFont(
          Future.value(
            ByteData.sublistView(
              await File('$fonts/MaterialIcons-Regular.otf').readAsBytes(),
            ),
          ),
        ))
        .load();
  });
  Future<void> save(WidgetTester t, GlobalKey key, String name) async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await t.runAsync(() async {
      final img = await boundary.toImage(pixelRatio: 1.5);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '${out.path}/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      img.dispose();
    });
  }

  testWidgets('real ElectroSim palette perspective and board front', (t) async {
    t.view.physicalSize = const Size(1440, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final key = GlobalKey();
    final def = CoreComponentModelContracts.registry.resolve('rcd_2p_ac1')!;
    final circuit = CircuitState(
      circuitId: CircuitId('visual-proof-rcd'),
      revision: 0,
      mode: ElectricalMode.ac1,
      components: [
        ComponentInstance(
          id: ComponentId('Q1'),
          modelType: 'rcd_2p_ac1',
          terminals: [
            for (var i = 0; i < 4; i++)
              Terminal(
                id: TerminalId('Q1-$i'),
                name: ['N entrée', 'L entrée', 'N sortie', 'L sortie'][i],
                phase: i.isEven ? PhaseTag.neutral : PhaseTag.l1,
              ),
          ],
          parameters: {
            ProtectionRating.ratedCurrentKey: 16.0,
            ComponentParameterKeys.residualTripCurrentA: .03,
          },
          controlState: const {'closed': false, 'tripped': false},
        ),
      ],
    );
    expect(def.terminalCount, 4);
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ElectroSimTheme.light(),
          home: F9WorkspaceDemoPage(
            initialCircuit: circuit,
            initialSelectedElementId: 'Q1',
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const Key('palette-search-field')),
      'différentiel',
    );
    await t.pumpAndSettle();
    final widgets = t.widgetList<Disjoncteur3D>(find.byType(Disjoncteur3D));
    expect(widgets.any((w) => w.vue == VueDisjoncteur.palette), isTrue);
    expect(widgets.any((w) => w.vue == VueDisjoncteur.platine), isTrue);
    final scenes = t
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((paint) => paint.painter)
        .whereType<CircuitScenePainter>();
    expect(scenes.single.paintElementChrome, isFalse);
    expect(scenes.single.dinSupportsAtBuild, hasLength(1));
    expect(t.takeException(), isNull);
    await save(t, key, 'electrosim-palette-platine');
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('large real Flutter component detail', (t) async {
    t.view.physicalSize = const Size(1100, 760);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: F18PremiumRcd2pShowcase()),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await save(t, key, 'detail-perspective-face');
    for (final vue in VueDisjoncteur.values) {
      final f = find.byKey(Key('premium-rcd-${vue.name}'));
      final boundary = t.renderObject<RenderRepaintBoundary>(
        find.descendant(of: f, matching: find.byType(RepaintBoundary)).first,
      );
      await t.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 3);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${out.path}/composant-${vue.name}.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}

// Flutter test runs under flutter_tester in bin/cache/artifacts/engine/<target>.
String _flutterRoot() {
  var directory = File(Platform.resolvedExecutable).parent;
  while (directory.parent.path != directory.path) {
    if (File('${directory.path}/bin/flutter').existsSync()) {
      return directory.path;
    }
    directory = directory.parent;
  }
  throw StateError(
    'Set FLUTTER_ROOT to the Flutter SDK directory for capture fonts.',
  );
}
