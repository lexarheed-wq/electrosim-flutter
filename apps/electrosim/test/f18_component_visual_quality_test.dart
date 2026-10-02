import 'dart:ui' as ui;

import 'package:electrosim/f18_component_visual_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const List<String> productionModels = <String>[
    'dc_voltage_source',
    'breaker',
    'switch',
    'push_button_no',
    'lamp',
    'multimeter',
    'resistor',
    'fuse',
    'buzzer',
    'diode',
    'motor_dc',
    'fan_dc',
    'relay_coil',
    'contactor',
    'inverter',
    'transformer',
    'pv_panel',
    'battery_storage',
    'regulator',
  ];

  test('G4-R1 common product components all have dedicated visuals', () {
    for (final String model in productionModels) {
      expect(
        F18ComponentVisualRegistry.hasDedicatedVisual(model),
        isTrue,
        reason: '$model must not regress to a generic archetype.',
      );
    }
  });

  test('G4-R1 dedicated visuals paint without exceptions', () {
    for (final String model in productionModels) {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      expect(
        F18ComponentVisualRegistry.paint(
          canvas,
          const Rect.fromLTWH(0, 0, 112, 92),
          model,
          const Color(0xFF174D89),
        ),
        isTrue,
        reason: '$model must be rendered by the dedicated registry.',
      );
      expect(recorder.endRecording(), isA<ui.Picture>());
    }
  });
}
