import 'dart:convert';
import 'dart:io';
import 'package:electrosim/f9_component_palette.dart';
import 'package:electrosim/f18_component_asset_visual.dart';
import 'package:electrosim/f18_native_appliance_assets.dart';
import 'package:electrosim/f18_industrial_physical_plate.dart';
import 'package:electrosim/f18_crusher_3d_assets.dart';
import 'package:electrosim/f18_voltmeter_3d_assets.dart';
import 'package:electrosim/f18_ammeter_3d_assets.dart';
import 'package:electrosim/f18_frequency_3d_assets.dart';
import 'package:electrosim/f18_phase_sequence_3d_assets.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('audit every palette entry after real asset decoding', (t) async {
    await t.runAsync(() async {
      await F18PhysicalPlateAssets.preload();
      await F18Crusher3dAssets.preload();
      await F18Voltmeter3dAssets.preload();
      await F18Ammeter3dAssets.preload();
      await F18Frequency3dAssets.preload();
      await F18PhaseSequence3dAssets.preload();
      for (final spec in NativeApplianceGeometry.catalogue.values) {
        await F18NativeApplianceAssets.load(spec.key);
      }
    });
    final rows = <Map<String, Object?>>[], errors = <String>[];
    final ids = <String>{};
    for (final d in f9PaletteCatalog) {
      if (!ids.add(d.keyName)) errors.add('duplicate palette key ${d.keyName}');
      final contract = CoreComponentModelContracts.registry.resolve(
        d.modelType,
      );
      if (d.kind == F9PaletteElementKind.component) {
        if (contract == null) {
          errors.add('missing contract ${d.keyName}: ${d.modelType}');
        } else if (contract.terminalCount != d.terminalCount) {
          errors.add(
            '${d.keyName}: palette ${d.terminalCount}, contract ${contract.terminalCount}',
          );
        }
      }
      final native = NativeApplianceGeometry.forVisual(
        d.renderedModelType,
        d.visualVariant,
      );
      String rendering = 'vector';
      if (native != null &&
          F18NativeApplianceAssets.images(native.key) != null) {
        rendering = 'Cycles mesh';
      } else if (d.keyName == 'external-crusher' && F18Crusher3dAssets.ready) {
        rendering = 'Cycles mesh';
      } else if (F18PhysicalPlateAssets.ready(
        d.renderedModelType,
        variantKey: d.visualVariant,
      )) {
        rendering = 'Cycles mesh';
      } else if (d.kind == F9PaletteElementKind.instrument) {
        final ready = switch (d.keyName) {
          'instrument-voltmeter' => F18Voltmeter3dAssets.ready,
          'instrument-ammeter' => F18Ammeter3dAssets.ready,
          'instrument-frequency' => F18Frequency3dAssets.ready,
          'instrument-phase-sequence' => F18PhaseSequence3dAssets.ready,
          _ => false,
        };
        rendering = ready ? 'Cycles mesh' : 'instrument vector';
      } else if (d.modelType == 'rcd_2p_ac1') {
        rendering = 'Dart perspective painter';
      }
      await t.pumpWidget(
        MaterialApp(
          home: Center(child: F9ComponentPreview(definition: d)),
        ),
      );
      expect(t.takeException(), isNull, reason: d.keyName);
      final context = t.element(find.byType(F9ComponentPreview));
      String? boardWidget;
      if (d.kind != F9PaletteElementKind.instrument) {
        boardWidget = F18ComponentAssetVisual(
          modelType: d.renderedModelType,
          variantKey: d.visualVariant,
          size: const Size(200, 200),
        ).build(context).runtimeType.toString();
        if (boardWidget == 'F18ComponentIdentityVisual') {
          errors.add('generic identity fallback ${d.keyName}');
        }
        await t.pumpWidget(
          MaterialApp(
            home: Center(
              child: F18ComponentAssetVisual(
                modelType: d.renderedModelType,
                variantKey: d.visualVariant,
                size: F18ReferenceComponentMetrics.boardSizeFor(
                  d.renderedModelType,
                  variantKey: d.visualVariant,
                ),
                serviceOpen: true,
              ),
            ),
          ),
        );
        expect(
          t.takeException(),
          isNull,
          reason: '${d.keyName} board painting',
        );
      }
      if (d.keyName.startsWith('power_socket_') && rendering != 'Cycles mesh') {
        errors.add('${d.keyName}: socket has no real 3D assets');
      }
      rows.add({
        'key': d.keyName,
        'title': d.title,
        'model': d.modelType,
        'visualModel': d.renderedModelType,
        'variant': d.visualVariant,
        'kind': d.kind.name,
        'palettePorts': d.terminalCount,
        'contractPorts': contract?.terminalCount,
        'nativePhysicalPorts': native?.ports.length,
        'modes': [
          for (final mode in ElectricalMode.values)
            if (d.supportsMode(mode)) mode.name,
        ],
        'rendering': rendering,
        'boardWidget': boardWidget,
      });
    }
    await t.runAsync(() async {
      final file = File('build/g5-catalogue-audit.json');
      await file.parent.create(recursive: true);
      await file.writeAsString(
        const JsonEncoder.withIndent(
          '  ',
        ).convert({'entries': rows, 'errors': errors}),
      );
    });
    expect(errors, isEmpty);
  });
}
