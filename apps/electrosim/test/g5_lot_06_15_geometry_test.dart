import 'dart:convert';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim/f18_physical_layout_migration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'g5_crusher_integration_test.dart' as crusher;

CircuitState machineFixture(
  NativeApplianceGeometry spec, {
  bool delta = false,
}) {
  final j =
      jsonDecode(jsonEncode(crusher.crusherFixture().toJson()))
          as Map<String, dynamic>;
  final c = (j['components'] as List).single as Map<String, dynamic>;
  final p = c['parameters'] as Map<String, dynamic>;
  p['_visualModelType'] = spec.visualType;
  p['_visualVariant'] = spec.variant;
  final wires = j['connections'] as List;
  if (delta) {
    wires.removeWhere((w) => w['id'] == 'star1' || w['id'] == 'star2');
    for (final pair in [
      ['U1', 'W2'],
      ['V1', 'U2'],
      ['W1', 'V2'],
    ]) {
      wires.add(
        Connection(
          id: ConnectionId('delta-${pair[0]}'),
          fromTerminalId: TerminalId(pair[0]),
          toTerminalId: TerminalId(pair[1]),
        ).toJson(),
      );
    }
  }
  return CircuitState.fromJson(j);
}

void main() {
  for (final s
      in NativeApplianceGeometry.catalogue.values
          .take(10)
          .where((s) => s.threePhase)) {
    test(
      '${s.key} places terminals in its own enclosure in four rotations',
      () {
        final c = machineFixture(s);
        for (var q = 0; q < 4; q++) {
          final l = CircuitVisualLayout(
            elementPositions: {
              'crusher': const Offset(500, 400),
              'grid': const Offset(100, 100),
            },
            elementSizes: {'crusher': s.boardSize},
            elementQuarterTurns: {'crusher': q},
          );
          final g = CircuitGeometryIndex.build(c, l);
          var expected = s.offsets(s.boardSize, 7).first;
          for (var i = 0; i < q; i++) {
            expected = Offset(-expected.dy, expected.dx);
          }
          expect(
            g.terminalPositions[c.components.single.terminals.first.id],
            const Offset(500, 400) + expected,
          );
        }
      },
    );
    for (final delta in [false, true]) {
      test(
        '${s.key} ${delta ? 'delta' : 'star'} links remain inside terminal box',
        () {
          final c = machineFixture(s, delta: delta);
          final l = crusher.crusherRouter.routeAll(
            circuit: c,
            layout: CircuitVisualLayout(
              elementPositions: {
                'crusher': const Offset(500, 400),
                'grid': const Offset(100, 100),
              },
              elementSizes: {'crusher': s.boardSize},
            ),
          );
          final box = Rect.fromLTWH(
            500 -
                s.boardSize.width / 2 +
                s.serviceBox.left * s.boardSize.width / s.designSize.width,
            400 -
                s.boardSize.height / 2 +
                s.serviceBox.top * s.boardSize.height / s.designSize.height,
            s.serviceBox.width * s.boardSize.width / s.designSize.width,
            s.serviceBox.height * s.boardSize.height / s.designSize.height,
          );
          final g = CircuitGeometryIndex.build(c, l);
          final ports = c.components.single.terminals
              .take(6)
              .map((t) => t.id)
              .toSet();
          for (final w in c.connections.where(
            (w) =>
                ports.contains(w.fromTerminalId) &&
                ports.contains(w.toTerminalId),
          )) {
            expect(l.routeFor(w.id.value), isEmpty);
            for (final point in [
              g.terminalPositions[w.fromTerminalId]!,
              ...l.routeFor(w.id.value),
              g.terminalPositions[w.toTerminalId]!,
            ]) {
              expect(
                box.contains(point),
                isTrue,
                reason: '${s.key} link leaves enclosure',
              );
            }
          }
          final old = CircuitVisualLayout(
            elementPositions: l.elementPositions,
            elementSizes: l.elementSizes,
            wireRoutes: {
              ...l.wireRoutes,
              'star1': [const Offset(-999, -999)],
            },
          );
          final repaired = repairNativeMotorBridgeRoutes(c, old);
          if (!delta) expect(repaired.routeFor('star1'), isEmpty);
          expect(c.toJson(), machineFixture(s, delta: delta).toJson());
        },
      );
    }
  }
}
