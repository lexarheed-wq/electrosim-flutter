import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> mount(
  WidgetTester t,
  Size size, {
  WorkspaceLayoutController? controller,
  bool reduce = false,
  bool locked = false,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: reduce),
        child: Scaffold(
          body: ElectroSimWorkspaceShell(
            layoutController: controller,
            interactionLocked: locked,
            topBar: const SizedBox(height: 64, child: Text('Commandes')),
            canvas: const ColoredBox(
              color: Colors.white,
              child: Text('Circuit'),
            ),
            palette: const Text('Catalogue disponible'),
            contextPanel: const Text('Mesures disponibles'),
            statusBar: const SizedBox(height: 40, child: Text('Arrêtée')),
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('desktop panels never overlap canvas or permanent command bars', (
    t,
  ) async {
    await mount(t, const Size(1440, 900));
    final canvas = t.getRect(find.byKey(electroSimCanvasRegionKey));
    final palette = t.getRect(find.byKey(electroSimPaletteRegionKey));
    final inspector = t.getRect(find.byKey(electroSimContextRegionKey));
    final top = t.getRect(find.byKey(electroSimTopRegionKey));
    final status = t.getRect(find.byKey(electroSimStatusRegionKey));
    expect(canvas.overlaps(palette), isFalse);
    expect(canvas.overlaps(inspector), isFalse);
    expect(palette.overlaps(top), isFalse);
    expect(inspector.overlaps(top), isFalse);
    expect(inspector.overlaps(status), isFalse);
    expect(find.text('Catalogue disponible').hitTestable(), findsOneWidget);
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Catalogue disponible').hitTestable(), findsOneWidget);
  });
  testWidgets('separator resizes only its own dock', (t) async {
    final c = WorkspaceLayoutController();
    addTearDown(c.dispose);
    await mount(t, const Size(1440, 900), controller: c);
    await t.drag(
      find.byKey(const Key('workspace-palette-resizer')),
      const Offset(30, 0),
    );
    await t.pumpAndSettle();
    expect(c.paletteWidth, closeTo(294, 1));
    expect(c.contextWidth, 304);
  });
  for (final size in [const Size(390, 844), const Size(820, 1180)]) {
    testWidgets(
      'narrow $size exposes just one modal panel and Escape restores focus',
      (t) async {
        await mount(t, size);
        await t.tap(find.byKey(electroSimPaletteEdgeKey));
        await t.pumpAndSettle();
        expect(find.text('Catalogue disponible').hitTestable(), findsOneWidget);
        await t.tap(find.byKey(electroSimContextEdgeKey));
        await t.pumpAndSettle();
        expect(find.text('Catalogue disponible').hitTestable(), findsNothing);
        expect(find.text('Mesures disponibles').hitTestable(), findsOneWidget);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(find.text('Mesures disponibles').hitTestable(), findsNothing);
        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          'workspace-context-toggle',
        );
        final semantics = t.ensureSemantics();
        final targets = await androidTapTargetGuideline.evaluate(t);
        expect(targets.passed, isTrue, reason: targets.reason);
        final labels = await labeledTapTargetGuideline.evaluate(t);
        expect(labels.passed, isTrue, reason: labels.reason);
        semantics.dispose();
      },
    );
  }
  testWidgets('maximum widths fall back safely at 1200', (t) async {
    final c = WorkspaceLayoutController()
      ..setPaletteWidth(360)
      ..setContextWidth(440);
    addTearDown(c.dispose);
    await mount(t, const Size(1200, 900), controller: c);
    expect(
      t.getRect(find.byKey(electroSimCanvasRegionKey)).width,
      greaterThanOrEqualTo(480),
    );
    expect(
      find.text('Catalogue disponible').hitTestable().evaluate().length +
          find.text('Mesures disponibles').hitTestable().evaluate().length,
      lessThanOrEqualTo(1),
    );
  });
  testWidgets(
    'reduced animations close instantly and disposed transitions are safe',
    (t) async {
      await mount(t, const Size(1440, 900), reduce: true);
      await t.tap(find.byKey(electroSimPaletteEdgeKey));
      await t.pump();
      expect(find.text('Catalogue disponible').hitTestable(), findsNothing);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(milliseconds: 500));
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('locked interaction prevents separator drag', (t) async {
    final c = WorkspaceLayoutController();
    addTearDown(c.dispose);
    await mount(t, const Size(1440, 900), controller: c, locked: true);
    await t.drag(
      find.byKey(const Key('workspace-palette-resizer')),
      const Offset(40, 0),
    );
    await t.pumpAndSettle();
    expect(c.paletteWidth, 264);
  });
  testWidgets(
    'closing drawer leaves no keyboard targets during its exit transition',
    (t) async {
      await mount(t, const Size(390, 844));
      await t.tap(find.byKey(electroSimContextEdgeKey));
      await t.pumpAndSettle();
      await t.tap(find.byKey(electroSimContextPinKey));
      await t.pump(const Duration(milliseconds: 20));
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      var insideClosingPanel = false;
      FocusManager.instance.primaryFocus?.context?.visitAncestorElements((
        element,
      ) {
        if (element.widget.key == electroSimContextRegionKey) {
          insideClosingPanel = true;
        }
        return true;
      });
      expect(insideClosingPanel, isFalse);
      await t.pumpAndSettle();
    },
  );
}
