import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim/electrical_project_workspace_page.dart';
import 'package:electrosim/f18_industrial_physical_plate.dart';
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
  ElectricalNetwork(id: 'control', circuit: CircuitState(
    circuitId: CircuitId('dc'), revision: 0, mode: ElectricalMode.dc,
    components: <ComponentInstance>[
      ComponentInstance(id: ComponentId('plc'), modelType: 'plc_dc',
        terminals: <Terminal>[for (int i = 0; i < 10; i++) Terminal(id: TerminalId('plc-$i'), name: '$i')],
        parameters: const <String, Object?>{'ladderProgram': <Object?>[]}),
      _component('coil', 'relay_coil', 2),
    ],
    sources: <SourceInstance>[SourceInstance(
      id: SourceId('supply'), modelType: 'dc_voltage_source',
      terminals: <Terminal>[
        Terminal(id: TerminalId('supply-pos'), name: '+', phase: PhaseTag.dcPositive),
        Terminal(id: TerminalId('supply-neg'), name: '-', phase: PhaseTag.dcNegative),
      ], parameters: const <String, Object?>{'voltageV': 24.0},
    )],
    connections: <Connection>[
      Connection(id: ConnectionId('supply-to-plc-plus'), fromTerminalId: TerminalId('supply-pos'), toTerminalId: TerminalId('plc-0')),
      Connection(id: ConnectionId('supply-to-plc-minus'), fromTerminalId: TerminalId('supply-neg'), toTerminalId: TerminalId('plc-1')),
    ],
  )),
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
    final Finder relayBridge = find.text('coil → contact');
    await tester.scrollUntilVisible(
      relayBridge,
      200,
      scrollable: find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Scrollable),
      ).first,
    );
    await tester.tap(relayBridge);
    await tester.pumpAndSettle();
    expect(changed!.relayLinks, hasLength(1));
    expect(changed!.relayLinks.single.outputAddress, 'Q0');
    await tester.tap(find.byTooltip('Liaisons PLC et relais'));
    await tester.pumpAndSettle();
    final Finder removeLink = find.byTooltip('Supprimer la liaison');
    await tester.scrollUntilVisible(
      removeLink,
      200,
      scrollable: find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Scrollable),
      ).first,
    );
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

  testWidgets('CC source and PLC stay powered while the AC3 board runs', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1800, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    expect(await tester.runAsync(F18PhysicalPlateAssets.preload), isTrue);
    await tester.pumpWidget(MaterialApp(home: ElectricalProjectWorkspacePage(
      initialProject: _project(), onProjectChanged: (_) {},
    )));
    await tester.pumpAndSettle();
    // Selecting the AC3 network must not make the independently solved CC
    // supply and PLC disappear from the shared mixed board.
    await tester.tap(find.byKey(const Key('project-network-power')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('project-simulation-toggle')));
    await tester.pump(const Duration(milliseconds: 260));
    final Finder sourceVisual = find.byKey(
      const ValueKey<String>('board-v1-visual-n0--supply'),
    );
    expect(sourceVisual, findsOneWidget);
    final F18ComponentAssetVisual source =
        tester.widget<F18ComponentAssetVisual>(sourceVisual);
    expect(source.modelType, 'dc_voltage_source');
    expect(source.voltageV, closeTo(24.0, 1e-6));
    expect(
      find.bySemanticsLabel(
        RegExp(r'Automate programmable, automate alimenté'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('mixed board shows contactor resting state and closed NC contact before start', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1800, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    expect(await tester.runAsync(F18PhysicalPlateAssets.preload), isTrue);
    await tester.pumpWidget(MaterialApp(home: ElectricalProjectWorkspacePage(
      initialProject: _project(), onProjectChanged: (_) {},
    )));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp(r'Contact auxiliaire normalement ouvert'), skipOffstage: false), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Contacteur triphasé'), skipOffstage: false), findsOneWidget);
    semantics.dispose();
  });
}
