import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
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
    _component('motor-contactor', 'contactor_3p', 8),
  ])),
]);

void main() {
  testWidgets('mixed board shows every network and selects the active palette domain', (WidgetTester tester) async {
    ElectricalProject? changed;
    await tester.pumpWidget(MaterialApp(home: ElectricalProjectWorkspacePage(
      initialProject: _project(), onProjectChanged: (ElectricalProject p) => changed = p,
    )));
    await tester.pumpAndSettle();
    expect(find.text('CC 24 V'), findsOneWidget);
    expect(find.text('AC triphasé'), findsOneWidget);
    expect(find.text('Simulateur — mode Mixte'), findsOneWidget);
    expect(find.byKey(const Key('workspace-simulation-toggle')), findsNothing);
    final SimulatorCanvas canvas = tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    expect(canvas.circuit.components.map((component) => component.id.value), containsAll(<String>[
      'n0--plc', 'n0--coil', 'n1--contact',
    ]));
    expect(canvas.circuit.mode, isNot(ElectricalMode.mixed));
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
    await tester.ensureVisible(find.text('coil → contact'));
    await tester.tap(find.text('coil → contact'));
    await tester.pumpAndSettle();
    expect(changed!.relayLinks, hasLength(1));
    expect(changed!.relayLinks.single.outputAddress, 'Q0');
    await tester.tap(find.byTooltip('Liaisons PLC et relais'));
    await tester.pumpAndSettle();
    final Finder removeLink = find.byTooltip('Supprimer la liaison');
    await tester.ensureVisible(removeLink);
    await tester.tap(removeLink);
    await tester.pumpAndSettle();
    expect(changed!.relayLinks, isEmpty);
  });

  testWidgets('links a PLC output directly to an AC3 power contactor', (WidgetTester tester) async {
    ElectricalProject? changed;
    await tester.pumpWidget(MaterialApp(home: ElectricalProjectWorkspacePage(
      initialProject: _project(), onProjectChanged: (ElectricalProject p) => changed = p,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Liaisons PLC et relais'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('plc → motor-contactor'));
    await tester.pumpAndSettle();

    expect(changed!.actuatorLinks, hasLength(1));
    expect(changed!.actuatorLinks.single.outputAddress, 'Q0');
    expect(changed!.actuatorLinks.single.targetNetworkId, 'power');
    expect(changed!.actuatorLinks.single.contactorId, 'motor-contactor');
  });

  testWidgets('links a PV inverter to an explicit AC1 line and neutral boundary', (WidgetTester tester) async {
    final ElectricalProject project = ElectricalProject(networks: <ElectricalNetwork>[
      ElectricalNetwork(id: 'solar', circuit: CircuitState(
        circuitId: CircuitId('solar'), revision: 0, mode: ElectricalMode.pv,
        components: <ComponentInstance>[ComponentInstance(
          id: ComponentId('inv'), modelType: 'pv_inverter',
          terminals: <Terminal>[
            Terminal(id: TerminalId('inv-dc-pos'), name: 'DC+'),
            Terminal(id: TerminalId('inv-dc-neg'), name: 'DC-'),
            Terminal(id: TerminalId('inv-line'), name: 'L', role: TerminalRole.line),
            Terminal(id: TerminalId('inv-neutral'), name: 'N', role: TerminalRole.neutral),
          ],
        )],
      )),
      ElectricalNetwork(id: 'ac1', circuit: CircuitState(
        circuitId: CircuitId('ac1'), revision: 0, mode: ElectricalMode.ac1,
        components: <ComponentInstance>[_component('load', 'resistor', 2)],
      )),
    ]);
    final ElectricalNetwork ac = project.networks.last;
    final ComponentInstance load = ac.circuit.components.single;
    final CircuitState acCircuit = CircuitState(
      circuitId: ac.circuit.circuitId, revision: 0, mode: ElectricalMode.ac1,
      components: <ComponentInstance>[ComponentInstance(
        id: load.id, modelType: load.modelType,
        terminals: <Terminal>[
          Terminal(id: TerminalId('load-line'), name: 'L', role: TerminalRole.line),
          Terminal(id: TerminalId('load-neutral'), name: 'N', role: TerminalRole.neutral),
        ],
      )],
    );
    final ElectricalProject converterProject = ElectricalProject(networks: <ElectricalNetwork>[
      project.networks.first,
      ElectricalNetwork(id: ac.id, circuit: acCircuit),
    ]);
    ElectricalProject? changed;
    await tester.pumpWidget(MaterialApp(home: ElectricalProjectWorkspacePage(
      initialProject: converterProject,
      onProjectChanged: (ElectricalProject value) => changed = value,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Liaisons PLC et relais'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('inv → ac1').first);
    await tester.pumpAndSettle();

    expect(changed!.converterLinks, hasLength(1));
    expect(changed!.converterLinks.single.outputLineTerminalId, 'load-line');
    expect(changed!.converterLinks.single.outputNeutralTerminalId, 'load-neutral');
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
