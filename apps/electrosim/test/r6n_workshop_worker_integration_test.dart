import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:electrosim/pneumatics/pneumatic_workshop_page.dart';
import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'r6_workshop_authored_runtime_test.dart' as fixture;
import 'r6l_live_png_evidence_test.dart' as evidence;

/// A controllable transport witness. It never solves until the test releases
/// the worker response, proving the Flutter UI does not calculate the result
/// synchronously or substitute an untested direct-solver fallback.
final class WitnessWorker implements R6Worker {
  final List<R6NetworkJob> requests = <R6NetworkJob>[];
  final List<Completer<R6NetworkOutcome>> replies =
      <Completer<R6NetworkOutcome>>[];
  bool closed = false;

  @override
  Future<R6NetworkOutcome> solve(R6NetworkJob job) {
    if (closed) throw StateError('witness worker already closed');
    requests.add(job);
    final Completer<R6NetworkOutcome> response = Completer<R6NetworkOutcome>();
    replies.add(response);
    return response.future;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

/// Executes the real native isolate and makes its completion observable
/// without pretending that a mocked worker is release-platform evidence.
final class RealIsolateWitness implements R6Worker {
  RealIsolateWitness(this.delegate, this.requestSent, this.resultReceived);

  final R6Worker delegate;
  final Completer<void> requestSent;
  final Completer<void> resultReceived;

  @override
  Future<R6NetworkOutcome> solve(R6NetworkJob job) async {
    requestSent.complete();
    try {
      final R6NetworkOutcome answer = await delegate.solve(job);
      resultReceived.complete();
      return answer;
    } catch (error, stack) {
      resultReceived.completeError(error, stack);
      rethrow;
    }
  }

  @override
  Future<void> close() => delegate.close();
}

Future<void> _startSimulation(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('air-advance')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).last, '0.8');
  await tester.tap(find.byKey(const Key('air-cd-apply')));
  await tester.pump();
  await tester.pump();
}

Future<void> _loadProofFont(WidgetTester tester) async {
  await tester.runAsync(() async {
    final File font = File('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');
    if (!font.existsSync()) return;
    final FontLoader loader = FontLoader('R6NProofFont')
      ..addFont(
        Future<ByteData>.value(ByteData.sublistView(await font.readAsBytes())),
      );
    await loader.load();
    final String? root = Platform.environment['FLUTTER_ROOT'];
    if (root == null) return;
    final File icons = File(
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) {
      final FontLoader iconLoader = FontLoader('MaterialIcons')
        ..addFont(
          Future<ByteData>.value(
            ByteData.sublistView(await icons.readAsBytes()),
          ),
        );
      await iconLoader.load();
    }
  });
}

/// Drive the test clock until its scheduled zero-delay dispatch has run.
/// No fake response or arbitrary wall-clock delay is involved.
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() done,
) async {
  for (int tick = 0; tick < 30 && !done(); tick++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
  expect(done(), isTrue, reason: 'The Flutter worker dispatch never started');
}

void main() {
  testWidgets('R6/N Flutter UI completes using a real native isolate', (
    WidgetTester tester,
  ) async {
    await fixture.setSize(tester);
    final Completer<void> workerReady = Completer<void>();
    final Completer<void> requestSent = Completer<void>();
    final Completer<void> resultReceived = Completer<void>();
    await _loadProofFont(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'R6NProofFont'),
        home: RepaintBoundary(
          key: const Key('r6l-live-evidence-boundary'),
          child: PneumaticWorkshopPage(
            initialProject: fixture.project(),
            workerFactory: () async {
              final R6Worker actual = await createR6Worker();
              workerReady.complete();
              return RealIsolateWitness(actual, requestSent, resultReceived);
            },
          ),
        ),
      ),
    );
    await _startSimulation(tester);
    await tester.runAsync(
      () => workerReady.future.timeout(const Duration(seconds: 20)),
    );
    await _pumpUntil(tester, () => requestSent.isCompleted);
    await tester.runAsync(
      () => resultReceived.future.timeout(const Duration(seconds: 20)),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Simulation réelle : t = 0.020 s'),
      findsOneWidget,
    );
    expect(
      find.text('R6/N : résultat accepté depuis worker isolé'),
      findsOneWidget,
    );
    await evidence.captureWorkshop(
      tester,
      '04_platine_reseau_worker_natif.png',
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('R6/N Flutter UI uses worker answer, not synchronous solve', (
    WidgetTester tester,
  ) async {
    await fixture.setSize(tester);
    final WitnessWorker transport = WitnessWorker();
    int factoryCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PneumaticWorkshopPage(
          initialProject: fixture.project(),
          workerFactory: () async {
            factoryCalls++;
            return transport;
          },
        ),
      ),
    );
    await _startSimulation(tester);
    await _pumpUntil(tester, () => transport.requests.isNotEmpty);
    expect(factoryCalls, 1);
    expect(transport.requests, hasLength(1));
    expect(transport.requests.single.durationS, .02);
    expect(find.byKey(const Key('air-worker-running')), findsOneWidget);
    expect(find.textContaining('Simulation réelle :'), findsNothing);

    // Only the response from the canonical job advances the accepted state.
    transport.replies.single.complete(transport.requests.single.execute());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('air-worker-running')), findsNothing);
    expect(
      find.textContaining('Simulation réelle : t = 0.020 s'),
      findsOneWidget,
    );
    expect(
      find.text('R6/N : résultat accepté depuis worker isolé'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('air-measured-pressure')), findsOneWidget);

    await tester.tap(find.byKey(const Key('air-advance')));
    await _pumpUntil(tester, () => transport.requests.length == 2);
    expect(factoryCalls, 1);
    expect(transport.requests, hasLength(2));
    expect(transport.requests.last.before.timeS, closeTo(.02, 1e-12));
    transport.replies.last.complete(transport.requests.last.execute());
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Simulation réelle : t = 0.040 s'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(transport.closed, isTrue);
  });

  testWidgets('R6/N edit discards in-flight result and releases transport', (
    WidgetTester tester,
  ) async {
    await fixture.setSize(tester);
    final WitnessWorker transport = WitnessWorker();
    await tester.pumpWidget(
      MaterialApp(
        home: PneumaticWorkshopPage(
          initialProject: fixture.project(),
          workerFactory: () async => transport,
        ),
      ),
    );
    await _startSimulation(tester);
    await _pumpUntil(tester, () => transport.requests.isNotEmpty);
    expect(transport.requests, hasLength(1));
    expect(find.textContaining('Simulation réelle :'), findsNothing);

    // Modify the physical graph while the worker is still busy.
    await tester.tap(find.byKey(const Key('add-idealSource')));
    await tester.pump();
    await tester.pump();
    expect(transport.closed, isTrue);

    // An obsolete completion must never become the visible accepted state.
    transport.replies.single.complete(transport.requests.single.execute());
    await tester.pumpAndSettle();
    expect(find.textContaining('Simulation réelle :'), findsNothing);
    expect(
      find.text('R6/N : résultat accepté depuis worker isolé'),
      findsNothing,
    );
  });
}
