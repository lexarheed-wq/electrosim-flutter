import 'package:electrosim/f18_component_asset_visual.dart';
import 'package:electrosim/f9_component_palette.dart';
import 'package:electrosim/reference_components/disjoncteur_3d.dart';
import 'package:electrosim_canvas/src/premium_rcd2p_terminal_geometry.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RCCB is AC1 only; four ports in immutable N/L/N/L order', () {
    final p = f9PaletteCatalog.singleWhere((e) => e.modelType == 'rcd_2p_ac1');
    expect(p.terminalCount, 4);
    expect(p.terminalLabels, <String>[
      'N entrée',
      'L entrée',
      'N sortie',
      'L sortie',
    ]);
    expect(p.terminals.map((e) => e.phase), <PhaseTag>[
      PhaseTag.neutral,
      PhaseTag.l1,
      PhaseTag.neutral,
      PhaseTag.l1,
    ]);
    expect(p.supportsMode(ElectricalMode.ac1), true);
    expect(p.supportsMode(ElectricalMode.dc), false);
    expect(p.supportsMode(ElectricalMode.ac3), false);
    expect(p.supportsMode(ElectricalMode.pv), false);
    expect(
      CoreComponentModelContracts.registry
          .resolve('breaker_ac1')!
          .terminalCount,
      2,
    );
    expect(
      CoreComponentModelContracts.registry.resolve('rcd_2p_ac1')!.terminalCount,
      4,
    );
  });

  test('every Canvas port lands on the actual 0/0 projected screw', () {
    for (final size in <Size>[
      const Size(160, 260),
      const Size(320, 520),
      const Size(140, 230),
    ]) {
      final painter = Disjoncteur3D.positionsBornes(
        size,
        vue: VueDisjoncteur.platine,
      );
      final offsets = PremiumRcd2pTerminalGeometry.offsets(size);
      final center = Offset(size.width / 2, size.height / 2);
      for (var i = 0; i < 4; i++) {
        final actual = center + offsets[i];
        final expected = painter[BorneDisjoncteur.values[i]]!;
        expect(
          (actual - expected).distance,
          lessThan(1e-4),
          reason: 'socket ${BorneDisjoncteur.values[i]} at $size',
        );
      }
    }
  });

  testWidgets('palette uses genuine native 3D camera, no legacy wrapper', (
    tester,
  ) async {
    final def = f9PaletteCatalog.singleWhere(
      (e) => e.modelType == 'rcd_2p_ac1',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Center(child: F9ComponentPreview(definition: def)),
      ),
    );
    final widget = tester.widget<Disjoncteur3D>(find.byType(Disjoncteur3D));
    expect(widget.vue, VueDisjoncteur.palette);
    expect(widget.calibreA, 16);
    expect(widget.sensibiliteMA, 30);
    expect(widget.width, greaterThanOrEqualTo(100));
    expect(widget.height, greaterThanOrEqualTo(175));
    expect(tester.takeException(), isNull);
  });

  testWidgets('board remains frontal, externally controlled and brand-free', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: F18ComponentAssetVisual(
            modelType: 'rcd_2p_ac1',
            size: Size(160, 260),
            closed: false,
            ratedCurrentA: 16,
            residualTripCurrentA: .03,
          ),
        ),
      ),
    );
    final w = tester.widget<Disjoncteur3D>(find.byType(Disjoncteur3D));
    expect(w.vue, VueDisjoncteur.platine);
    expect(w.etat, EtatDisjoncteur.ouvert);
    expect(w.sensibiliteMA, closeTo(30, 1e-9));
    expect(w.marque, isNull);
    expect(w.gamme, isNull);
    expect(w.reference, isNull);
    expect(tester.takeException(), isNull);
  });
}
