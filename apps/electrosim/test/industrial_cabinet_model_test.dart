import 'dart:ui';
import 'package:electrosim/runtime/electrosim_layout_persistence.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'projected overlap on distinct surfaces is valid, same surface remains blocked',
    () {
      final cabinet = CabinetLayout(
        [
          CabinetFixture(
            id: 'D',
            kind: CabinetFixtureKind.wireDuct,
            bounds: const Rect.fromLTWH(100, 100, 100, 50),
          ),
        ],
        mounts: {'Q1': CabinetMount()},
      );
      CabinetPlacementResult place(CabinetSurface surface) =>
          CabinetPlacementPlanner.plan(
            cabinet: cabinet,
            elementId: 'S1',
            deviceSize: const Size(40, 40),
            proposedCenter: const Offset(130, 125),
            existingDevices: {'Q1': const Rect.fromLTWH(100, 100, 100, 100)},
            surface: surface,
          );
      expect(place(CabinetSurface.door).isValid, isTrue);
      expect(place(CabinetSurface.interior).isValid, isFalse);
    },
  );
  final envelope = CabinetEnvelope(widthMm: 800, heightMm: 1000, depthMm: 300);
  final rail = CabinetFixture(
    id: 'R1',
    kind: CabinetFixtureKind.dinRail,
    bounds: const Rect.fromLTWH(100, 200, 500, 36),
  );
  test(
    'physical bounds depend on mounting surface and reject invalid dimensions',
    () {
      expect(envelope.contains(const Rect.fromLTWH(0, 0, 20, 20)), isFalse);
      expect(
        envelope.contains(
          const Rect.fromLTWH(0, 0, 20, 20),
          surface: CabinetSurface.door,
        ),
        isTrue,
      );
      expect(
        envelope.contains(
          const Rect.fromLTWH(900, 0, 20, 20),
          surface: CabinetSurface.exterior,
        ),
        isTrue,
      );
      expect(
        () =>
            CabinetEnvelope(widthMm: double.nan, heightMm: 1000, depthMm: 300),
        throwsArgumentError,
      );
      expect(
        () => CabinetMount(surface: CabinetSurface.door, railId: 'R1'),
        throwsArgumentError,
      );
    },
  );
  test(
    'DIN assistance aligns mechanical anchor and detaches moved rail without moving equipment',
    () {
      final cabinet = CabinetLayout(
        [rail],
        envelope: envelope,
        mounts: {
          'Q1': CabinetMount(railId: 'R1', anchorOffset: const Offset(0, 20)),
        },
      );
      final placed = CabinetPlacementPlanner.plan(
        cabinet: cabinet,
        elementId: 'Q1',
        deviceSize: const Size(60, 100),
        proposedCenter: const Offset(200, 190),
        existingDevices: {},
        mode: CabinetPlacementMode.assistedDin,
        dinMountable: true,
        mountingAnchorOffset: const Offset(0, 20),
      );
      expect(placed.isValid, isTrue);
      expect(placed.position.dy + 20, rail.bounds.center.dy);
      expect(placed.railId, 'R1');
      final layout = CircuitVisualLayout(
        elementPositions: {'Q1': placed.position},
        cabinetLayout: cabinet,
      );
      final moved = layout.withCabinetLayout(
        cabinet.move('R1', const Offset(100, 300)),
      );
      expect(moved.positionOf('Q1'), placed.position);
      expect(moved.cabinetLayout.mounts['Q1']!.railId, isNull);
      expect(moved.cabinetLayout.envelope, envelope);
      expect(cabinet.remove('R1').mounts['Q1']!.railId, isNull);
    },
  );
  test(
    'schema 3 round trips physical metadata and schema 2 remains compatible',
    () {
      final layout = CircuitVisualLayout(
        elementPositions: const {'Q1': Offset(200, 198)},
        cabinetLayout: CabinetLayout(
          [rail],
          envelope: envelope,
          mounts: {
            'Q1': CabinetMount(
              railId: 'R1',
              anchorOffset: const Offset(0, 20),
              depthMm: 70,
            ),
          },
        ),
      );
      final data = ElectroSimLayoutPersistence.encode(layout);
      final restored = ElectroSimLayoutPersistence.decode(data)!;
      expect(restored.cabinetLayout.envelope, envelope);
      expect(restored.cabinetLayout.mounts, layout.cabinetLayout.mounts);
      final legacy = ElectroSimLayoutPersistence.decode({
        ...data,
        'schemaVersion': 2,
      })!;
      expect(legacy.cabinetLayout.envelope, isNull);
      expect(legacy.cabinetLayout.mounts, isEmpty);
      expect(legacy.cabinetLayout.fixture('R1')!.bounds, rail.bounds);
      expect(
        () => ElectroSimLayoutPersistence.decode({
          ...data,
          'cabinetMounts': {
            'Q1': {
              'surface': 'interior',
              'railId': 'missing',
              'anchorOffset': [0, 0],
              'depthMm': 70,
            },
          },
        }),
        throwsFormatException,
      );
    },
  );
}
