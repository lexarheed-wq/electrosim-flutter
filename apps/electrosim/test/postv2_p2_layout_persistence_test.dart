import 'dart:ui';

import 'package:electrosim/runtime/electrosim_layout_persistence.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P2 saves rails, wiring ducts, and terminal areas without losing wires', () {
    final layout = CircuitVisualLayout(
      elementPositions: const {'KM1': Offset(230, 160)},
      elementSizes: const {'KM1': Size(96, 180)},
      wireRoutes: const {'wire': [Offset(10, 40), Offset(230, 40)]},
      cabinetLayout: CabinetLayout([
        CabinetFixture(id: 'R1', kind: CabinetFixtureKind.dinRail,
          bounds: const Rect.fromLTWH(100, 120, 500, 36)),
        CabinetFixture(id: 'D1', kind: CabinetFixtureKind.wireDuct,
          bounds: const Rect.fromLTWH(100, 260, 500, 40)),
        CabinetFixture(id: 'X1', kind: CabinetFixtureKind.terminalZone,
          bounds: const Rect.fromLTWH(100, 320, 300, 56)),
      ]),
    );
    final data = ElectroSimLayoutPersistence.encode(layout);
    expect(data['schemaVersion'], 2);
    final restored = ElectroSimLayoutPersistence.decode(data)!;
    expect(restored.cabinetLayout.fixtures, hasLength(3));
    expect(restored.cabinetLayout.fixture('R1')!.bounds,
        const Rect.fromLTWH(100, 120, 500, 36));
    expect(restored.cabinetLayout.fixture('D1')!.kind,
        CabinetFixtureKind.wireDuct);
    expect(restored.cabinetLayout.fixture('X1')!.kind,
        CabinetFixtureKind.terminalZone);
    expect(restored.positionOf('KM1'), const Offset(230, 160));
    expect(restored.routeFor('wire'), const [Offset(10, 40), Offset(230, 40)]);
    expect(restored.moveElement('KM1', const Offset(280, 175))
        .cabinetLayout.fixtures, hasLength(3));
  });

  test('P2 opens legacy schema-1 layout with empty cabinet, no migration loss', () {
    final old = <String, Object?>{
      'schemaVersion': 1,
      'positions': <String, Object?>{'KM1': <double>[100, 140]},
      'sizes': <String, Object?>{},
      'routes': <String, Object?>{},
      'quarterTurns': <String, Object?>{},
      'defaultSize': <double>[104, 64],
    };
    final loaded = ElectroSimLayoutPersistence.decode(old)!;
    expect(loaded.cabinetLayout.fixtures, isEmpty);
    expect(loaded.positionOf('KM1'), const Offset(100, 140));
    final rewritten = ElectroSimLayoutPersistence.encode(loaded);
    expect(rewritten['schemaVersion'], 2);
  });

  test('P2 rejects malformed, unsupported or duplicate cabinet fixtures', () {
    final valid = ElectroSimLayoutPersistence.encode(
      CircuitVisualLayout(elementPositions: const {}),
    );
    expect(() => ElectroSimLayoutPersistence.decode({
      ...valid,
      'cabinetFixtures': [
        {'id': 'R', 'kind': 'dinRail', 'bounds': [0, 20, 200, 25]},
        {'id': 'R', 'kind': 'wireDuct', 'bounds': [0, 60, 200, 40]},
      ],
    }), throwsFormatException);
    expect(() => ElectroSimLayoutPersistence.decode({
      ...valid,
      'cabinetFixtures': [
        {'id': 'R', 'kind': 'wireDuct',
         'bounds': [0, 20, double.infinity, 25]},
      ],
    }), throwsFormatException);
    expect(() => ElectroSimLayoutPersistence.decode({
      ...valid,
      'cabinetFixtures': [
        {'id': 'R', 'kind': 'unknown', 'bounds': [0, 20, 200, 25]},
      ],
    }), throwsFormatException);
    expect(() => ElectroSimLayoutPersistence.decode({
      ...valid,
      'schemaVersion': 999,
    }), throwsFormatException);
  });
}
