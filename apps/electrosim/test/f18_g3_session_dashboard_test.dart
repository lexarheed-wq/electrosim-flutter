import 'package:electrosim/main.dart' as app;
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void _desktop(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
}

Future<void> _openSession(WidgetTester tester) async {
  await tester.pumpWidget(const app.ElectroSimApp());
  await tester.tap(find.byKey(const Key('home-create-session')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('session-create-dialog')), findsOneWidget);
  await tester.tap(find.byKey(const Key('session-create-confirm')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('session-waiting-room-page')), findsOneWidget);
  await _pumpUntil(tester, find.byKey(const Key('session-waiting-qr')));
  expect(find.byKey(const Key('session-waiting-browser-url')), findsOneWidget);
  await tester.tap(find.byKey(const Key('session-waiting-continue')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('session-shell-page')), findsOneWidget);
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final Stopwatch stopwatch = Stopwatch()..start();
  while (finder.evaluate().isEmpty) {
    if (stopwatch.elapsed > timeout) {
      fail('Timed out waiting for widget: $finder');
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

Future<void> _ensureTopOpen(WidgetTester tester) async {
  final Finder region = find.byKey(electroSimTopRegionKey);
  if (region.evaluate().isEmpty || tester.getRect(region).bottom <= 0) {
    await tester.tap(find.byKey(electroSimTopEdgeKey));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('resume preserves the teacher workshop being prepared', (
    tester,
  ) async {
    _desktop(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _openSession(tester);
    await tester.tap(find.byKey(const Key('dashboard-wiring')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('activity-setup-open-workshop')));
    await tester.pumpAndSettle();
    final originalCanvas = tester.state(find.byType(SimulatorCanvas));
    await _ensureTopOpen(tester);
    await tester.tap(find.byKey(const Key('session-home-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-create-session')));
    await tester.pumpAndSettle();
    expect(find.byType(SimulatorCanvas), findsOneWidget);
    expect(tester.state(find.byType(SimulatorCanvas)), same(originalCanvas));
  });

  testWidgets(
    'maintenance navigation from home keeps the active teacher session',
    (tester) async {
      _desktop(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _openSession(tester);
      await tester.tap(find.byKey(const Key('session-home-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home-maintenance')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('center-home-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home-create-session')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('session-shell-page')), findsOneWidget);
      expect(find.byKey(const Key('session-create-dialog')), findsNothing);
    },
  );

  testWidgets('system back preserves the teacher session', (tester) async {
    _desktop(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _openSession(tester);
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    await navigator.maybePop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-create-session')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('session-shell-page')), findsOneWidget);
    expect(find.byKey(const Key('session-create-dialog')), findsNothing);
  });

  testWidgets(
    'returning home preserves the active session and prevents another creation',
    (tester) async {
      _desktop(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _openSession(tester);
      await tester.tap(find.byKey(const Key('session-manage-action')));
      await tester.pumpAndSettle();
      final originalUrl = tester
          .widget<SelectableText>(find.byKey(const Key('tp-network-endpoint')))
          .data;
      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('session-home-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home-create-session')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('session-create-dialog')), findsNothing);
      expect(find.byKey(const Key('session-shell-page')), findsOneWidget);
      await tester.tap(find.byKey(const Key('session-manage-action')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SelectableText>(
              find.byKey(const Key('tp-network-endpoint')),
            )
            .data,
        originalUrl,
      );
      await tester.tap(find.byKey(const Key('tp-close-classroom-session')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home-create-session')), findsOneWidget);
      await tester.tap(find.byKey(const Key('home-create-session')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('session-create-dialog')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('manage session displays a scannable QR', (tester) async {
    _desktop(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _openSession(tester);
    await tester.tap(find.byKey(const Key('session-manage-action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tp-network-qr')), findsOneWidget);
  });

  testWidgets(
    'session management and supervision share one real TP controller',
    (WidgetTester tester) async {
      _desktop(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _openSession(tester);

      await tester.tap(find.byKey(const Key('session-manage-action')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tp-create-draft')), findsOneWidget);
      await tester.tap(find.byKey(const Key('tp-create-draft')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tp-session-title')), findsOneWidget);

      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('dashboard-supervision')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('session-supervision-page')), findsOneWidget);
      expect(find.byKey(const Key('tp-supervision-panel')), findsOneWidget);
      expect(find.byKey(const Key('supervision-title')), findsOneWidget);
      expect(find.byKey(const Key('supervision-lifecycle')), findsOneWidget);
      expect(find.byType(SimulatorCanvas), findsNothing);
    },
  );

  testWidgets(
    'workspace reuses session controller and dashboard action returns to shell',
    (WidgetTester tester) async {
      _desktop(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _openSession(tester);
      await tester.tap(find.byKey(const Key('session-manage-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tp-create-draft')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('dashboard-wiring')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('session-cabling-setup-page')),
        findsOneWidget,
      );
      expect(find.byType(SimulatorCanvas), findsNothing);
      await tester.tap(find.byKey(const Key('activity-setup-open-workshop')));
      await tester.pumpAndSettle();
      expect(find.byType(SimulatorCanvas), findsOneWidget);

      await _ensureTopOpen(tester);
      await tester.tap(find.byKey(const Key('session-manage-action')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tp-session-title')), findsOneWidget);
      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();

      await _ensureTopOpen(tester);
      await tester.tap(find.byKey(const Key('session-dashboard-action')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('session-shell-page')), findsOneWidget);
      expect(find.byKey(const Key('dashboard-wiring')), findsOneWidget);
      expect(find.byType(SimulatorCanvas), findsNothing);
    },
  );

  testWidgets(
    'session management exposes the automatically active teacher LAN session',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1100, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _openSession(tester);
      await tester.tap(find.byKey(const Key('session-manage-action')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tp-network-share')), findsNothing);
      expect(find.byKey(const Key('tp-network-code')), findsOneWidget);
      expect(find.byKey(const Key('tp-network-endpoint')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('supervision does not route through simulator', (
    WidgetTester tester,
  ) async {
    _desktop(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _openSession(tester);
    await tester.tap(find.byKey(const Key('dashboard-supervision')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('session-supervision-page')), findsOneWidget);
    expect(find.byKey(const Key('tp-supervision-panel')), findsOneWidget);
    expect(find.byType(SimulatorCanvas), findsNothing);
  });
}
