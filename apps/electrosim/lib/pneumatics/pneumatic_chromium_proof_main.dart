import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';
import 'package:flutter/material.dart';

import 'pneumatic_workshop_page.dart';

/// Actual R4 Flutter widget, prepopulated for automated browser evidence.
/// This is an isolated proof entrypoint; no drawing is fabricated or retouched.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final PneumaticWorkshopView view =
      Uri.base.queryParameters['view'] == 'schematic'
      ? PneumaticWorkshopView.schematic
      : PneumaticWorkshopView.physical;

  final CircuitState electricity = CircuitState(
    circuitId: CircuitId('pneumatic-chromium-proof'),
    revision: 0,
    mode: ElectricalMode.dc,
  );
  PneumaticWorkshopState stage = PneumaticWorkshopState(
    project: MultiphysicsProject(electricalCircuit: electricity),
  );
  const List<PneumaticDeviceKind> catalog = <PneumaticDeviceKind>[
    PneumaticDeviceKind.idealSource,
    PneumaticDeviceKind.valve32,
    PneumaticDeviceKind.valve52,
    PneumaticDeviceKind.singleActingCylinder,
    PneumaticDeviceKind.doubleActingCylinder,
    PneumaticDeviceKind.restrictor,
    PneumaticDeviceKind.checkValve,
    PneumaticDeviceKind.tee,
    PneumaticDeviceKind.manometer,
    PneumaticDeviceKind.silencer,
  ];

  for (int i = 0; i < catalog.length; i++) {
    final PneumaticDeviceKind kind = catalog[i];
    final String id = 'air${i + 1}';
    final List<String> labels = switch (kind) {
      PneumaticDeviceKind.idealSource => <String>['P'],
      PneumaticDeviceKind.valve32 => <String>['P', 'A', 'R'],
      PneumaticDeviceKind.valve52 => <String>['P', 'A', 'B', 'R', 'S'],
      PneumaticDeviceKind.singleActingCylinder => <String>['A'],
      PneumaticDeviceKind.doubleActingCylinder => <String>['A', 'B'],
      PneumaticDeviceKind.restrictor ||
      PneumaticDeviceKind.checkValve => <String>['A', 'B'],
      PneumaticDeviceKind.tee => <String>['1', '2', '3'],
      PneumaticDeviceKind.silencer => <String>['R'],
      PneumaticDeviceKind.manometer => <String>['P'],
      _ => <String>['P'],
    };
    final PneumaticDevice device = PneumaticDevice(
      id: id,
      kind: kind,
      ports: <PneumaticPort>[
        for (final String label in labels)
          PneumaticPort(
            id: PneumaticPortId('$id.$label'),
            deviceId: id,
            role: label == 'P'
                ? PneumaticPortRole.supply
                : label == 'R' || label == 'S'
                ? PneumaticPortRole.exhaust
                : PneumaticPortRole.work,
          ),
      ],
    );
    stage = stage.place(
      device: device,
      physicalPose: PhysicalViewPose(
        x: 36 + (i % 5) * 210,
        y: 54 + (i ~/ 5) * 190,
      ),
      schematicPose: PhysicalViewPose(
        x: 36 + (i % 5) * 210,
        y: 54 + (i ~/ 5) * 190,
      ),
    );
  }

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ElectroSim — Preuve Chromium R4',
      home: PneumaticWorkshopPage(
        initialProject: stage.project,
        initialView: view,
      ),
    ),
  );
}
