import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';

import 'main.dart' as product;

/// Evidence entry point. The actual production F18 workspace, canvas,
/// physical widget painter, viewport and menus are used; only its initial
/// furniture is deterministic. It does not replace or mock production UI.
void main() {
  final stage = Uri.base.queryParameters['stage'] ?? 'overview';
  const r = CabinetFixtureKind.dinRail;
  const d = CabinetFixtureKind.wireDuct;
  const t = CabinetFixtureKind.terminalZone;
  final isResized = stage == 'resized';
  final layout = CabinetLayout([
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
      bounds: const Rect.fromLTWH(655, 110, 45, 320),
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
        onExitWorkspace: () {},
      ),
    ),
  );
}
