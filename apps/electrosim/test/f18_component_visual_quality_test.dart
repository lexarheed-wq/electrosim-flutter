import 'dart:typed_data';
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

  test('G4-R2 state-sensitive component visuals produce distinct pixels',
      () async {
    for (final String model in const <String>[
      'dc_voltage_source',
      'breaker',
      'switch',
      'lamp',
      'multimeter',
      'motor_dc',
      'fan_dc',
      'relay_coil',
      'contactor',
    ]) {
      final Uint8List active = await _raster(model, active: true);
      final Uint8List inactive = await _raster(model, active: false);
      expect(
        active,
        isNot(equals(inactive)),
        reason: '$model must visually expose its physical active state.',
      );
    }
  });

  test('G4-R2 fault state changes protected-device evidence', () async {
    final Uint8List normal = await _raster(
      'breaker',
      active: true,
      fault: false,
    );
    final Uint8List faulted = await _raster(
      'breaker',
      active: true,
      fault: true,
    );
    expect(normal, isNot(equals(faulted)));
  });
}


Future<Uint8List> _raster(
  String model, {
  required bool active,
  bool fault = false,
}) async {
  const int width = 180;
  const int height = 130;
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = Colors.white,
  );
  F18ComponentVisualRegistry.paint(
    canvas,
    const Rect.fromLTWH(20, 15, 140, 100),
    model,
    const Color(0xFF174D89),
    active: active,
    fault: fault,
  );
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(width, height);
  final ByteData data =
      (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final Uint8List bytes = data.buffer.asUint8List();
  image.dispose();
  picture.dispose();
  return bytes;
}
