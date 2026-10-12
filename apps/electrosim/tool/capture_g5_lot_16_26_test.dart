import 'dart:io';
import 'dart:ui' as ui;
import 'package:electrosim/f18_workspace_page.dart';
import 'package:electrosim/f18_native_appliance_assets.dart';
import 'package:electrosim/f18_native_appliance_visual.dart';
import 'package:electrosim/f18_industrial_physical_plate.dart';
import 'package:electrosim/f9_component_palette.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test/g5_lot_16_26_fixtures.dart';
import '../test/g5_crusher_integration_test.dart' as fixtures;

void main() {
  const selected = String.fromEnvironment('G5_PROOF_KEYS');
  final specs = NativeApplianceGeometry.catalogue.values
      .where((s) => lastLotAndMeterKeys.contains(s.key))
      .where((s) => selected.isEmpty || selected.split(',').contains(s.key))
      .toList();
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final spec in specs) {
      await F18NativeApplianceAssets.load(spec.key);
    }
    for (final key in specs.map((s) => s.key)) {
      expect(
        F18NativeApplianceAssets.images(key),
        isNotNull,
        reason: 'Missing real assets $key',
      );
    }
    await F18PhysicalPlateAssets.preload();
    final fonts =
        '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
    for (final e in {
      'Roboto': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(
            Future.value(
              ByteData.sublistView(
                await File('$fonts/${e.value}').readAsBytes(),
              ),
            ),
          ))
          .load();
    }
  });
  for (final spec in specs) {
    testWidgets(
      '${spec.key} actual palette, front and native maintenance proof',
      (t) async {
        t.view.physicalSize = const Size(1600, 1000);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final c = lastLotFixture(spec);
        final l = fixtures.crusherRouter.routeAll(
          circuit: c,
          layout: lastLotLayout(spec),
        );
        final id = spec.key;
        final definition = f9PaletteCatalog.singleWhere(
          (d) => d.keyName == spec.key,
        );
        for (final service in [false, true]) {
          final key = GlobalKey();
          await t.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              home: RepaintBoundary(
                key: key,
                child: F18WorkspacePage(
                  key: ValueKey('${spec.key}-$service'),
                  initialCircuit: c,
                  initialVisualLayout: l,
                  initialSelectedElementId: service ? id : null,
                ),
              ),
            ),
          );
          await t.pump(const Duration(milliseconds: 800));
          await t.pump();
          await t.enterText(
            find.byKey(const Key('palette-search-field')),
            definition.title,
          );
          await t.pump(const Duration(milliseconds: 400));
          await t.pump();
          expect(t.takeException(), isNull);
          expect(
            find.byWidgetPredicate(
              (w) => w is F18NativeApplianceVisual && w.spec.key == spec.key,
            ),
            findsOneWidget,
          );
          final images = find
              .byType(RawImage)
              .evaluate()
              .map((e) => e.widget as RawImage);
          final textures = F18NativeApplianceAssets.images(spec.key)!;
          expect(
            images.any((w) => identical(w.image, textures.palette)),
            isTrue,
          );
          expect(
            images.any(
              (w) => identical(
                w.image,
                service ? textures.service : textures.front,
              ),
            ),
            isTrue,
          );
          final canvas = t.widget<SimulatorCanvas>(
            find.byType(SimulatorCanvas),
          );
          final component = canvas.circuit.components
              .where((c) => c.id.value == id)
              .firstOrNull;
          final source = canvas.circuit.sources
              .where((c) => c.id.value == id)
              .firstOrNull;
          expect(
            component?.terminals.length ?? source?.terminals.length,
            spec.ports.length,
          );
          expect(canvas.layout.sizeOf(id), spec.boardSize);
          await t.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 1.5);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
              'build/g5-lot-16-26-proof/${spec.key}-${service ? 'maintenance' : 'closed'}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
          if (service) {
            await t.tap(find.byKey(const Key('workspace-simulation-toggle')));
            await t.pump(const Duration(milliseconds: 200));
            await t.pump();
            final visual = t.widget<F18NativeApplianceVisual>(
              find.byWidgetPredicate(
                (w) => w is F18NativeApplianceVisual && w.spec.key == spec.key,
              ),
            );
            if (spec.key.startsWith('energy-meter-')) {
              expect(visual.meterReading?.available, isTrue);
              expect(visual.meterReading!.importWh, greaterThan(0));
              expect(
                find.byKey(Key('meter-power-${spec.key}')),
                findsOneWidget,
              );
            }
            expect(
              visual.energized,
              isTrue,
              reason: '${spec.key} is supplied by the real solver',
            );
            if (spec.key.startsWith('external-fan-')) {
              final rotor = find.byKey(Key('native-fan-rotor-${spec.key}'));
              expect(rotor, findsOneWidget);
              final before = List<double>.from(
                t.widget<Transform>(rotor).transform.storage,
              );
              await t.pump(const Duration(milliseconds: 137));
              expect(
                t.widget<Transform>(rotor).transform.storage.toList(),
                isNot(equals(before)),
                reason:
                    'The powered rotor advances while its guard stays fixed',
              );
            }
            await t.runAsync(() async {
              final image =
                  await (key.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage(pixelRatio: 1.5);
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                'build/g5-lot-16-26-proof/${spec.key}-running.png',
              ).writeAsBytes(data!.buffer.asUint8List());
              image.dispose();
            });
            await t.tap(find.byKey(const Key('workspace-simulation-toggle')));
            await t.pump();
            // Exercise the actual quick-add path; saved project sizes are a
            // separate migration test, not a fabricated preview-only instance.
            await t.tap(find.byKey(Key('palette-quick-add-${spec.key}')));
            await t.pump(const Duration(milliseconds: 300));
            final updated = t.widget<SimulatorCanvas>(
              find.byType(SimulatorCanvas),
            );
            final candidates = [
              ...updated.circuit.components,
              ...updated.circuit.sources,
            ];
            final dynamic added = candidates.singleWhere(
              (dynamic c) =>
                  c.id.value != id &&
                  c.id.value != 'grid' &&
                  c.id.value != 'socket' &&
                  c.id.value != 'inverter' &&
                  c.id.value != 'proof-load',
            );
            expect(added.terminals.length, spec.ports.length);
            expect(updated.layout.sizeOf(added.id.value), spec.boardSize);
            expect(t.takeException(), isNull);
          }
        }
      },
    );
  }
}
