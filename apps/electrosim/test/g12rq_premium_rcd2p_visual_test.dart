import 'package:electrosim/f18_premium_rcd2p_showcase.dart';
import 'package:electrosim/reference_components/disjoncteur_3d.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the two views are native projector settings, not matrix wrappers', () {
    expect(VueDisjoncteur.palette.angleHorizontal, 10);
    expect(VueDisjoncteur.palette.angleVertical, -12);
    expect(VueDisjoncteur.platine.angleHorizontal, 0);
    expect(VueDisjoncteur.platine.angleVertical, 0);
  });

  test('four named sockets are symmetric only in frontal board view', () {
    const size = Size(280, 430);
    final front = Disjoncteur3D.positionsBornes(
      size,
      vue: VueDisjoncteur.platine,
    );
    final perspective = Disjoncteur3D.positionsBornes(
      size,
      vue: VueDisjoncteur.palette,
    );
    expect(front.keys.toSet(), BorneDisjoncteur.values.toSet());
    expect(
      front[BorneDisjoncteur.neutreEntree]!.dx,
      closeTo(front[BorneDisjoncteur.neutreSortie]!.dx, 0.001),
    );
    expect(
      front[BorneDisjoncteur.phaseEntree]!.dx,
      closeTo(front[BorneDisjoncteur.phaseSortie]!.dx, 0.001),
    );
    expect(
      front[BorneDisjoncteur.neutreEntree]!.dy,
      lessThan(front[BorneDisjoncteur.neutreSortie]!.dy),
    );
    expect(
      perspective[BorneDisjoncteur.neutreEntree],
      isNot(front[BorneDisjoncteur.neutreEntree]),
    );
  });

  testWidgets(
    'showcase uses exact premium widget in both views, not old painters',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: F18PremiumRcd2pShowcase())),
      );
      await tester.pumpAndSettle();
      final palette = tester.widget<Disjoncteur3D>(
        find.byKey(const Key('premium-rcd-palette')),
      );
      final platine = tester.widget<Disjoncteur3D>(
        find.byKey(const Key('premium-rcd-platine')),
      );
      expect(palette.vue, VueDisjoncteur.palette);
      expect(platine.vue, VueDisjoncteur.platine);
      expect(palette.onCommande, isNull);
      expect(platine.onCommande, isNull);
      expect(platine.onTest, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('actual Flutter raster: original 3D palette plus frontal board', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: F18PremiumRcd2pShowcase())),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(F18PremiumRcd2pShowcase),
      matchesGoldenFile('goldens/g12rq_premium_rcd2p_palette_board.png'),
    );
  });

  testWidgets(
    'the externally supplied tripped state is not mutated by a click',
    (tester) async {
      EtatDisjoncteur? requested;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: Disjoncteur3D(
              width: 280,
              height: 430,
              vue: VueDisjoncteur.platine,
              etat: EtatDisjoncteur.declenche,
              onCommande: (state) => requested = state,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final center = tester.getCenter(find.byType(Disjoncteur3D));
      await tester.tapAt(center + const Offset(0, 55));
      await tester.pump(const Duration(milliseconds: 90));
      await tester.tapAt(center + const Offset(0, 55));
      await tester.pumpAndSettle();
      expect(requested, EtatDisjoncteur.ouvert);
      expect(
        tester.widget<Disjoncteur3D>(find.byType(Disjoncteur3D)).etat,
        EtatDisjoncteur.declenche,
      );
    },
  );
}
