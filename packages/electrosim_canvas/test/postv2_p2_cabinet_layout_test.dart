import 'dart:ui';

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

CabinetFixture _fixture(String id, CabinetFixtureKind kind, Rect bounds) =>
    CabinetFixture(id: id, kind: kind, bounds: bounds);

void main() {
  test('P2 rails and ducts are geometry-only and support move/resize/remove', () {
    final rail = _fixture('R1', CabinetFixtureKind.dinRail,
        const Rect.fromLTWH(80, 140, 400, 34));
    final duct = _fixture('D1', CabinetFixtureKind.wireDuct,
        const Rect.fromLTWH(80, 210, 400, 42));
    final layout = CabinetLayout([rail]).add(duct);
    expect(layout.fixtures, hasLength(2));
    expect(layout.fixture('R1')!.bounds, const Rect.fromLTWH(80, 140, 400, 34));
    final edited = layout.move('R1', const Offset(100, 160))
        .resize('D1', const Size(440, 42));
    expect(edited.fixture('R1')!.bounds.topLeft, const Offset(100, 160));
    expect(edited.fixture('D1')!.bounds.width, 440);
    expect(layout.fixture('R1')!.bounds.left, 80);
    expect(edited.remove('D1').fixtures, hasLength(1));
  });

  test('P2 invalid fixtures and duplicates are explicitly rejected', () {
    expect(() => _fixture('bad', CabinetFixtureKind.wireDuct,
        Rect.fromLTWH(0, 0, -2, 40)), throwsArgumentError);
    expect(() => _fixture('nan', CabinetFixtureKind.dinRail,
        Rect.fromLTWH(double.nan, 0, 80, 30)), throwsArgumentError);
    final a = _fixture('R1', CabinetFixtureKind.dinRail,
        const Rect.fromLTWH(0, 0, 120, 30));
    expect(() => CabinetLayout([a, a]), throwsArgumentError);
    expect(() => CabinetLayout([a]).resize('R1', const Size(3, 4)),
        throwsArgumentError);
  });

  test('P2 assisted DIN snaps onto nearby rail, free mode does not', () {
    final cabinet = CabinetLayout([
      _fixture('R', CabinetFixtureKind.dinRail,
          const Rect.fromLTWH(80, 130, 400, 34)),
    ]);
    final assisted = CabinetPlacementPlanner.plan(
      cabinet: cabinet,
      elementId: 'KM1',
      deviceSize: const Size(80, 90),
      proposedCenter: const Offset(200, 168),
      existingDevices: const {},
      mode: CabinetPlacementMode.assistedDin,
      dinMountable: true,
    );
    expect(assisted.isValid, isTrue);
    expect(assisted.snapped, isTrue);
    expect(assisted.position, const Offset(200, 147));
    final free = CabinetPlacementPlanner.plan(
      cabinet: cabinet,
      elementId: 'KM1',
      deviceSize: const Size(80, 90),
      proposedCenter: const Offset(200, 168),
      existingDevices: const {},
      mode: CabinetPlacementMode.free,
      dinMountable: true,
    );
    expect(free.position, const Offset(200, 168));
    expect(free.snapped, isFalse);
  });

  test('P2 placement reports collisions with devices, ducts and terminal zones', () {
    final cabinet = CabinetLayout([
      _fixture('D', CabinetFixtureKind.wireDuct,
          const Rect.fromLTWH(180, 110, 50, 150)),
      _fixture('X', CabinetFixtureKind.terminalZone,
          const Rect.fromLTWH(170, 130, 100, 40)),
    ]);
    final result = CabinetPlacementPlanner.plan(
      cabinet: cabinet,
      elementId: 'Q1',
      deviceSize: const Size(100, 100),
      proposedCenter: const Offset(190, 180),
      existingDevices: const {
        'KM1': Rect.fromLTWH(110, 140, 40, 70),
      },
    );
    expect(result.isValid, isFalse);
    expect(result.intersectingIds,
        containsAll(['fixture:D', 'fixture:X', 'device:KM1']));
    expect(result.position, const Offset(190, 180));
  });

  test('P2 snap never creates an electrical constraint or unexpected relocation', () {
    final circuit = CircuitState(
      circuitId: CircuitId('cabinet-keeps-electricity'),
      revision: 0,
      mode: ElectricalMode.dc,
      sources: const [],
      components: const [],
    );
    final visual = CircuitVisualLayout(
      elementPositions: const {'KM1': Offset(150, 160)},
      cabinetLayout: CabinetLayout([
        _fixture('rail', CabinetFixtureKind.dinRail,
            const Rect.fromLTWH(50, 140, 400, 40)),
      ]),
    );
    final altered = visual.withCabinetLayout(
        visual.cabinetLayout.move('rail', const Offset(60, 200)));
    expect(altered.positionOf('KM1'), const Offset(150, 160));
    expect(circuit.sources, isEmpty);
    expect(circuit.connections, isEmpty);
    expect(visual.cabinetLayout.fixture('rail')!.bounds.top, 140);
    expect(altered.cabinetLayout.fixture('rail')!.bounds.top, 200);
    expect(altered.moveElement('KM1', const Offset(200, 200))
        .cabinetLayout.fixture('rail')!.bounds.top, 200);
  });

  test('P2 viewport coordinates only affect paint, not stored world geometry', () {
    final fixture = _fixture('R', CabinetFixtureKind.dinRail,
        const Rect.fromLTWH(60, 100, 400, 30));
    final cabinet = CabinetLayout([fixture]);
    final viewport = ViewportController();
    addTearDown(viewport.dispose);
    final circuit = CircuitState(
      circuitId: CircuitId('cabinet-painter'),
      revision: 0,
      mode: ElectricalMode.ac3,
    );
    final visual = CircuitVisualLayout(
      elementPositions: const {},
      cabinetLayout: cabinet,
    );
    final painter = CircuitScenePainter(
      circuit: circuit, layout: visual, viewport: viewport,
      paintElementChrome: false,
    );
    final recorder = PictureRecorder();
    painter.paint(Canvas(recorder), const Size(800, 600));
    recorder.endRecording().dispose();
    expect(visual.cabinetLayout.fixture('R')!.bounds, fixture.bounds);
  });

  test('P2 fixture movement clamps to bounded cabinet, not to electric ports', () {
    final rail = _fixture('R', CabinetFixtureKind.dinRail,
        const Rect.fromLTWH(0, 0, 250, 30));
    expect(CabinetPlacementPlanner.boundedTopLeft(
      rail, const Offset(900, -20), const Rect.fromLTWH(0, 0, 500, 400),
    ), const Offset(250, 0));
    expect(() => CabinetPlacementPlanner.boundedTopLeft(
      rail, const Offset(10, 10), const Rect.fromLTWH(0, 0, 100, 100),
    ), throwsArgumentError);
  });
  test('P2 orthogonal duct routing traverses centerline and preserves endpoints', () {
    final cabinet = CabinetLayout([
      CabinetFixture(id: 'duct', kind: CabinetFixtureKind.wireDuct,
          bounds: const Rect.fromLTWH(100, 180, 450, 42)),
    ]);
    final route = CabinetDuctWirePlanner.route(
      start: const Offset(150, 85),
      end: const Offset(480, 410),
      cabinet: cabinet,
    )!;
    final all = [
      const Offset(150, 85), ...route, const Offset(480, 410),
    ];
    expect(route, contains(const Offset(150, 201)));
    expect(route, contains(const Offset(480, 201)));
    for (var i = 1; i < all.length; i++) {
      expect(all[i].dx == all[i-1].dx ||
             all[i].dy == all[i-1].dy, isTrue);
    }
  });

  test('P2 duct routing falls back safely when there is no cable duct', () {
    expect(CabinetDuctWirePlanner.route(
      start: const Offset(0, 0),
      end: const Offset(100, 100),
      cabinet: const CabinetLayout.empty(),
    ), isNull);
  });


}
