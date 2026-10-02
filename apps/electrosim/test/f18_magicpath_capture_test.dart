import 'package:electrosim/f18_component_archetypes.dart';
import 'package:electrosim/f9_ui_context.dart';
import 'package:electrosim/main.dart' as app;
import 'package:electrosim/runtime/electrosim_tp_session_controller.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _setSurface(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
}

Future<void> _capture(
  WidgetTester tester,
  String filename,
) async {
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(Scaffold).first,
    matchesGoldenFile('_capture/$filename'),
  );
}

void main() {
  setUp(() {});

  testWidgets('capture F18 home desktop', (WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _setSurface(tester, const Size(1440, 900));
    await tester.pumpWidget(const app.ElectroSimApp());
    await _capture(tester, '01_flutter_home_desktop.png');
  });

  testWidgets('capture F18 workspace desktop', (WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _setSurface(tester, const Size(1440, 900));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ElectroSimTheme.light(),
        home: const app.F18WorkspacePage(
          entryLabel: 'TP Commande Moteur',
          sessionNavigation: true,
          initialSelectedElementId: 'breaker-1',
        ),
      ),
    );
    await _capture(tester, '02_flutter_workspace_desktop.png');
  });

  testWidgets('capture F18 workspace compact', (WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ElectroSimTheme.light(),
        home: const app.F18WorkspacePage(
          entryLabel: 'TP Commande',
        ),
      ),
    );
    await _capture(tester, '03_flutter_workspace_compact.png');
  });

  testWidgets('capture F18 troubleshooting student', (WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _setSurface(tester, const Size(820, 1180));
    final ElectroSimTpSessionController controller =
        ElectroSimTpSessionController(
      tpIdValue: 'K7M4P2',
      title: 'TP 04 · Circuit d’éclairage 24 V',
    );
    controller.createDraft();
    controller.publish();
    controller.startStudent();

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ElectroSimTheme.light(),
        home: app.F18WorkspacePage(
          initialWorkspace: 'Recherche de dérangement',
          role: F9UserRole.student,
          tpSessionController: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final Finder diagnostic = find.byKey(const Key('diagnostic-tab'));
    if (diagnostic.evaluate().isNotEmpty) {
      await tester.tap(diagnostic);
    }
    await _capture(tester, '04_flutter_troubleshooting_student.png');
    controller.dispose();
  });

  testWidgets('capture G4-R1 component quality gallery',
      (WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _setSurface(tester, const Size(1440, 900));

    const List<(String, String)> components = <(String, String)>[
      ('Alimentation DC', 'dc_voltage_source'),
      ('Disjoncteur', 'breaker'),
      ('Interrupteur', 'switch'),
      ('Bouton-poussoir', 'push_button_no'),
      ('Lampe', 'lamp'),
      ('Multimètre', 'multimeter'),
      ('Résistance', 'resistor'),
      ('Fusible', 'fuse'),
      ('Buzzer', 'buzzer'),
      ('Diode', 'diode'),
      ('Moteur CC', 'motor_dc'),
      ('Ventilateur', 'fan_dc'),
      ('Relais', 'relay_coil'),
      ('Contacteur', 'contactor'),
      ('Onduleur', 'inverter'),
      ('Transformateur', 'transformer'),
      ('Module PV', 'pv_panel'),
      ('Batterie', 'battery_storage'),
      ('Régulateur', 'regulator'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ElectroSimTheme.light(),
        home: Scaffold(
          backgroundColor: const Color(0xFFF4F7FA),
          body: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'G4-R1 · Bibliothèque visuelle des composants',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF132033),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Chaque appareil possède une identité physique dédiée. Les archétypes génériques ne servent plus que de fallback.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF5A6D83),
                  ),
                ),
                const SizedBox(height: 26),
                Expanded(
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 18,
                      mainAxisSpacing: 18,
                      childAspectRatio: 1.55,
                    ),
                    itemCount: components.length,
                    itemBuilder: (BuildContext context, int index) {
                      final (String label, String model) = components[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: const Color(0xFFD7E0EA),
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            F18ComponentArchetypeGlyph(
                              modelType: model,
                              size: 76,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              label,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF132033),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await _capture(tester, '05_flutter_component_gallery.png');
  });
}
