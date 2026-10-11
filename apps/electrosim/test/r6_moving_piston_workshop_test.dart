import 'package:electrosim/pneumatics/pneumatic_device_glyph.dart';
import 'package:electrosim/pneumatics/pneumatic_workshop_page.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PneumaticPort port(String owner, String suffix, PneumaticPortRole role) =>
    PneumaticPort(
      id: PneumaticPortId('$owner.$suffix'),
      deviceId: owner,
      role: role,
    );

PneumaticDevice reservoir(String id, PneumaticDeviceKind kind, double p) =>
    PneumaticDevice(
      id: id,
      kind: kind,
      ports: <PneumaticPort>[
        port(
          id,
          '1',
          kind == PneumaticDeviceKind.idealSource
              ? PneumaticPortRole.supply
              : PneumaticPortRole.exhaust,
        ),
      ],
      parametersSi: <String, double>{'pressureAbsPa': p},
    );

PneumaticPipe hose(String id, String from, String to) => PneumaticPipe(
  id: id,
  fromPortId: PneumaticPortId(from),
  toPortId: PneumaticPortId(to),
  lengthM: .2,
  innerDiameterM: .003,
  lossCoefficient: 1,
);

MultiphysicsProject actualProject() {
  final List<PneumaticDevice> devices = <PneumaticDevice>[
    reservoir('supply', PneumaticDeviceKind.idealSource, 701325),
    reservoir('ventR', PneumaticDeviceKind.silencer, 101325),
    reservoir('ventS', PneumaticDeviceKind.silencer, 101325),
    PneumaticDevice(
      id: 'v52',
      kind: PneumaticDeviceKind.valve52,
      ports: <PneumaticPort>[
        port('v52', 'P', PneumaticPortRole.supply),
        port('v52', 'A', PneumaticPortRole.work),
        port('v52', 'B', PneumaticPortRole.work),
        port('v52', 'R', PneumaticPortRole.exhaust),
        port('v52', 'S', PneumaticPortRole.exhaust),
      ],
      parametersSi: <String, double>{
        'portDeadVolumeM3': .00001,
        'pressureAbsPa': 101325,
        'valveEffectiveAreaM2': .000004,
        'valveCd': .8,
        'energized': 1,
      },
    ),
    PneumaticDevice(
      id: 'cyl',
      kind: PneumaticDeviceKind.doubleActingCylinder,
      ports: <PneumaticPort>[
        port('cyl', 'A', PneumaticPortRole.work),
        port('cyl', 'B', PneumaticPortRole.work),
      ],
      parametersSi: <String, double>{
        'pistonDiameterM': .032,
        'rodDiameterM': .008,
        'strokeM': .06,
        'deadVolumeAM3': .00005,
        'deadVolumeBM3': .00005,
        'initialPositionM': .005,
        'initialPressureAAbsPa': 101325,
        'initialPressureBAbsPa': 101325,
        'movingMassKg': 1,
      },
    ),
  ];
  return MultiphysicsProject(
    electricalCircuit: CircuitState(
      circuitId: CircuitId('r6l-real-physical-piston'),
      revision: 0,
      mode: ElectricalMode.dc,
    ),
    pneumaticNetwork: PneumaticNetwork(
      devices: devices,
      pipes: <PneumaticPipe>[
        hose('P', 'supply.1', 'v52.P'),
        hose('A', 'v52.A', 'cyl.A'),
        hose('B', 'v52.B', 'cyl.B'),
        hose('R', 'v52.R', 'ventR.1'),
        hose('S', 'v52.S', 'ventS.1'),
      ],
    ),
    devices: <PhysicalDeviceRecord>[
      for (final PneumaticDevice d in devices)
        PhysicalDeviceRecord(id: d.id, pneumaticDeviceId: d.id),
    ],
    physicalLayout: <String, PhysicalViewPose>{
      for (int i = 0; i < devices.length; i++)
        devices[i].id: PhysicalViewPose(
          x: 60 + (i % 4) * 240.0,
          y: 95 + (i ~/ 4) * 210,
        ),
    },
    schematicLayout: <String, PhysicalViewPose>{
      for (int i = 0; i < devices.length; i++)
        devices[i].id: PhysicalViewPose(
          x: 70 + (i % 4) * 240.0,
          y: 145 + (i ~/ 4) * 210,
        ),
    },
  );
}

void main() {
  testWidgets(
    'R6/L accepted piston position renders identically in two views',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: PneumaticWorkshopPage(initialProject: actualProject()),
        ),
      );
      await tester.tap(find.byKey(const Key('device-cyl')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('air-advance')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, '0.8');
      await tester.tap(find.byKey(const Key('air-cd-apply')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('air-measured-position')), findsOneWidget);
      expect(
        find.textContaining('Simulation réelle : t = 0.020 s'),
        findsOneWidget,
      );
      final Finder actualGlyph = find.descendant(
        of: find.byKey(const Key('device-cyl')),
        matching: find.byType(PneumaticDeviceGlyph),
      );
      final PneumaticDeviceGlyph first = tester.widget<PneumaticDeviceGlyph>(
        actualGlyph,
      );
      expect(first.pistonFraction, isNotNull);
      expect(first.pistonFraction!, inInclusiveRange(0, 1));
      await tester.tap(find.text('Schéma'));
      await tester.pumpAndSettle();
      final PneumaticDeviceGlyph second = tester.widget<PneumaticDeviceGlyph>(
        actualGlyph,
      );
      expect(second.pistonFraction, first.pistonFraction);
      await tester.tap(find.byKey(const Key('air-reset-physics')));
      await tester.pumpAndSettle();
      final PneumaticDeviceGlyph reset = tester.widget<PneumaticDeviceGlyph>(
        actualGlyph,
      );
      expect(reset.pistonFraction, isNull);
      expect(find.byKey(const Key('air-measured-position')), findsNothing);
    },
  );

  testWidgets('R6/L cylinder geometry fields are user-authored, not defaults', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: PneumaticWorkshopPage(initialProject: actualProject())),
    );
    await tester.tap(find.byKey(const Key('device-cyl')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('air-calibrate-device')));
    await tester.pumpAndSettle();
    expect(find.text('Diamètre piston (m)'), findsOneWidget);
    expect(find.text('Position initiale (m)'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('air-measured-position')), findsNothing);
  });
}
