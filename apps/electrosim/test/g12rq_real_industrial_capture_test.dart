import 'package:electrosim/f18_component_asset_visual.dart';
import 'package:electrosim/f18_industrial_dual_view.dart';
import 'package:electrosim/f18_industrial_physical_devices.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const samples = <String>[
    'dc_voltage_source', 'breaker_dc', 'switch_spst', 'push_button_no',
    'lamp', 'fan_dc', 'motor_dc', 'relay_coil',
  ];

  for (var page = 0; page < 2; page++) {
    testWidgets('Flutter screenshot proof: genuine industrial models set $page',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final models = samples.sublist(page * 4, page * 4 + 4);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFFF0F3F5),
          body: Center(
            child: RepaintBoundary(
              key: const Key('industrial-proof-scene'),
              child: Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFFF0F3F5),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    for (final type in models)
                      Container(
                        width: 470,
                        height: 328,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCBD6DF)),
                        ),
                        child: Column(children: <Widget>[
                          Text(type, style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
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
                                  size: const Size(150, 210),
                                  child: F18ComponentAssetVisual(
                                    modelType: type, size: const Size(150, 210),
                                    energized: true, voltageV: 24,
                                    currentA: 1.2, ratedCurrentA: 16),
                                ),
                              ]),
                              Column(children: <Widget>[
                                const Text('PLATINE FACE'),
                                const SizedBox(height: 8),
                                F18IndustrialDualView(
                                  modelType: type,
                                  presentation:
                                      F18IndustrialPresentation.boardFront,
                                  size: const Size(150, 210),
                                  child: F18ComponentAssetVisual(
                                    modelType: type, size: const Size(150, 210),
                                    energized: true, voltageV: 24,
                                    currentA: 1.2, ratedCurrentA: 16),
                                ),
                              ]),
                            ],
                          ),
                        ]),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(find.byType(IndustrialPhysicalView), findsNWidgets(8));
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const Key('industrial-proof-scene')),
        matchesGoldenFile('goldens/g12rq_real_industrial_set$page.png'),
      );
    });
  }
}
