import 'package:electrosim/main.dart' as app;
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/regression_fixture.dart';

Future<void> mount(WidgetTester t, Size size, double textScale) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      theme: ElectroSimTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: app.F9WorkspaceDemoPage(
        initialCircuit: buildRegressionFixtureCircuit(),
        initialSelectedElementId: 'lamp-1',
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'simulation command is labeled and represents actual controller state',
    (t) async {
      await mount(t, const Size(1440, 900), 1);
      expect(find.text('Lancer').hitTestable(), findsOneWidget);
      await t.tap(find.byKey(const Key('workspace-simulation-toggle')));
      await t.pump(const Duration(milliseconds: 40));
      expect(find.text('Pause').hitTestable(), findsOneWidget);
      await t.tap(find.byKey(const Key('workspace-simulation-toggle')));
      await t.pumpAndSettle();
      expect(find.text('Lancer'), findsOneWidget);
      await t.tap(find.byKey(const Key('workspace-more-actions')));
      await t.pumpAndSettle();
      expect(
        find
            .byKey(const Key('workspace-reset-simulation-action'))
            .hitTestable(),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'Mesures is clickable below permanent toolbar and shows real measurements',
    (t) async {
      await mount(t, const Size(1440, 900), 1);
      expect(
        find
            .descendant(of: find.byType(TabBar), matching: find.text('Mesures'))
            .hitTestable(),
        findsOneWidget,
      );
      await t.tap(
        find.descendant(
          of: find.byType(TabBar),
          matching: find.text('Mesures'),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find
            .descendant(of: find.byType(TabBar), matching: find.text('Mesures'))
            .hitTestable(),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );
  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    for (final scale in [1.5, 2.0]) {
      testWidgets('readable controls and inspector at $size text $scale', (
        t,
      ) async {
        await mount(t, size, scale);
        expect(
          find.byKey(const Key('workspace-simulation-toggle')).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('workspace-electrical-mode')).hitTestable(),
          findsOneWidget,
        );
        await t.tap(find.byKey(electroSimContextEdgeKey));
        await t.pumpAndSettle();
        expect(
          find
              .descendant(
                of: find.byType(TabBar),
                matching: find.text('Mesures'),
              )
              .hitTestable(),
          findsOneWidget,
        );
        await t.tap(
          find.descendant(
            of: find.byType(TabBar),
            matching: find.text('Mesures'),
          ),
        );
        await t.pumpAndSettle();
        final semantics = t.ensureSemantics();
        final targets = await androidTapTargetGuideline.evaluate(t);
        expect(targets.passed, isTrue, reason: targets.reason);
        final labels = await labeledTapTargetGuideline.evaluate(t);
        expect(labels.passed, isTrue, reason: labels.reason);
        semantics.dispose();
        expect(find.byType(SimulatorCanvas), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  }
}
