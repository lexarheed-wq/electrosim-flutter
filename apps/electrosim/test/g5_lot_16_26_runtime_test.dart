import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim/f18_physical_layout_migration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'g5_lot_16_26_fixtures.dart';
import 'g5_crusher_integration_test.dart' as tools;

void main() {
  for (final key in ['source-ac3-grid', 'source-ac3-alternator']) {
    test(
      '$key repairs a saved diagonal route without changing source ports',
      () {
        final s = NativeApplianceGeometry.catalogue[key]!;
        final c = lastLotFixture(s), l = lastLotLayout(s);
        final old = CircuitVisualLayout(
          elementPositions: l.elementPositions,
          elementSizes: l.elementSizes,
          wireRoutes: {
            'supply-0': [const Offset(999, 999)],
          },
        );
        final next = migrateNativeApplianceLayout(
          c,
          old,
          router: tools.crusherRouter,
        );
        final g = CircuitGeometryIndex.build(c, next), w = c.connections.first;
        final points = [
          g.terminalPositions[w.fromTerminalId]!,
          ...next.routeFor(w.id.value),
          g.terminalPositions[w.toTerminalId]!,
        ];
        for (var i = 1; i < points.length; i++) {
          final d = points[i] - points[i - 1];
          expect(d.dx.abs() < .001 || d.dy.abs() < .001, isTrue);
        }
        expect(next.elementSizes, old.elementSizes);
      },
    );
  }
  for (final key in lastLotAndMeterKeys) {
    test(
      '$key solves without modifying authored IDs and routes orthogonally',
      () {
        final s = NativeApplianceGeometry.catalogue[key]!;
        final c = lastLotFixture(s), json = c.toJson();
        final l = tools.crusherRouter.routeAll(
          circuit: c,
          layout: lastLotLayout(s),
        );
        final m = migrateNativeApplianceLayout(
          c,
          l,
          router: tools.crusherRouter,
        );
        final g = CircuitGeometryIndex.build(c, m);
        expect(c.toJson(), json);
        expect(m.elementSizes, l.elementSizes);
        expect(m.elementPositions, l.elementPositions);
        expect(
          identical(
            migrateNativeApplianceLayout(c, m, router: tools.crusherRouter),
            m,
          ),
          isTrue,
        );
        for (final w in c.connections.where(
          (w) => !w.metadata.containsKey(AppliancePowerConnection.cableTag),
        )) {
          final points = [
            g.terminalPositions[w.fromTerminalId]!,
            ...m.routeFor(w.id.value),
            g.terminalPositions[w.toTerminalId]!,
          ];
          for (var i = 1; i < points.length; i++) {
            final d = points[i] - points[i - 1];
            expect(
              d.dx.abs() < .001 || d.dy.abs() < .001,
              isTrue,
              reason: w.id.value,
            );
          }
        }
        final snap = const ElectroSimRuntimeEngine().evaluate(c);
        expect(snap.solved, isTrue, reason: snap.diagnostics.toString());
      },
    );
  }
}
