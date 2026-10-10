import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:electrosim/main.dart' as app;
import 'package:electrosim/f18_session_coordinator.dart';
import 'package:electrosim/runtime/electrosim_lan_sync.dart';
import 'package:electrosim_tp/electrosim_tp.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

Future<void> waitFor(
  WidgetTester tester,
  bool Function() condition,
  String description, {
  Duration timeout = const Duration(seconds: 45),
}) async {
  final watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > timeout) fail('Timeout: $description');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
}

Future<String> decodeQr(WidgetTester tester, Key key, File output) async {
  final custom = tester.widget<CustomPaint>(
    find
        .descendant(of: find.byKey(key), matching: find.byType(CustomPaint))
        .first,
  );
  final painter = custom.painter! as QrPainter;
  final png = await tester.runAsync(
    () => painter.toImageData(512, format: ui.ImageByteFormat.png),
  );
  output.writeAsBytesSync(png!.buffer.asUint8List());
  final decoded = await tester.runAsync(
    () => Process.run('python', ['../../tools/e2e/decode_qr.py', output.path]),
  );
  expect(decoded!.exitCode, 0, reason: decoded.stderr.toString());
  return decoded.stdout.toString().trim();
}

Future<void> captureTeacher(WidgetTester tester, File output) async {
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('real-teacher-proof')),
  );
  final png = await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      return await image.toByteData(format: ui.ImageByteFormat.png);
    } finally {
      image.dispose();
    }
  });
  output.writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  final root = Platform.environment['ELECTROSIM_STUDENT_WEB_ROOT'];
  if (root != null) {
    // Real I/O must not run in AutomatedTestWidgetsFlutterBinding's fake timer zone.
    LiveTestWidgetsFlutterBinding().framePolicy =
        LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
  }
  for (final wiring in [false, true]) {
    testWidgets(
      'real ${wiring ? 'wiring' : 'troubleshooting'} browser and teacher UI complete TP, rescan, grade and closure',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1440, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        tester.view.physicalSize = const Size(1440, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final evidence = Directory(
          '${Platform.environment['ELECTROSIM_TP_EVIDENCE_DIR'] ?? '${Directory.current.path}/build/tp-browser-proof'}/${wiring ? 'wiring' : 'troubleshooting'}',
        )..createSync(recursive: true);
        for (final f in evidence.listSync().whereType<File>()) {
          f.deleteSync();
        }
        await tester.pumpWidget(
          const RepaintBoundary(
            key: Key('real-teacher-proof'),
            child: app.ElectroSimApp(),
          ),
        );
        await tester.tap(find.byKey(const Key('home-create-session')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('session-create-confirm')));
        await tester.pumpAndSettle();
        await waitFor(
          tester,
          () =>
              find.byKey(const Key('session-waiting-qr')).evaluate().isNotEmpty,
          'teacher LAN QR',
        );
        await captureTeacher(
          tester,
          File('${evidence.path}/teacher-01-session.png'),
        );
        final qrUrl = await decodeQr(
          tester,
          const Key('session-waiting-qr'),
          File('${evidence.path}/teacher-waiting-qr.png'),
        );
        expect(
          qrUrl,
          tester
              .widget<SelectableText>(
                find.byKey(const Key('session-waiting-browser-url')),
              )
              .data,
        );
        // Use the same LAN host/port through loopback in the container; advertised LAN routing is tested on devices separately.
        final browserUrl = Uri.parse(
          qrUrl,
        ).replace(host: '127.0.0.1').toString();
        File('${evidence.path}/transport.json').writeAsStringSync(
          jsonEncode({'qrUrl': qrUrl, 'browserUrl': browserUrl}),
        );
        final process = await tester.runAsync(
          () => Process.start('python', [
            '../../tools/e2e/tp_student_browser.py',
            browserUrl,
            evidence.path,
            wiring ? 'wiring' : 'troubleshooting',
          ]),
        );
        final browserLog = StringBuffer();
        process!.stdout.transform(utf8.decoder).listen(browserLog.write);
        process.stderr.transform(utf8.decoder).listen(browserLog.write);
        addTearDown(() {
          process.kill();
        });
        Future<void> phase(String name) async {
          try {
            await waitFor(
              tester,
              () => File('${evidence.path}/$name.json').existsSync(),
              name,
            );
          } catch (_) {
            final log = File('${evidence.path}/browser.log');
            fail(
              '$name failed:\n${log.existsSync() ? log.readAsStringSync() : browserLog}',
            );
          }
        }

        await phase('joined');
        await tester.tap(find.byKey(const Key('session-waiting-continue')));
        await tester.pumpAndSettle();
        if (wiring) {
          await tester.tap(find.byKey(const Key('dashboard-wiring')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('activity-setup-publish-tp')));
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const Key('tp-wiring-reference-example')),
          );
          await tester.pumpAndSettle();
          final firstExample =
              tester
                      .widget<DropdownButton<String>>(
                        find.byKey(const Key('tp-wiring-reference-example')),
                      )
                      .items!
                      .first
                      .child
                  as Text;
          await tester.tap(find.text(firstExample.data!).last);
          await tester.pumpAndSettle();
        } else {
          await tester.tap(find.byKey(const Key('session-manage-action')));
        }

        await tester.pumpAndSettle();
        expect(
          await decodeQr(
            tester,
            const Key('tp-network-qr'),
            File('${evidence.path}/teacher-manage-qr.png'),
          ),
          qrUrl,
        );
        await tester.tap(find.byKey(const Key('tp-create-draft')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('tp-publish')));
        await tester.pumpAndSettle();
        await captureTeacher(
          tester,
          File('${evidence.path}/teacher-02-published.png'),
        );
        await tester.tap(find.byKey(const Key('tp-teacher-start')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Fermer'));
        await tester.pumpAndSettle();
        if (wiring) {
          await tester.tap(find.byKey(const Key('activity-setup-back')));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(const Key('dashboard-supervision')));
        await tester.pumpAndSettle();
        final supervision = tester.widget<F18SessionSupervisionPage>(
          find.byType(F18SessionSupervisionPage),
        );
        final ElectroSimLanSyncHost host = supervision.lanHost!;
        await phase('progress');
        await waitFor(tester, () {
          final session = host.studentSessions.values.single!;
          return wiring
              ? session.studentCircuit.sources.isNotEmpty &&
                    session.studentCircuit.components.isNotEmpty &&
                    session.studentCircuit.connections.length == 2
              : session.diagnosticSheet.entries.length == 1;
        }, 'saved student progress');
        final originalId = host.studentSessions.keys.single;
        final original = host.studentSessions[originalId]!;
        expect(
          original.studentCircuit.components.length,
          greaterThan(
            supervision.controller.session!.studentCircuit.components.length,
          ),
        );
        final originalCircuit = original.studentCircuit.toJson();
        File('${evidence.path}/rescan.json').writeAsStringSync('{}');
        await phase('resumed');
        expect(host.studentSessions.keys, [originalId]);
        if (!wiring) {
          await waitFor(
            tester,
            () =>
                host
                    .studentSessions[originalId]!
                    .diagnosticSheet
                    .entries
                    .length ==
                2,
            'resumed diagnostic persisted',
          );
        }
        expect(
          host.studentSessions[originalId]!.studentCircuit.toJson(),
          originalCircuit,
        );
        await phase('submitted');
        await waitFor(
          tester,
          () =>
              host.studentSessions[originalId]!.lifecycle ==
              TpLifecycle.submitted,
          'submission',
        );
        expect(
          host.studentSessions[originalId]!.studentCircuit.toJson(),
          originalCircuit,
        );
        expect(
          host.studentSessions[originalId]!.diagnosticSheet.entries.length,
          wiring ? 0 : 2,
        );
        final studentCard = find.byKey(
          Key('supervision-student-open-$originalId'),
        );
        await tester.ensureVisible(studentCard);
        await tester.tap(studentCard);
        await tester.pumpAndSettle();
        final gradeField = find.byKey(
          Key('supervision-grade-input-$originalId'),
        );
        await tester.ensureVisible(gradeField);
        await tester.enterText(gradeField, '81');
        final gradeButton = find.byKey(
          Key('supervision-grade-submit-$originalId'),
        );
        await tester.ensureVisible(gradeButton);
        await tester.tap(gradeButton);
        await tester.pumpAndSettle();
        expect(host.studentSessions[originalId]!.evaluation!.score, 81);
        expect(
          host.studentSessions[originalId]!.lifecycle,
          TpLifecycle.evaluated,
        );
        await captureTeacher(
          tester,
          File('${evidence.path}/teacher-03-graded.png'),
        );
        File('${evidence.path}/graded.json').writeAsStringSync('{}');
        await phase('grade_seen');
        await tester.tap(find.byKey(const Key('session-supervision-back')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('session-manage-action')));
        await tester.pumpAndSettle();
        expect(
          await decodeQr(
            tester,
            const Key('tp-network-qr'),
            File('${evidence.path}/teacher-manage-qr.png'),
          ),
          qrUrl,
        );
        await tester.tap(find.byKey(const Key('tp-close-classroom-session')));
        await tester.pumpAndSettle();
        await phase('closed');
        final exit = await tester.runAsync(() => process.exitCode);
        expect(exit, 0, reason: browserLog.toString());
        expect(find.byKey(const Key('home-create-session')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      skip: root == null,
      timeout: const Timeout(Duration(minutes: 5)),
    );
  }
}
