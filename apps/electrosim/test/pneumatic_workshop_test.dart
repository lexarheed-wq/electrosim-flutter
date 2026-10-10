import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';
import 'package:electrosim/pneumatics/pneumatic_workshop_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('R4 opt-in: one device appears in plate and schematic', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: PneumaticWorkshopPage()));
    await tester.tap(find.byKey(const Key('add-idealSource')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('device-air1')), findsOneWidget);

    await tester.tap(find.text('Schéma'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('device-air1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('air-undo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('device-air1')), findsNothing);

    await tester.tap(find.byKey(const Key('air-redo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('device-air1')), findsOneWidget);
  });

  testWidgets('R4 editor honors existing multiphysics identity', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final PneumaticDevice device = PneumaticDevice(
      id: 'valve',
      kind: PneumaticDeviceKind.valve52,
      ports: <PneumaticPort>[
        PneumaticPort(
          id: PneumaticPortId('valve.P'),
          deviceId: 'valve',
          role: PneumaticPortRole.supply,
        ),
      ],
    );
    final MultiphysicsProject project = MultiphysicsProject(
      electricalCircuit: CircuitState(
        circuitId: CircuitId('r4-existing'),
        revision: 0,
        mode: ElectricalMode.dc,
      ),
      pneumaticNetwork: PneumaticNetwork(devices: <PneumaticDevice>[device]),
      devices: <PhysicalDeviceRecord>[
        PhysicalDeviceRecord(id: 'valve', pneumaticDeviceId: 'valve'),
      ],
      physicalLayout: <String, PhysicalViewPose>{
        'valve': PhysicalViewPose(x: 75, y: 65),
      },
      schematicLayout: <String, PhysicalViewPose>{
        'valve': PhysicalViewPose(x: 140, y: 180),
      },
    );
    await tester.pumpWidget(
      MaterialApp(home: PneumaticWorkshopPage(initialProject: project)),
    );
    expect(find.byKey(const Key('device-valve')), findsOneWidget);
    await tester.tap(find.text('Schéma'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('device-valve')), findsOneWidget);
    expect(project.physicalLayout['valve']!.x, 75);
    expect(project.schematicLayout['valve']!.x, 140);
  });
}
