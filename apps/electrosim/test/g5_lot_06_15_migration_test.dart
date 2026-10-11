import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim/f18_physical_layout_migration.dart';
import 'package:electrosim/f18_component_asset_visual.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'g5_lot_06_15_fixtures.dart';
import 'g5_crusher_integration_test.dart' as crusher;

void main() {
  for (final s in NativeApplianceGeometry.catalogue.values) {
    test(
      '${s.key} migration preserves graph, saved size, custom anchor and other routes',
      () {
        final c = lotFixture(s), j = c.toJson();
        final component = c.components.first;
        final base = crusher.crusherRouter.routeAll(
          circuit: c,
          layout: lotLayout(s),
        );
        final t = component.terminals.last;
        final l = CircuitVisualLayout(
          elementPositions: base.elementPositions,
          elementSizes: base.elementSizes,
          terminalAnchorOffsets: {t.id.value: const Offset(7, 9)},
          wireRoutes: {
            ...base.wireRoutes,
            'untouched': [const Offset(999, 999)],
          },
        );
        final next = migrateNativeApplianceLayout(
          c,
          l,
          router: crusher.crusherRouter,
        );
        expect(c.toJson(), j);
        expect(next.elementPositions, l.elementPositions);
        expect(next.elementSizes, l.elementSizes);
        expect(next.terminalAnchorOffsets[t.id.value], const Offset(7, 9));
        expect(next.routeFor('untouched'), l.routeFor('untouched'));
        expect(
          identical(
            migrateNativeApplianceLayout(
              c,
              next,
              router: crusher.crusherRouter,
            ),
            next,
          ),
          isTrue,
        );
        final g = CircuitGeometryIndex.build(c, next);
        for (final w in c.connections.where(
          (w) => !w.metadata.containsKey(AppliancePowerConnection.cableTag),
        )) {
          final points = [
            g.terminalPositions[w.fromTerminalId]!,
            ...next.routeFor(w.id.value),
            g.terminalPositions[w.toTerminalId]!,
          ];
          for (var i = 1; i < points.length; i++) {
            final delta = points[i] - points[i - 1];
            expect(delta.dx.abs() < .001 || delta.dy.abs() < .001, isTrue);
          }
        }
        expect(
          F18ReferenceComponentMetrics.boardSizeFor(
            s.visualType,
            variantKey: s.variant,
          ),
          s.boardSize,
        );
        final runtime = ElectroSimRuntimeEngine().advance(
          c,
          elapsed: const Duration(milliseconds: 100),
        );
        expect(runtime.solved, isTrue);
      },
    );
  }
  for (final spec in NativeApplianceGeometry.catalogue.values.where(
    (s) => s.threePhase,
  )) {
    test('${spec.key} phase fanouts remain orthogonal in all rotations', () {
      final circuit = lotFixture(spec);
      for (var q = 0; q < 4; q++) {
        final base = lotLayout(spec);
        final layout = crusher.crusherRouter.routeAll(
          circuit: circuit,
          layout: CircuitVisualLayout(
            elementPositions: base.elementPositions,
            elementSizes: base.elementSizes,
            elementQuarterTurns: {spec.key: q},
          ),
        );
        final migrated = migrateNativeApplianceLayout(
          circuit,
          layout,
          router: crusher.crusherRouter,
        );
        final g = CircuitGeometryIndex.build(circuit, migrated);
        for (final wire in circuit.connections) {
          final points = [
            g.terminalPositions[wire.fromTerminalId]!,
            ...migrated.routeFor(wire.id.value),
            g.terminalPositions[wire.toTerminalId]!,
          ];
          for (var i = 1; i < points.length; i++) {
            final d = points[i] - points[i - 1];
            expect(
              d.dx.abs() < .001 || d.dy.abs() < .001,
              isTrue,
              reason: '${spec.key} q=$q wire=${wire.id.value}',
            );
          }
        }
        expect(
          identical(
            migrateNativeApplianceLayout(
              circuit,
              migrated,
              router: crusher.crusherRouter,
            ),
            migrated,
          ),
          isTrue,
        );
      }
    });
  }
  test('native input docks remain distinct for every appliance', () {
    for (final spec in NativeApplianceGeometry.catalogue.values) {
      final c = lotFixture(spec), layout = lotLayout(spec);
      final g = CircuitGeometryIndex.build(c, layout);
      final count = spec.threePhase ? 3 : 2;
      final docks = c.components.first.terminals
          .take(count)
          .map((t) => g.terminalRoutingPositions[t.id])
          .toSet();
      expect(
        docks.length,
        count,
        reason: '${spec.key}: separate supply cores must not share a dock',
      );
    }
  });
}
