import 'dart:io';
import 'package:electrosim/main.dart';
import 'package:electrosim/runtime/workspace_layout_preferences.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final editFirst in [false, true]) {
    testWidgets(
      'preferences restore without overwriting early edits ($editFirst)',
      (t) async {
        t.view.physicalSize = const Size(1440, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final dir = (await t.runAsync(
          () => Directory.systemTemp.createTemp('electrosim-ui-pref-'),
        ))!;
        addTearDown(() async {
          await dir.delete(recursive: true);
        });
        final store = WorkspaceLayoutPreferences(
          File('${dir.path}/layout.json'),
        );
        await t.runAsync(
          () => store.save({
            'version': 1,
            'paletteWidth': 310,
            'paletteVisible': false,
          }),
        );
        late WorkspaceLayoutController layout;
        await t.runAsync(() async {
          await t.pumpWidget(
            MaterialApp(
              theme: ElectroSimTheme.light(),
              home: F18WorkspacePage(layoutPreferences: store),
            ),
          );
          layout = t
              .widget<ElectroSimWorkspaceShell>(
                find.byType(ElectroSimWorkspaceShell),
              )
              .layoutController!;
          if (editFirst) layout.setPaletteWidth(280);
          final deadline = Stopwatch()..start();
          while ((!editFirst && layout.paletteWidth != 310) &&
              deadline.elapsedMilliseconds < 2000) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          if (editFirst) {
            await Future<void>.delayed(const Duration(milliseconds: 30));
          }
        });
        await t.pumpAndSettle();
        expect(layout.paletteWidth, editFirst ? 280 : 310);
        expect(layout.paletteVisible, editFirst);
        layout.setPaletteWidth(300);
        await t.runAsync(() async {
          await t.pumpWidget(const SizedBox());
          final deadline = Stopwatch()..start();
          while ((await store.load())?['paletteWidth'] != 300 &&
              deadline.elapsedMilliseconds < 2000) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          expect((await store.load())!['paletteWidth'], 300);
        });
        expect(t.takeException(), isNull);
      },
    );
  }
}
