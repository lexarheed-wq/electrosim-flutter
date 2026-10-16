import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim/electrical_project_workspace_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CircuitState _circuit(String id, ElectricalMode mode, List<ComponentInstance> components) => CircuitState(
  circuitId: CircuitId(id), revision: 0, mode: mode, components: components,
);
ComponentInstance _component(String id, String model, int terminalCount) => ComponentInstance(
  id: ComponentId(id), modelType: model,
  terminals: <Terminal>[for (int i = 0; i < terminalCount; i++) Terminal(id: TerminalId('$id-$i'), name: '$i')],
);

ElectricalProject _project() => ElectricalProject(networks: <ElectricalNetwork>[
  ElectricalNetwork(id: 'control', circuit: _circuit('dc', ElectricalMode.dc, <ComponentInstance>[
    _component('plc', 'plc_dc', 10), _component('coil', 'relay_coil', 2),
  ])),
  ElectricalNetwork(id: 'power', circuit: _circuit('ac3', ElectricalMode.ac3, <ComponentInstance>[
    _component('contact', 'contactor_aux_no', 2),
  ])),
]);

void main() {
  testWidgets('network selector shows separate DC and AC3 workspaces', (WidgetTester tester) async {
    ElectricalProject? changed;
    await tester.pumpWidget(MaterialApp(home: ElectricalProjectWorkspacePage(
      initialProject: _project(), onProjectChanged: (ElectricalProject p) => changed = p,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Commande 24 V CC'), findsOneWidget);
    expect(find.text('Puissance AC3'), findsOneWidget);
    expect(find.byKey(const Key('workspace-simulation-toggle')), findsNothing);
    await tester.tap(find.byKey(const Key('project-network-power')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('project-network-power')), findsOneWidget);
    expect(changed, isNull);
  });

  testWidgets('creates and removes an explicit PLC-to-relay bridge', (WidgetTester tester) async {
    ElectricalProject? changed;
    await tester.pumpWidget(MaterialApp(home: ElectricalProjectWorkspacePage(
      initialProject: _project(), onProjectChanged: (ElectricalProject p) => changed = p,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Liaisons PLC et relais'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('coil → contact'));
    await tester.pumpAndSettle();
    expect(changed!.relayLinks, hasLength(1));
    expect(changed!.relayLinks.single.outputAddress, 'Q0');
    await tester.tap(find.byTooltip('Liaisons PLC et relais'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Supprimer la liaison'));
    await tester.pumpAndSettle();
    expect(changed!.relayLinks, isEmpty);
  });

  testWidgets('shared clock start, pause and single step show project status', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: ElectricalProjectWorkspacePage(
      initialProject: _project(), onProjectChanged: (_) {},
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('project-simulation-toggle')));
    await tester.pump(const Duration(milliseconds: 260));
    expect(find.text('t = 0.25 s'), findsOneWidget);
    await tester.tap(find.byKey(const Key('project-simulation-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Pause'), findsNothing);
    await tester.tap(find.byTooltip('Un pas de 250 ms'));
    await tester.pumpAndSettle();
    expect(find.text('t = 0.50 s'), findsOneWidget);
  });
}
