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
    final Completer<R6NetworkOutcome> completer =
        Completer<R6NetworkOutcome>();
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

  test('R6/N scheduler replaces pending work and refuses late revisions',
      () async {
    final ControlledWorker underlying = ControlledWorker();
    final R6WorkerScheduler scheduler = R6WorkerScheduler(
      underlying, engineVersion: 'real-dart-engine',
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
  });

  test('R6/N scheduler never dispatches two active engine operations', () async {
    final ControlledWorker underlying = ControlledWorker();
    final R6WorkerScheduler scheduler = R6WorkerScheduler(
      underlying, engineVersion: 'r6n',
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
  });
}
