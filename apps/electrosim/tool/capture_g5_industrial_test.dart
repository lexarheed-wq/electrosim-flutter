import 'dart:io';
import 'dart:ui' as ui;
import 'package:electrosim/main.dart';
import 'package:electrosim/f9_component_palette.dart';
import 'package:electrosim/reference_components/disjoncteur_3d.dart';
import 'package:electrosim/f18_industrial_physical_plate.dart';
import 'package:electrosim/f18_component_asset_visual.dart';
import 'package:electrosim/f18_industrial_dual_view.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final out = Directory(
    Platform.environment['ELECTROSIM_G5_PROOF_DIR'] ??
        'build/g5-industrial-proof',
  );
  setUpAll(() async {
    await out.create(recursive: true);
    expect(await Disjoncteur3D.prechargerTextures(), isTrue);
    expect(await F18PhysicalPlateAssets.preload(), isTrue);
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

  testWidgets('industrial housings in the real ElectroSim palette and board', (
    t,
  ) async {
    t.view.physicalSize = const Size(1440, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    for (final entry in [
      ('breaker_3p', 'disjoncteur'),
      ('contactor_3p', 'contacteur'),
      ('push_button_no', 'bouton'),
      ('motor_3p_6t', 'moteur'),
      ('lamp', 'lampe'),
      ('fuse_dc', 'fusible'),
      ('contactor_aux_no', 'auxiliaire'),
      ('contactor_aux_nc', 'auxiliaire'),
      ('relay_coil', 'bobine'),
      ('terminal_block_5', 'bornier'),
    ]) {
      final key = GlobalKey();
      final def = CoreComponentModelContracts.registry.resolve(entry.$1)!;
      final mode = ['fuse_dc', 'relay_coil'].contains(entry.$1)
          ? ElectricalMode.dc
          : ElectricalMode.ac3;
      final paletteDef = f9PaletteCatalog.firstWhere(
        (d) => d.modelType == entry.$1 && d.supportsMode(mode),
      );
      final circuit = CircuitState(
        circuitId: CircuitId('physical-${entry.$1}'),
        revision: 0,
        mode: mode,
        components: [
          ComponentInstance(
            id: ComponentId('Q1'),
            modelType: entry.$1,
            terminals: List.generate(
              def.terminalCount,
              (i) => Terminal(
                id: TerminalId('Q1-$i'),
                name: paletteDef.terminalLabels[i],
              ),
            ),
            parameters: paletteDef.defaultParameters,
            controlState: paletteDef.defaultControlState,
          ),
        ],
      );
      await t.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ElectroSimTheme.light(),
            home: F9WorkspaceDemoPage(
              initialCircuit: circuit,
              initialSelectedElementId: 'Q1',
              initialCabinetLayout:
                  [
                    'fuse_dc',
                    'contactor_aux_no',
                    'contactor_aux_nc',
                    'relay_coil',
                    'terminal_block_5',
                  ].contains(entry.$1)
                  ? CabinetLayout([
                      CabinetFixture(
                        id: 'DIN-NEW-INDUSTRIAL',
                        kind: CabinetFixtureKind.dinRail,
                        bounds: Rect.fromLTWH(
                          28,
                          96 +
                              (F18ReferenceComponentMetrics.boardSizeFor(
                                        entry.$1,
                                      ).height /
                                      2)
                                  .clamp(96, double.infinity) -
                              17,
                          F18ReferenceComponentMetrics.boardSizeFor(
                                entry.$1,
                              ).width +
                              160,
                          34,
                        ),
                      ),
                    ])
                  : null,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const Key('palette-search-field')),
        entry.$2,
      );
      await t.pumpAndSettle();
      final plates = t.widgetList<F18IndustrialPhysicalPlate>(
        find.byType(F18IndustrialPhysicalPlate),
      );
      expect(
        plates.any((p) => p.modelType == entry.$1 && p.perspective),
        isTrue,
      );
      expect(
        plates.any((p) => p.modelType == entry.$1 && !p.perspective),
        isTrue,
      );
      expect(t.takeException(), isNull);
      await save(t, key, 'electrosim-${entry.$1}');
      await t.pumpWidget(const SizedBox());
    }
  });
  testWidgets('mixed board preserves physical scale without overlaps', (
    t,
  ) async {
    t.view.physicalSize = const Size(1440, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final types = ['motor_3p_6t', 'breaker_3p', 'lamp'];
    final circuit = CircuitState(
      circuitId: CircuitId('physical-scale'),
      revision: 0,
      mode: ElectricalMode.ac3,
      components: [
        for (var j = 0; j < types.length; j++)
          ComponentInstance(
            id: ComponentId('E$j'),
            modelType: types[j],
            terminals: List.generate(
              CoreComponentModelContracts.registry
                  .resolve(types[j])!
                  .terminalCount,
              (i) => Terminal(id: TerminalId('E$j-$i'), name: '$i'),
            ),
          ),
      ],
    );
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: ElectroSimTheme.light(),
          debugShowCheckedModeBanner: false,
          home: F9WorkspaceDemoPage(
            initialCircuit: circuit,
            initialCabinetLayout: CabinetLayout([
              CabinetFixture(
                id: 'DIN-INTEGRATION',
                kind: CabinetFixtureKind.dinRail,
                bounds: const Rect.fromLTWH(846, 175, 240, 34),
              ),
              CabinetFixture(
                id: 'DUCT-INTEGRATION',
                kind: CabinetFixtureKind.wireDuct,
                bounds: const Rect.fromLTWH(48, 560, 1200, 42),
              ),
            ]),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final canvas = t.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    expect(canvas.layout.cabinetLayout.fixtures, hasLength(2));
    final rects = [
      for (var j = 0; j < types.length; j++)
        Rect.fromCenter(
          center: canvas.layout.positionOf('E$j')!,
          width: canvas.layout.sizeOf('E$j').width,
          height: canvas.layout.sizeOf('E$j').height,
        ),
    ];
    for (var a = 0; a < rects.length; a++) {
      for (var b = a + 1; b < rects.length; b++) {
        expect(rects[a].overlaps(rects[b]), isFalse);
      }
    }
    expect(
      canvas.layout.sizeOf('E0').width,
      greaterThan(canvas.layout.sizeOf('E1').width * 3),
    );
    expect(t.takeException(), isNull);
    await save(t, key, 'electrosim-echelle-moteur-protection-lampe');
    await save(t, key, 'electrosim-g5-p2-rails-goulotte');
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('complete catalogue appearance inventory', (t) async {
    t.view.physicalSize = const Size(1600, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    for (var page = 0; page < (f9PaletteCatalog.length / 12).ceil(); page++) {
      final key = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ElectroSimTheme.light(),
            home: Scaffold(
              backgroundColor: const Color(0xFFE9EDF1),
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'ElectroSim — contrôle des apparences · catalogue ${page + 1}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 4,
                        childAspectRatio: 1.14,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        children: [
                          for (final def
                              in f9PaletteCatalog.skip(page * 12).take(12))
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    def.title,
                                    maxLines: 2,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    def.keyName,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.blueGrey,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        for (final camera
                                            in F18IndustrialPresentation.values)
                                          Expanded(
                                            child: Column(
                                              children: [
                                                Text(
                                                  camera ==
                                                          F18IndustrialPresentation
                                                              .palettePerspective
                                                      ? 'Palette'
                                                      : 'Face',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: FittedBox(
                                                    child: F18IndustrialDualView(
                                                      modelType:
                                                          def.renderedModelType,
                                                      size:
                                                          def.kind ==
                                                              F9PaletteElementKind
                                                                  .instrument
                                                          ? const Size(112, 152)
                                                          : F18ReferenceComponentMetrics.boardSizeFor(
                                                              def.renderedModelType,
                                                            ),
                                                      presentation: camera,
                                                      child:
                                                          def.kind ==
                                                              F9PaletteElementKind
                                                                  .instrument
                                                          ? F18PhysicalInstrumentPreview(
                                                              ammeter:
                                                                  def.keyName ==
                                                                  'instrument-ammeter',
                                                            )
                                                          : F18ComponentAssetVisual(
                                                              modelType: def
                                                                  .renderedModelType,
                                                              variantKey: def
                                                                  .visualVariant,
                                                              size: F18ReferenceComponentMetrics.boardSizeFor(
                                                                def.renderedModelType,
                                                              ),
                                                              ratedCurrentA: 16,
                                                            ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await save(t, key, 'catalogue-complet-${page + 1}');
      await t.pumpWidget(const SizedBox());
    }
  });
  testWidgets('all industrial styles as actual production Flutter widgets', (
    t,
  ) async {
    t.view.physicalSize = const Size(1440, 1040);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final types = [
      'breaker_ac1',
      'breaker_3p',
      'breaker_4p',
      'contactor_ac1',
      'contactor_3p',
      'thermal_overload_3p',
      'push_button_no',
      'push_button_nc',
      'motor_3p_6t',
      'isolator_3p',
      'isolator_4p',
      'lamp',
      'fuse_dc',
      'contactor_aux_no',
      'contactor_aux_nc',
      'relay_coil',
      'terminal_block_5',
    ];
    for (var page = 0; page < (types.length / 9).ceil(); page++) {
      final key = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ElectroSimTheme.light(),
            home: Scaffold(
              backgroundColor: const Color(0xFFE9EDF1),
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'ElectroSim G5 · Palette en perspective / Platine de face',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 3,
                        childAspectRatio: 1.45,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        children: [
                          for (final type in types.skip(page * 9).take(9))
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFC),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    type == 'motor_3p_6t'
                                        ? 'Moteur triphasé'
                                        : f9PaletteCatalog
                                              .firstWhere(
                                                (item) =>
                                                    item.modelType == type,
                                              )
                                              .title,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Expanded(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        for (final camera
                                            in F18IndustrialPresentation.values)
                                          Expanded(
                                            child: Column(
                                              children: [
                                                Text(
                                                  camera ==
                                                          F18IndustrialPresentation
                                                              .palettePerspective
                                                      ? 'Palette'
                                                      : 'Platine',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: FittedBox(
                                                    child: F18IndustrialDualView(
                                                      modelType: type,
                                                      size:
                                                          F18ReferenceComponentMetrics.boardSizeFor(
                                                            type,
                                                          ),
                                                      presentation: camera,
                                                      child: F18ComponentAssetVisual(
                                                        modelType: type,
                                                        size:
                                                            F18ReferenceComponentMetrics.boardSizeFor(
                                                              type,
                                                            ),
                                                        closed: false,
                                                        ratedCurrentA: 16,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await save(t, key, 'industriels-perspective-face-${page + 1}');
      await t.pumpWidget(const SizedBox());
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
