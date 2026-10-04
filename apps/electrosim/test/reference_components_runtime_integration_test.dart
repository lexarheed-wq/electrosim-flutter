import 'dart:ui' as ui;

import 'package:electrosim/f18_component_asset_visual.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim/reference_components/reference_widgets_extended.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Integrated reference component runtime candidate', () {
    for (final MapEntry<String, double> entry in const <String, double>{
      'motor_dc': 8,
      'fan_dc': 12,
      'buzzer': 48,
      'relay_coil': 120,
      'lamp': 24,
      'resistor': 100,
    }.entries) {
      test('${entry.key} receives real solved DC current', () {
        final ElectroSimRuntimeSnapshot snapshot =
            const ElectroSimRuntimeEngine().evaluate(
          _singleLoadCircuit(
            modelType: entry.key,
            resistanceOhm: entry.value,
          ),
        );

        expect(snapshot.dc.status, DcSolveStatus.solved);
        final double currentA =
            snapshot.dc.branch('component:load').currentA ?? 0;
        expect(currentA.abs(), greaterThan(1e-6), reason: entry.key);
      });
    }

    test('push_button_nc conducts released and opens while pressed', () {
      final ElectroSimRuntimeSnapshot released =
          const ElectroSimRuntimeEngine().evaluate(
        _singleLoadCircuit(
          modelType: 'push_button_nc',
          controlState: const <String, Object?>{'pressed': false},
        ),
      );
      expect(released.dc.status, DcSolveStatus.solved);
      expect(
        (released.dc.branch('component:load').currentA ?? 0).abs(),
        greaterThan(1e-6),
      );

      final ElectroSimRuntimeSnapshot pressed =
          const ElectroSimRuntimeEngine().evaluate(
        _singleLoadCircuit(
          modelType: 'push_button_nc',
          controlState: const <String, Object?>{'pressed': true},
        ),
      );
      expect(pressed.dc.status, DcSolveStatus.solved);
      expect(
        (pressed.dc.branch('component:load').currentA ?? 0).abs(),
        closeTo(0, 1e-12),
      );
    });

    testWidgets('motor runtime state maps to rotating production painter',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: F18ComponentAssetVisual(
              modelType: 'motor_dc',
              size: Size(230, 190),
              energized: true,
              currentA: 3,
              voltageV: 24,
              animationValue: .25,
            ),
          ),
        ),
      );
      await tester.pump();

      final ExtendedReferenceComponentView view =
          tester.widget<ExtendedReferenceComponentView>(
        find.byType(ExtendedReferenceComponentView),
      );
      expect(view.device, ExtendedReferenceDevice.motor);
      expect(view.state.speedRpm, closeTo(3000, 1e-9));
      expect(view.state.animationValue, .25);
    });

    testWidgets('fan animation changes rendered pixels while energized',
        (WidgetTester tester) async {
      final List<int> frameA = await _renderPixels(
        tester,
        modelType: 'fan_dc',
        animationValue: .05,
      );
      final List<int> frameB = await _renderPixels(
        tester,
        modelType: 'fan_dc',
        animationValue: .55,
      );
      expect(frameA, isNot(equals(frameB)));
    });

    testWidgets('motor animation changes rendered pixels while energized',
        (WidgetTester tester) async {
      final List<int> frameA = await _renderPixels(
        tester,
        modelType: 'motor_dc',
        animationValue: .10,
      );
      final List<int> frameB = await _renderPixels(
        tester,
        modelType: 'motor_dc',
        animationValue: .60,
      );
      expect(frameA, isNot(equals(frameB)));
    });
  });
}

Future<List<int>> _renderPixels(
  WidgetTester tester, {
  required String modelType,
  required double animationValue,
}) async {
  final GlobalKey boundaryKey = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: RepaintBoundary(
          key: boundaryKey,
          child: F18ComponentAssetVisual(
            modelType: modelType,
            size: F18ReferenceComponentMetrics.boardSizeFor(modelType),
            energized: true,
            currentA: 2,
            voltageV: 24,
            animationValue: animationValue,
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  final RenderRepaintBoundary boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final ui.Image image = await boundary.toImage(pixelRatio: 1);
  final ByteData? data =
      await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!.buffer.asUint8List().toList(growable: false);
}

CircuitState _singleLoadCircuit({
  required String modelType,
  double? resistanceOhm,
  Map<String, Object?> controlState = const <String, Object?>{},
}) {
  final Terminal sourcePositive = Terminal(
    id: TerminalId('source-positive'),
    name: '+',
    role: TerminalRole.positive,
    phase: PhaseTag.dcPositive,
  );
  final Terminal sourceNegative = Terminal(
    id: TerminalId('source-negative'),
    name: '-',
    role: TerminalRole.negative,
    phase: PhaseTag.dcNegative,
  );
  final Terminal input = Terminal(
    id: TerminalId('load-input'),
    name: '1',
    role: TerminalRole.input,
  );
  final Terminal output = Terminal(
    id: TerminalId('load-output'),
    name: '2',
    role: TerminalRole.output,
  );

  return CircuitState(
    circuitId: CircuitId('reference-runtime-$modelType'),
    revision: 1,
    mode: ElectricalMode.dc,
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('source'),
        modelType: 'dc_voltage_source',
        terminals: <Terminal>[sourcePositive, sourceNegative],
        parameters: const <String, Object?>{'voltageV': 24.0},
      ),
    ],
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId('load'),
        modelType: modelType,
        terminals: <Terminal>[input, output],
        parameters: resistanceOhm == null
            ? const <String, Object?>{}
            : <String, Object?>{'resistanceOhm': resistanceOhm},
        controlState: controlState,
      ),
    ],
    connections: <Connection>[
      Connection(
        id: ConnectionId('positive-wire'),
        fromTerminalId: sourcePositive.id,
        toTerminalId: input.id,
      ),
      Connection(
        id: ConnectionId('negative-wire'),
        fromTerminalId: output.id,
        toTerminalId: sourceNegative.id,
      ),
    ],
  );
}
