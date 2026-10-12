import 'dart:async';

import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';
import 'package:test/test.dart';

final class ControlledWorker implements R6Worker {
  final List<R6NetworkJob> started = <R6NetworkJob>[];
  final List<Completer<R6NetworkOutcome>> replies =
      <Completer<R6NetworkOutcome>>[];
  bool closed = false;

  @override
  Future<R6NetworkOutcome> solve(R6NetworkJob request) {
    started.add(request);
    final Completer<R6NetworkOutcome> completer = Completer<R6NetworkOutcome>();
    replies.add(completer);
    return completer.future;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

void main() {
  IsothermalAirNetwork smallNetwork() => IsothermalAirNetwork(
    chambers: <FixedAirChamber>[
      FixedAirChamber.fromPressure(
        id: 'c',
        volumeM3: .001,
        pressureAbsPa: 150000,
      ),
    ],
    passages: <AirPassage>[],
  );

  test(
    'R6/N scheduler replaces pending work and refuses late revisions',
    () async {
      final ControlledWorker underlying = ControlledWorker();
      final R6WorkerScheduler scheduler = R6WorkerScheduler(
        underlying,
        engineVersion: 'real-dart-engine',
      );
      final IsothermalAirNetwork network = smallNetwork();
      R6NetworkJob builder(int revision, int requestId) => R6NetworkJob(
        projectRevision: revision,
        requestId: requestId,
        engineVersion: 'real-dart-engine',
        network: network,
        before: network.initialSnapshot,
        durationS: .02,
        maxStepS: .002,
      );
      final Future<R6NetworkOutcome> first = scheduler.submit(build: builder);
      final Future<R6NetworkOutcome> second = scheduler.submit(build: builder);
      expect(second, throwsStateError);
      final Future<R6NetworkOutcome> third = scheduler.submit(build: builder);
      await Future<void>.delayed(Duration.zero);
      expect(underlying.started.length, 1);
      scheduler.changeRevision();
      expect(third, throwsStateError);
      underlying.replies.first.complete(underlying.started.first.execute());
      expect(first, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      expect(underlying.started.length, 1);
      await scheduler.close();
      expect(underlying.closed, isTrue);
      expect(() => scheduler.submit(build: builder), throwsStateError);
    },
  );

  test(
    'R6/N scheduler never dispatches two active engine operations',
    () async {
      final ControlledWorker underlying = ControlledWorker();
      final R6WorkerScheduler scheduler = R6WorkerScheduler(
        underlying,
        engineVersion: 'r6n',
      );
      final IsothermalAirNetwork network = smallNetwork();
      R6NetworkJob build(int rev, int id) => R6NetworkJob(
        projectRevision: rev,
        requestId: id,
        engineVersion: 'r6n',
        network: network,
        before: network.initialSnapshot,
        durationS: .001,
        maxStepS: .001,
      );
      final Future<R6NetworkOutcome> first = scheduler.submit(build: build);
      final Future<R6NetworkOutcome> second = scheduler.submit(build: build);
      await Future<void>.delayed(Duration.zero);
      expect(underlying.started.length, 1);
      underlying.replies[0].complete(underlying.started[0].execute());
      final R6NetworkOutcome result1 = await first;
      expect(result1.requestId, 1);
      await Future<void>.delayed(Duration.zero);
      expect(underlying.started.length, 2);
      underlying.replies[1].complete(underlying.started[1].execute());
      final R6NetworkOutcome result2 = await second;
      expect(result2.requestId, 2);
      await scheduler.close();
    },
  );

  test('R6/N scheduler rejects worker clock and mass corruption', () async {
    final IsothermalAirNetwork network = smallNetwork();

    for (final String fault in <String>['clock', 'mass']) {
      final ControlledWorker underlying = ControlledWorker();
      final R6WorkerScheduler scheduler = R6WorkerScheduler(
        underlying,
        engineVersion: 'r6n',
      );
      R6NetworkJob build(int revision, int requestId) => R6NetworkJob(
        projectRevision: revision,
        requestId: requestId,
        engineVersion: 'r6n',
        network: network,
        before: network.initialSnapshot,
        durationS: .02,
        maxStepS: .002,
      );

      final Future<R6NetworkOutcome> result = scheduler.submit(build: build);
      final Future<void> rejected = expectLater(result, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      final R6NetworkJob requested = underlying.started.single;
      final IsothermalAirSnapshot before = requested.before;
      final IsothermalAirSnapshot corrupt = IsothermalAirSnapshot(
        timeS: fault == 'clock' ? .03 : .02,
        chambers: <String, FixedAirChamber>{
          'c': fault == 'mass'
              ? before.chambers['c']!.withMass(
                  before.chambers['c']!.massKg + .01,
                )
              : before.chambers['c']!,
        },
        passageMassFlowKgPerS: before.passageMassFlowKgPerS,
        acceptedSubsteps: 1,
      );
      underlying.replies.single.complete(
        R6NetworkOutcome(
          projectRevision: requested.projectRevision,
          requestId: requested.requestId,
          engineVersion: requested.engineVersion,
          snapshot: corrupt,
        ),
      );
      await rejected;
      await scheduler.close();
    }
  });

  test('R6/N scheduler accepts a physically valid worker snapshot', () async {
    final ControlledWorker underlying = ControlledWorker();
    final R6WorkerScheduler scheduler = R6WorkerScheduler(
      underlying,
      engineVersion: 'r6n',
    );
    final IsothermalAirNetwork network = smallNetwork();
    R6NetworkJob build(int revision, int requestId) => R6NetworkJob(
      projectRevision: revision,
      requestId: requestId,
      engineVersion: 'r6n',
      network: network,
      before: network.initialSnapshot,
      durationS: .02,
      maxStepS: .002,
    );

    final Future<R6NetworkOutcome> result = scheduler.submit(build: build);
    await Future<void>.delayed(Duration.zero);
    underlying.replies.single.complete(underlying.started.single.execute());
    expect((await result).snapshot.timeS, .02);
    await scheduler.close();
  });

  test('R6/N unresponsive worker times out, closes and rejects queued work', () async {
    final ControlledWorker underlying = ControlledWorker();
    final R6WorkerScheduler scheduler = R6WorkerScheduler(
      underlying,
      engineVersion: 'r6n',
      requestTimeout: const Duration(milliseconds: 25),
    );
    final IsothermalAirNetwork network = smallNetwork();
    R6NetworkJob build(int revision, int requestId) => R6NetworkJob(
      projectRevision: revision,
      requestId: requestId,
      engineVersion: 'r6n',
      network: network,
      before: network.initialSnapshot,
      durationS: .02,
      maxStepS: .002,
    );

    final Future<R6NetworkOutcome> first = scheduler.submit(build: build);
    final Future<R6NetworkOutcome> queued = scheduler.submit(build: build);
    final Future<void> firstRejected = expectLater(first, throwsStateError);
    final Future<void> queuedRejected = expectLater(queued, throwsStateError);

    await Future.wait(<Future<void>>[firstRejected, queuedRejected]);
    expect(underlying.closed, isTrue);
    expect(underlying.started.length, 1);
    expect(() => scheduler.submit(build: build), throwsStateError);

    // A later worker completion cannot resurrect the rejected snapshot.
    underlying.replies.single.complete(underlying.started.single.execute());
    await Future<void>.delayed(Duration.zero);
    expect(scheduler.isBusy, isFalse);
  });

  test('R6/N rejects a nonpositive solver response timeout', () {
    final ControlledWorker underlying = ControlledWorker();
    expect(
      () => R6WorkerScheduler(
        underlying,
        engineVersion: 'r6n',
        requestTimeout: Duration.zero,
      ),
      throwsArgumentError,
    );
  });
}
