import 'dart:convert';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim/f18_physical_layout_migration.dart';
import 'package:electrosim/f18_component_asset_visual.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CircuitState crusherFixture() {
  Terminal t(String id) =>
      Terminal(id: TerminalId(id), name: id, phase: PhaseTag.none);
  Connection w(String id, String a, String b) => Connection(
    id: ConnectionId(id),
    fromTerminalId: TerminalId(a),
    toTerminalId: TerminalId(b),
  );
  final base = CircuitState(
    circuitId: CircuitId('crusher-proof'),
    revision: 0,
    mode: ElectricalMode.ac3,
    sources: [
      SourceInstance(
        id: SourceId('grid'),
        modelType: 'ac3_voltage_source',
        terminals: [
          for (final e in {
            'L1': PhaseTag.l1,
            'L2': PhaseTag.l2,
            'L3': PhaseTag.l3,
            'N': PhaseTag.neutral,
          }.entries)
            Terminal(id: TerminalId(e.key), name: e.key, phase: e.value),
        ],
        parameters: {'phaseVoltageRmsV': 230.0},
      ),
    ],
    components: [
      ComponentInstance(
        id: ComponentId('crusher'),
        modelType: 'motor_3p_6t',
        terminals: [
          for (final id in ['U1', 'V1', 'W1', 'U2', 'V2', 'W2']) t(id),
        ],
        parameters: {
          '_visualModelType': 'catalog_motor_driven_6t',
          '_visualVariant': 'crusher',
          'resistanceOhm': 12.0,
          'inductanceH': .045,
          'ratedPowerW': 4000.0,
        },
      ),
    ],
    connections: [
      w('a', 'L1', 'U1'),
      w('b', 'L2', 'V1'),
      w('c', 'L3', 'W1'),
      w('star1', 'U2', 'V2'),
      w('star2', 'V2', 'W2'),
    ],
    settings: {'frequencyHz': 50.0},
  );
  final upgraded = AppliancePowerConnection.addProtectiveEarth(base);
  final json = upgraded.toJson();
  json['connections'] = [
    ...upgraded.connections.map((w) => w.toJson()),
    w('pe', 'N', 'crusher:chassis-pe').toJson(),
  ];
  return CircuitState.fromJson(json);
}

const crusherRouter = CircuitWireLayoutEngine(
  router: OrthogonalWireRouter(
    grid: 24,
    obstacleClearance: 24,
    envelopePadding: 120,
  ),
);
CircuitVisualLayout crusherLayout() => CircuitVisualLayout(
  elementPositions: {
    'grid': const Offset(120, 160),
    'crusher': const Offset(540, 340),
  },
  elementSizes: {'grid': const Size(140, 160), 'crusher': const Size(480, 440)},
);
void main() {
  testNativeMotorBridges();
  test(
    'crusher supply routes remain orthogonal and migration is idempotent',
    () {
      final c = crusherFixture();
      final original = crusherRouter.routeAll(
        circuit: c,
        layout: crusherLayout(),
      );
      final migrated = migrateCrusherPhysicalLayout(
        c,
        original,
        router: crusherRouter,
      );
      final g = CircuitGeometryIndex.build(c, migrated);
      for (final w in c.connections) {
        final points = [
          g.terminalPositions[w.fromTerminalId]!,
          ...migrated.routeFor(w.id.value),
          g.terminalPositions[w.toTerminalId]!,
        ];
        for (var i = 1; i < points.length; i++) {
          final d = points[i] - points[i - 1];
          expect(d.dx.abs() < .001 || d.dy.abs() < .001, isTrue);
        }
      }
      expect(
        identical(
          migrateCrusherPhysicalLayout(c, migrated, router: crusherRouter),
          migrated,
        ),
        isTrue,
      );
    },
  );
  test('native winding contacts and PE scale and rotate with body', () {
    final c = crusherFixture();
    final l = crusherLayout();
    final g = CircuitGeometryIndex.build(c, l);
    expect(g.terminalPositions[TerminalId('U1')], const Offset(494, 468));
    expect(
      g.terminalPositions[TerminalId('crusher:chassis-pe')],
      const Offset(560, 494),
    );
    expect(
      F18ReferenceComponentMetrics.boardSizeFor(
        'catalog_motor_driven_6t',
        variantKey: 'crusher',
      ),
      const Size(480, 440),
    );
    final rotated = CircuitVisualLayout(
      elementPositions: l.elementPositions,
      elementSizes: l.elementSizes,
      elementQuarterTurns: {'crusher': 1},
    );
    final r = CircuitGeometryIndex.build(c, rotated);
    expect(
      (r.terminalPositions[TerminalId('U1')]! - const Offset(540, 340))
          .distance,
      closeTo((const Offset(-46, 128)).distance, 1e-8),
    );
  });
  test(
    'repair preserves circuit, custom anchors, placements and unrelated routes',
    () {
      final c = crusherFixture();
      final saved = c.toJson();
      final l = crusherLayout();
      final old = CircuitVisualLayout(
        elementPositions: l.elementPositions,
        elementSizes: l.elementSizes,
        terminalAnchorOffsets: {
          'U1': const Offset(-96, -184.8),
          'V1': const Offset(5, 5),
        },
        wireRoutes: {
          'a': [const Offset(220, 100)],
          'unrelated': [const Offset(11, 22)],
        },
      );
      final fixed = migrateCrusherPhysicalLayout(c, old, router: crusherRouter);
      expect(fixed.elementPositions, old.elementPositions);
      expect(fixed.elementSizes, old.elementSizes);
      expect(fixed.terminalAnchorOffsets.containsKey('U1'), isFalse);
      expect(fixed.terminalAnchorOffsets['V1'], const Offset(5, 5));
      expect(fixed.wireRoutes['unrelated'], old.wireRoutes['unrelated']);
      expect(c.toJson(), saved);
      expect(const ElectroSimRuntimeEngine().evaluate(c).solved, isTrue);
      expect(
        MotorThreePhaseCouplingEvaluator.evaluate(
          c,
          c.components.single,
        ).isValid,
        isTrue,
      );
    },
  );
}

void testNativeMotorBridges() {
  test('star/delta stay inside native terminal box through all rotations', () {
    for (final standalone in [false, true]) {
      for (final delta in [false, true]) {
        final data =
            jsonDecode(jsonEncode(crusherFixture().toJson()))
                as Map<String, dynamic>;
        final components = (data['components'] as List)
            .cast<Map<String, dynamic>>();
        if (standalone) {
          components.single['modelType'] = 'motor_3p_6t';
          components.single['terminals'] =
              (components.single['terminals'] as List).take(6).toList();
          (components.single['parameters'] as Map)['_visualModelType'] =
              'motor_3p_6t';
        }
        final links = (data['connections'] as List)
            .cast<Map<String, dynamic>>();
        links.removeWhere(
          (w) =>
              w['id'] == 'star1' ||
              w['id'] == 'star2' ||
              (standalone && w['id'] == 'pe'),
        );
        Connection wire(String id, String a, String b) => Connection(
          id: ConnectionId(id),
          fromTerminalId: TerminalId(a),
          toTerminalId: TerminalId(b),
        );
        links.addAll(
          (delta
                  ? [
                      wire('bridge1', 'U1', 'W2'),
                      wire('bridge2', 'V1', 'U2'),
                      wire('bridge3', 'W1', 'V2'),
                    ]
                  : [wire('bridge1', 'U2', 'V2'), wire('bridge2', 'V2', 'W2')])
              .map((w) => w.toJson()),
        );
        final c = CircuitState.fromJson(data);
        expect(
          MotorThreePhaseCouplingEvaluator.evaluate(
            c,
            c.components.single,
          ).isValid,
          isTrue,
        );
        for (var q = 0; q < 4; q++) {
          final base = crusherLayout();
          final l = CircuitVisualLayout(
            elementPositions: base.elementPositions,
            elementSizes: {
              ...base.elementSizes,
              'crusher': standalone
                  ? const Size(750, 430)
                  : const Size(480, 440),
            },
            elementQuarterTurns: {'crusher': q},
          );
          final routed = crusherRouter.routeAll(circuit: c, layout: l);
          final saved = CircuitVisualLayout(
            elementPositions: l.elementPositions,
            elementSizes: l.elementSizes,
            elementQuarterTurns: l.elementQuarterTurns,
            wireRoutes: {
              ...routed.wireRoutes,
              'bridge1': [const Offset(-999, -999)],
            },
          );
          final repaired = repairNativeMotorBridgeRoutes(c, saved);
          expect(repaired.routeFor('bridge1'), isEmpty);
          expect(
            identical(repairNativeMotorBridgeRoutes(c, repaired), repaired),
            isTrue,
          );
          final g = CircuitGeometryIndex.build(c, routed);
          final studs = c.components.single.terminals
              .take(6)
              .map((t) => g.terminalPositions[t.id]!)
              .toList();
          var bounds = Rect.fromPoints(studs.first, studs.last);
          for (final p in studs) {
            bounds = bounds.expandToInclude(Rect.fromLTWH(p.dx, p.dy, 0, 0));
          }
          for (final w in c.connections.where(
            (w) => w.id.value.startsWith('bridge'),
          )) {
            final points = [
              g.terminalPositions[w.fromTerminalId]!,
              ...routed.routeFor(w.id.value),
              g.terminalPositions[w.toTerminalId]!,
            ];
            expect(points.every(bounds.inflate(.001).contains), isTrue);
            for (var i = 1; i < points.length; i++) {
              final d = points[i] - points[i - 1];
              expect(d.dx.abs() < .001 || d.dy.abs() < .001, isTrue);
            }
          }
        }
      }
    }
  });
}
