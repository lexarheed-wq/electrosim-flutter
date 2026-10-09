import 'package:electrosim/reference_components/disjoncteur_3d.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'missing physical plates preserve native commands and terminals',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMessageHandler('flutter/assets', (_) async => null);
      addTearDown(
        () => messenger.setMockMessageHandler('flutter/assets', null),
      );
      expect(await Disjoncteur3D.prechargerTextures(), isFalse);
      EtatDisjoncteur? requested;
      var tests = 0;
      BorneDisjoncteur? terminal;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: Disjoncteur3D(
              width: 280,
              height: 430,
              onCommande: (state) => requested = state,
              onTest: () => tests++,
              onBorne: (borne) => terminal = borne,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final detector = find
          .descendant(
            of: find.byType(Disjoncteur3D),
            matching: find.byType(GestureDetector),
          )
          .first;
      Focus.of(tester.element(detector)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(requested, EtatDisjoncteur.ferme);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      expect(tests, 1);
      final point = Disjoncteur3D.positionsBornes(
        const Size(280, 430),
      )[BorneDisjoncteur.phaseEntree]!;
      await tester.tapAt(tester.getTopLeft(find.byType(Disjoncteur3D)) + point);
      await tester.pump(const Duration(milliseconds: 350));
      expect(terminal, BorneDisjoncteur.phaseEntree);
      expect(tester.takeException(), isNull);
    },
  );
}
