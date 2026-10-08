import 'dart:io';
import 'dart:ui' as ui;

import 'package:electrosim/f18_component_asset_visual.dart';
import 'package:electrosim/f18_industrial_dual_view.dart';
import 'package:electrosim/f18_industrial_physical_devices.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('capture real pixel proof of eight replaced industrial models',
      (tester) async {
    tester.view.physicalSize = const Size(2080, 1150);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const samples = <String>[
      'dc_voltage_source', 'breaker_dc', 'switch_spst', 'push_button_no',
      'lamp', 'fan_dc', 'motor_dc', 'relay_coil',
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFFF0F3F5),
          body: Center(
            child: RepaintBoundary(
              key: const Key('industrial-proof-scene'),
              child: Container(
                padding: const EdgeInsets.all(32),
                color: const Color(0xFFF0F3F5),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: <Widget>[
                    for (final type in samples)
                      Container(
                        width: 476,
                        height: 315,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFCBD6DF)),
                        ),
                        child: Column(
                          children: <Widget>[
                            Text(type, style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: <Widget>[
                                Column(children: <Widget>[
                                  const Text('PALETTE 3D'),
                                  const SizedBox(height: 8),
                                  F18IndustrialDualView(
                                    modelType: type,
                                    presentation:
                                        F18IndustrialPresentation.palettePerspective,
                                    size: const Size(165, 205),
                                    child: F18ComponentAssetVisual(
                                      modelType: type,
                                      size: const Size(165, 205),
                                      energized: true,
                                      voltageV: 24,
                                      currentA: 1.2,
                                      ratedCurrentA: 16,
                                    ),
                                  ),
                                ]),
                                Column(children: <Widget>[
                                  const Text('PLATINE FACE'),
                                  const SizedBox(height: 8),
                                  F18IndustrialDualView(
                                    modelType: type,
                                    presentation:
                                        F18IndustrialPresentation.boardFront,
                                    size: const Size(165, 205),
                                    child: F18ComponentAssetVisual(
                                      modelType: type,
                                      size: const Size(165, 205),
                                      energized: true,
                                      voltageV: 24,
                                      currentA: 1.2,
                                      ratedCurrentA: 16,
                                    ),
                                  ),
                                ]),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(IndustrialPhysicalView), findsNWidgets(16));
    expect(tester.takeException(), isNull);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('industrial-proof-scene')),
    );
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    expect(data, isNotNull);
    final destination = File('build/visual-proof/industrial-eight-views.png');
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(data!.buffer.asUint8List());
    expect(destination.lengthSync(), greaterThan(15000));
    image.dispose();
  });
}
