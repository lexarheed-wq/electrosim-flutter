import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';

import 'main.dart' as product;
import 'f18_industrial_physical_plate.dart';
import 'reference_components/disjoncteur_3d.dart';

/// Evidence entry point. The actual production F18 workspace, canvas,
/// physical widget painter, viewport and menus are used; only its initial
/// furniture is deterministic. It does not replace or mock production UI.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Disjoncteur3D.prechargerTextures();
  await F18PhysicalPlateAssets.preload();
  final stage = Uri.base.queryParameters['stage'] ?? 'overview';
  const r = CabinetFixtureKind.dinRail;
  const d = CabinetFixtureKind.wireDuct;
  const t = CabinetFixtureKind.terminalZone;
  final isResized = stage == 'resized';
  final integrated = stage == 'integrated';
  final layout = integrated
      ? CabinetLayout([
          CabinetFixture(
            id: 'DIN-INTEGRATION',
            kind: r,
            bounds: const Rect.fromLTWH(846, 175, 240, 34),
          ),
          CabinetFixture(
            id: 'DUCT-INTEGRATION',
            kind: d,
            bounds: const Rect.fromLTWH(48, 560, 1200, 42),
          ),
        ])
      : CabinetLayout([
          CabinetFixture(
            id: 'DIN-35-01',
            kind: r,
            bounds: Rect.fromLTWH(110, 110, isResized ? 650 : 520, 34),
          ),
          CabinetFixture(
            id: 'DIN-35-02',
            kind: r,
            bounds: const Rect.fromLTWH(110, 260, 520, 34),
          ),
          CabinetFixture(
            id: 'DUCT-H-01',
            kind: d,
            bounds: const Rect.fromLTWH(110, 193, 520, 48),
          ),
          CabinetFixture(
            id: 'DUCT-V-02',
            kind: d,
            bounds: const Rect.fromLTWH(790, 110, 45, 320),
          ),
          CabinetFixture(
            id: 'TERMINAL-ZONE-01',
            kind: t,
            bounds: const Rect.fromLTWH(140, 360, 370, 56),
          ),
        ]);
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ElectroSimTheme.light(),
      home: product.F18WorkspacePage(
        entryLabel: 'Preuve Chromium P2 : armoire industrielle',
        initialWorkspace: 'Câblage',
        initialCabinetLayout: layout,
        initialCircuit: integrated
            ? CircuitState(
                circuitId: CircuitId('g5-p2-proof'),
                revision: 0,
                mode: ElectricalMode.ac3,
                components: [
                  for (final type in ['motor_3p_6t', 'breaker_3p', 'lamp'])
                    ComponentInstance(
                      id: ComponentId(type),
                      modelType: type,
                      terminals: List.generate(
                        CoreComponentModelContracts.registry
                            .resolve(type)!
                            .terminalCount,
                        (i) => Terminal(
                          id: TerminalId('$type-$i'),
                          name: '${i + 1}',
                        ),
                      ),
                    ),
                ],
              )
            : null,
        onExitWorkspace: () {},
      ),
    ),
  );
}
