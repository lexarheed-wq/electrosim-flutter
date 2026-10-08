// flutter test tool/capture_industrial_plate_test.dart
// ELECTROSIM_UI_CAPTURE_DIR overrides the output directory.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:electrosim/f18_component_asset_visual.dart';
import 'package:electrosim/f9_component_palette.dart';
import 'package:electrosim/f9_component_visuals.dart';
import 'package:electrosim/professional_residual_current_visual.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/capture_fonts.dart';

void main() {
  setUpAll(loadCaptureFonts);
  testWidgets('capture real production plate and visual-only differential', (
    t,
  ) async {
    t.view.physicalSize = const Size(1120, 820);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final components = <ComponentInstance>[];
    for (final entry in [
      ('Q1', 'breaker-3p'),
      ('KM1', 'contactor-3p'),
      ('F1', 'thermal-overload-3p'),
      ('S1', 'push-button-no'),
      ('S2', 'push-button-nc'),
      ('M1', 'motor-3p-6t'),
    ]) {
      final spec = f9PaletteCatalog.singleWhere((d) => d.keyName == entry.$2);
      components.add(
        ComponentInstance(
          id: ComponentId(entry.$1),
          modelType: spec.modelType,
          parameters: {...spec.defaultParameters, '_displayLabel': entry.$1},
          controlState: spec.defaultControlState,
          terminals: [
            for (var i = 0; i < spec.terminalCount; i++)
              Terminal(
                id: TerminalId('${entry.$1}-$i'),
                name: spec.terminals.isEmpty
                    ? spec.terminalLabels[i]
                    : spec.terminals[i].label,
                role: spec.terminals.isEmpty
                    ? TerminalRole.generic
                    : spec.terminals[i].role,
                phase: spec.terminals.isEmpty
                    ? PhaseTag.none
                    : spec.terminals[i].phase,
              ),
          ],
        ),
      );
    }
    final connections = <Connection>[];
    for (final pair in [('Q1', 'KM1'), ('KM1', 'F1'), ('F1', 'M1')]) {
      for (var i = 0; i < 3; i++) {
        connections.add(
          Connection(
            id: ConnectionId('${pair.$1}-${pair.$2}-$i'),
            fromTerminalId: TerminalId('${pair.$1}-${i + 3}'),
            toTerminalId: TerminalId('${pair.$2}-$i'),
            phase: [PhaseTag.l1, PhaseTag.l2, PhaseTag.l3][i],
          ),
        );
      }
    }
    for (var i = 3; i < 5; i++) {
      connections.add(
        Connection(
          id: ConnectionId('star-$i'),
          fromTerminalId: TerminalId('M1-$i'),
          toTerminalId: TerminalId('M1-${i + 1}'),
        ),
      );
    }
    final circuit = CircuitState(
      circuitId: CircuitId('render-validation'),
      revision: 1,
      mode: ElectricalMode.ac3,
      components: components,
      connections: connections,
    );
    final layout =
        const CircuitWireLayoutEngine(
          router: OrthogonalWireRouter(
            grid: 24,
            obstacleClearance: 24,
            envelopePadding: 120,
          ),
        ).routeAll(
          circuit: circuit,
          layout: CircuitVisualLayout(
            elementPositions: const {
              'Q1': Offset(135, 165),
              'KM1': Offset(455, 165),
              'F1': Offset(455, 455),
              'S1': Offset(135, 455),
              'S2': Offset(255, 455),
              'M1': Offset(740, 455),
            },
            elementSizes: {
              for (final c in components)
                c.id.value: F18ReferenceComponentMetrics.boardSizeFor(
                  c.modelType,
                ),
            },
          ),
        );
    final viewport = ViewportController(
      scale: 1.1,
      translation: const Offset(50, 25),
    );
    final boundaryKey = GlobalKey();
    final oldShadows = debugDisableShadows;
    debugDisableShadows = false;
    try {
      await t.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ElectroSimTheme.light(),
          home: RepaintBoundary(
            key: boundaryKey,
            child: Scaffold(
              appBar: AppBar(
                backgroundColor: ElectroSimColors.workspaceHeader,
                foregroundColor: Colors.white,
                title: const Text(
                  'ElectroSim · Rendu des composants',
                  style: TextStyle(fontSize: 20),
                ),
                actions: const [
                  Center(
                    child: Padding(
                      padding: EdgeInsets.only(right: 24),
                      child: Text('SCÈNE DE VALIDATION'),
                    ),
                  ),
                ],
              ),
              body: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: CircuitScenePainter(
                        circuit: circuit,
                        layout: layout,
                        viewport: viewport,
                        paintElementChrome: false,
                        smartWireSemantics: true,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: F9CanvasVisualOverlay(
                      circuit: circuit,
                      layout: layout,
                      viewport: viewport,
                    ),
                  ),
                  // Separate artwork: not connected to the sample circuit.
                  Positioned(
                    left: 305,
                    top: 105,
                    child: Column(
                      children: const [
                        ResidualCurrentVisual(),
                        SizedBox(height: 6),
                        Text(
                          'Différentiel · rendu seul',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Rendus Flutter réels · Circuit sans alimentation · Différentiel : modèle électrique non intégré',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await t.runAsync(() async {
        final output = Directory(
          Platform.environment['ELECTROSIM_UI_CAPTURE_DIR'] ??
              'build/professional-workspace-captures',
        );
        await output.create(recursive: true);
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${output.path}/industrial-plate.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
      await t.pumpWidget(const SizedBox());
    } finally {
      debugDisableShadows = oldShadows;
      viewport.dispose();
    }
  });
}
