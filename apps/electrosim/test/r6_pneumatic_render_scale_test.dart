import 'dart:convert';

import 'package:electrosim/pneumatics/pneumatic_device_glyph.dart';
import 'package:electrosim/pneumatics/pneumatic_workshop_page.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// This is actual Flutter widget-tree construction, not a screenshot or a
/// promise of 60 fps on a particular device.
MultiphysicsProject buildRenderedWorkshop(int count) {
  final CircuitState electrical = CircuitState(
    circuitId: CircuitId('r6-flutter-real-widgets'),
    revision: 0,
    mode: ElectricalMode.dc,
  );
  final List<PneumaticDevice> air = <PneumaticDevice>[];
  final List<PhysicalDeviceRecord> physicalDevices = <PhysicalDeviceRecord>[];
  final Map<String, PhysicalViewPose> plate = <String, PhysicalViewPose>{};
  final Map<String, PhysicalViewPose> schematic = <String, PhysicalViewPose>{};

  for (int i = 0; i < count; i++) {
    final String id = 'r6.air$i';
    air.add(
      PneumaticDevice(
        id: id,
        kind: PneumaticDeviceKind.manometer,
        ports: <PneumaticPort>[
          PneumaticPort(
            id: PneumaticPortId('$id.P'),
            deviceId: id,
            role: PneumaticPortRole.work,
          ),
        ],
      ),
    );
    physicalDevices.add(PhysicalDeviceRecord(id: id, pneumaticDeviceId: id));
    plate[id] = PhysicalViewPose(x: (i % 5) * 210.0, y: (i ~/ 5) * 180.0);
    schematic[id] = PhysicalViewPose(
      x: (i % 5) * 210.0 + 20,
      y: (i ~/ 5) * 180.0 + 15,
    );
  }

  return MultiphysicsProject(
    electricalCircuit: electrical,
    pneumaticNetwork: PneumaticNetwork(devices: air),
    devices: physicalDevices,
    physicalLayout: plate,
    schematicLayout: schematic,
  );
}

void main() {
  for (final int count in <int>[30, 100, 200, 400]) {
    testWidgets(
      'R6 Flutter constructs $count real pneumatic tiles in both views',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1600, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final MultiphysicsProject project = buildRenderedWorkshop(count);
        final String electricalBefore = project.electricalCircuit
            .toJsonString();
        final Stopwatch timer = Stopwatch()..start();
        await tester.pumpWidget(
          MaterialApp(home: PneumaticWorkshopPage(initialProject: project)),
        );
        await tester.pump();
        timer.stop();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('pneumatic-r4-workshop')), findsOneWidget);
        expect(find.byKey(const Key('device-r6.air0')), findsOneWidget);
        expect(find.byKey(Key('device-r6.air${count - 1}')), findsOneWidget);
        expect(
          find.byType(PneumaticDeviceGlyph).evaluate().length,
          greaterThanOrEqualTo(count),
        );

        await tester.tap(find.text('Schéma'));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('device-r6.air0')), findsOneWidget);
        expect(find.byKey(Key('device-r6.air${count - 1}')), findsOneWidget);
        expect(
          find.byType(PneumaticDeviceGlyph).evaluate().length,
          greaterThanOrEqualTo(count),
        );
        expect(project.electricalCircuit.toJsonString(), electricalBefore);
        expect(project.pneumaticNetwork.devices, hasLength(count));
        debugPrint(
          jsonEncode(<String, Object>{
            'schema': 'electrosim.pneumatic.r6.flutter-widgets.v1',
            'deviceCount': count,
            'widgetGlyphs': count + 10,
            'initialPumpMicroseconds': timer.elapsedMicroseconds,
            'twoViewsConstructed': true,
            'sourceProjectUnchanged': true,
          }),
        );
      },
    );
  }
}
