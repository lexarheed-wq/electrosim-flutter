import 'dart:io';

import 'package:electrosim/reference_components/disjoncteur_3d.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    expect(await Disjoncteur3D.prechargerTextures(), isTrue);
  });
  testWidgets('G5 OFF ON TRIP: same industrial assembly, same four ports', (
    tester,
  ) async {
    final font = File('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');
    if (font.existsSync()) {
      final bytes = font.readAsBytesSync();
      await (FontLoader(
        'Roboto',
      )..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)))).load();
    }
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final layout = <EtatDisjoncteur>[
      EtatDisjoncteur.ouvert,
      EtatDisjoncteur.ferme,
      EtatDisjoncteur.declenche,
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFFE9EDF1),
          body: RepaintBoundary(
            key: const Key('g5-industrial-state-proof'),
            child: ColoredBox(
              color: const Color(0xFFE9EDF1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final state in layout)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(state.name.toUpperCase()),
                        const SizedBox(height: 8),
                        Disjoncteur3D(
                          key: Key('industrial-${state.name}'),
                          width: 190,
                          height: 310,
                          vue: VueDisjoncteur.platine,
                          etat: state,
                          calibreA: 16,
                          sensibiliteMA: 30,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Disjoncteur3D), findsNWidgets(3));

    final reference = Disjoncteur3D.positionsBornes(
      const Size(190, 310),
      vue: VueDisjoncteur.platine,
    );
    expect(reference.length, 4);
    expect(
      reference[BorneDisjoncteur.neutreEntree]!.dx,
      closeTo(reference[BorneDisjoncteur.neutreSortie]!.dx, 1e-6),
    );
    expect(
      reference[BorneDisjoncteur.phaseEntree]!.dx,
      closeTo(reference[BorneDisjoncteur.phaseSortie]!.dx, 1e-6),
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const Key('g5-industrial-state-proof')),
      matchesGoldenFile('goldens/g5_industrial_off_on_trip.png'),
    );
  });
}
