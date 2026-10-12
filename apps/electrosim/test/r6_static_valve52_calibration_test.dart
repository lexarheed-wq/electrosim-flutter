import 'package:electrosim/pneumatics/pneumatic_workshop_page.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'r6n_inline_test_worker.dart';

MultiphysicsProject singleValve() {
  final PneumaticDevice valve = PneumaticDevice(
    id: 'v52',
    kind: PneumaticDeviceKind.valve52,
    ports: <PneumaticPort>[
      for (final (String id, PneumaticPortRole role)
          in <(String, PneumaticPortRole)>[
            ('P', PneumaticPortRole.supply),
            ('A', PneumaticPortRole.work),
            ('B', PneumaticPortRole.work),
            ('R', PneumaticPortRole.exhaust),
            ('S', PneumaticPortRole.exhaust),
          ])
        PneumaticPort(
          id: PneumaticPortId('v52.$id'),
          deviceId: 'v52',
          role: role,
        ),
    ],
  );
  return MultiphysicsProject(
    electricalCircuit: CircuitState(
      circuitId: CircuitId('r6h-isolated-static-valve'),
      revision: 0,
      mode: ElectricalMode.dc,
    ),
    pneumaticNetwork: PneumaticNetwork(devices: <PneumaticDevice>[valve]),
    devices: <PhysicalDeviceRecord>[
      PhysicalDeviceRecord(id: 'v52', pneumaticDeviceId: 'v52'),
    ],
    physicalLayout: <String, PhysicalViewPose>{
      'v52': PhysicalViewPose(x: 80, y: 80),
    },
    schematicLayout: <String, PhysicalViewPose>{
      'v52': PhysicalViewPose(x: 120, y: 120),
    },
  );
}

void main() {
  testWidgets(
    'R6/H static 5/2 positions are explicit and physically computed',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: PneumaticWorkshopPage(
            initialProject: singleValve(),
            workerFactory: createInlineCanonicalTestWorker,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('device-v52')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('air-calibrate-device')));
      await tester.pumpAndSettle();
      expect(find.text('Calibrer v52 — unités SI'), findsOneWidget);
      final Finder fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '101325');
      await tester.enterText(fields.at(1), '0.0002');
      await tester.enterText(fields.at(2), '0.000001');
      await tester.enterText(fields.at(3), '0.8');
      await tester.tap(find.byKey(const Key('air-valve-static-position')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Travail : P-A / B-S').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('air-calibration-apply')));
      await tester.pumpAndSettle();
      expect(find.textContaining('valveCd=0.8'), findsOneWidget);
      await tester.tap(find.byKey(const Key('air-advance')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, '0.8');
      await tester.tap(find.byKey(const Key('air-cd-apply')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Simulation réelle : t = 0.020 s'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('air-measured-flows')), findsOneWidget);
      await tester.tap(find.byKey(const Key('air-reset-physics')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Simulation réelle :'), findsNothing);
    },
  );
}
