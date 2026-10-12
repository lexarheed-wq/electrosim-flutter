import 'package:electrosim/pneumatics/pneumatic_workshop_page.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'r6n_inline_test_worker.dart';

PneumaticDevice device(
  String id,
  PneumaticDeviceKind kind,
  List<String> names,
  PneumaticPortRole role,
  Map<String, double> properties,
) => PneumaticDevice(
  id: id,
  kind: kind,
  ports: <PneumaticPort>[
    for (final String name in names)
      PneumaticPort(id: PneumaticPortId('$id.$name'), deviceId: id, role: role),
  ],
  parametersSi: properties,
);

MultiphysicsProject project({bool unsupportedValve = false}) {
  final List<PneumaticDevice> devices = unsupportedValve
      ? <PneumaticDevice>[
          device(
            'valve',
            PneumaticDeviceKind.valve52,
            <String>['P'],
            PneumaticPortRole.supply,
            <String, double>{},
          ),
        ]
      : <PneumaticDevice>[
          device(
            'supply',
            PneumaticDeviceKind.idealSource,
            <String>['P'],
            PneumaticPortRole.supply,
            <String, double>{'pressureAbsPa': 601325},
          ),
          device(
            'middle',
            PneumaticDeviceKind.manifold,
            <String>['1', '2'],
            PneumaticPortRole.work,
            <String, double>{'pressureAbsPa': 101325, 'volumeM3': .002},
          ),
          device(
            'vent',
            PneumaticDeviceKind.silencer,
            <String>['R'],
            PneumaticPortRole.exhaust,
            <String, double>{'pressureAbsPa': 101325},
          ),
        ];
  return MultiphysicsProject(
    electricalCircuit: CircuitState(
      circuitId: CircuitId('r6f-ui-real-network'),
      revision: 0,
      mode: ElectricalMode.dc,
    ),
    pneumaticNetwork: PneumaticNetwork(
      devices: devices,
      pipes: unsupportedValve
          ? <PneumaticPipe>[]
          : <PneumaticPipe>[
              PneumaticPipe(
                id: 'supply.line',
                fromPortId: PneumaticPortId('supply.P'),
                toPortId: PneumaticPortId('middle.1'),
                lengthM: .5,
                innerDiameterM: .001,
                lossCoefficient: 2,
              ),
              PneumaticPipe(
                id: 'vent.line',
                fromPortId: PneumaticPortId('middle.2'),
                toPortId: PneumaticPortId('vent.R'),
                lengthM: .5,
                innerDiameterM: .001,
                lossCoefficient: 2,
              ),
            ],
    ),
    devices: <PhysicalDeviceRecord>[
      for (final PneumaticDevice d in devices)
        PhysicalDeviceRecord(id: d.id, pneumaticDeviceId: d.id),
    ],
    physicalLayout: <String, PhysicalViewPose>{
      for (int i = 0; i < devices.length; i++)
        devices[i].id: PhysicalViewPose(x: 50 + 210.0 * i, y: 90),
    },
    schematicLayout: <String, PhysicalViewPose>{
      for (int i = 0; i < devices.length; i++)
        devices[i].id: PhysicalViewPose(x: 60 + 210.0 * i, y: 140),
    },
  );
}

Future<void> setSize(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 950);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('R6/F authored graph advances actual solver and survives view', (
    WidgetTester tester,
  ) async {
    await setSize(tester);
    await tester.pumpWidget(
      MaterialApp(home: PneumaticWorkshopPage(
          initialProject: project(),
          workerFactory: createInlineCanonicalTestWorker,
        )),
    );
    await tester.tap(find.byKey(const Key('device-middle')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('air-advance')));
    await tester.pumpAndSettle();
    expect(find.text('Coefficient d’écoulement Cd'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, '0.8');
    await tester.tap(find.byKey(const Key('air-cd-apply')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Simulation réelle : t = 0.020 s'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('air-measured-pressure')), findsOneWidget);
    expect(find.byKey(const Key('air-measured-flows')), findsOneWidget);
    await tester.tap(find.text('Schéma'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('air-measured-pressure')), findsOneWidget);
    await tester.tap(find.byKey(const Key('air-reset-physics')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('air-measured-pressure')), findsNothing);
  });

  testWidgets('R6/F unsupported valve gives error, not a fictitious result', (
    WidgetTester tester,
  ) async {
    await setSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: PneumaticWorkshopPage(
          initialProject: project(unsupportedValve: true),
          workerFactory: createInlineCanonicalTestWorker,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('air-advance')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, '0.8');
    await tester.tap(find.byKey(const Key('air-cd-apply')));
    await tester.pumpAndSettle();
    expect(find.textContaining('missing_valve_calibration'), findsOneWidget);
    expect(find.textContaining('Simulation réelle'), findsNothing);
  });

  testWidgets('R6/F authored calibration is editable and undoable', (
    WidgetTester tester,
  ) async {
    await setSize(tester);
    await tester.pumpWidget(
      MaterialApp(home: PneumaticWorkshopPage(
          initialProject: project(),
          workerFactory: createInlineCanonicalTestWorker,
        )),
    );
    await tester.tap(find.byKey(const Key('device-middle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('air-calibrate-device')));
    await tester.pumpAndSettle();
    expect(find.text('Calibrer middle — unités SI'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '250000');
    await tester.tap(find.byKey(const Key('air-calibration-apply')));
    await tester.pumpAndSettle();
    expect(find.textContaining('pressureAbsPa=250000.0'), findsOneWidget);
    await tester.tap(find.byKey(const Key('air-undo')));
    await tester.pumpAndSettle();
    expect(find.textContaining('pressureAbsPa=101325.0'), findsOneWidget);
  });
}
