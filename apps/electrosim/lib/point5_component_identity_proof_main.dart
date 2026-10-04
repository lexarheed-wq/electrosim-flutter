import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';

import 'f18_component_asset_visual.dart';
import 'f18_component_archetypes.dart';
import 'f9_component_palette.dart';
import 'f9_component_visuals.dart';
import 'runtime/electrosim_simulation_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Point5V1ParityProofApp());
}

class _Point5V1ParityProofApp extends StatelessWidget {
  const _Point5V1ParityProofApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ElectroSimTheme.light(),
      home: const _Point5V1ParityProofPage(),
    );
  }
}

class _Point5V1ParityProofPage extends StatefulWidget {
  const _Point5V1ParityProofPage();

  @override
  State<_Point5V1ParityProofPage> createState() =>
      _Point5V1ParityProofPageState();
}

class _Point5V1ParityProofPageState extends State<_Point5V1ParityProofPage> {
  late final CircuitState _circuit = _buildPilotCircuit();
  late final CircuitVisualLayout _layout = _buildPilotLayout();
  final ViewportController _viewport = ViewportController();
  late final ElectroSimSimulationController _simulation =
      ElectroSimSimulationController(circuit: _circuit)
        ..addListener(_onSimulationChanged);

  static const List<String> _pilotKeys = <String>[
    'source-dc-24v',
    'switch-no',
    'lamp',
    'breaker',
    'push-button-no',
  ];

  @override
  void initState() {
    super.initState();
    _simulation.start();
  }

  void _onSimulationChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final List<F9PaletteDefinition> pilot = _pilotKeys
        .map(
          (String key) => f9PaletteCatalog.firstWhere(
            (F9PaletteDefinition item) => item.keyName == key,
          ),
        )
        .toList(growable: false);

    return Scaffold(
      backgroundColor: ElectroSimColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ElectroSimSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Point 5C — migration graphique V1 → Flutter',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '5 composants pilotes · bornes rapprochées · aucun cadre artificiel · courant animé piloté par le solveur',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  _ProofBadge(
                    text: _simulation.snapshot.solved
                        ? 'SOLVEUR : OK'
                        : 'SOLVEUR : EN ATTENTE',
                  ),
                  const SizedBox(width: 8),
                  _ProofBadge(
                    text:
                        't = ${(_simulation.simulatedTime.inMilliseconds / 1000).toStringAsFixed(1)} s',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 185,
                child: Row(
                  children: <Widget>[
                    for (var i = 0; i < pilot.length; i++) ...<Widget>[
                      Expanded(child: _PilotCard(definition: pilot[i])),
                      if (i != pilot.length - 1) const SizedBox(width: 10),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: ElectroSimColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(ElectroSimRadii.card),
                    border: Border.all(color: ElectroSimColors.outline),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(ElectroSimSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text(
                              'PREUVE EN SIMULATION RÉELLE',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const Spacer(),
                            const Text(
                              '24 V CC · 1 A · disjoncteur fermé · interrupteur fermé · BP NO pressé · lampe alimentée',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(ElectroSimRadii.card),
                            child: Stack(
                              fit: StackFit.expand,
                              children: <Widget>[
                                SimulatorCanvas(
                                  circuit: _circuit,
                                  layout: _layout,
                                  viewportController: _viewport,
                                  enableInteraction: false,
                                  paintElementChrome: false,
                                ),
                                F9CanvasVisualOverlay(
                                  circuit: _circuit,
                                  layout: _layout,
                                  viewport: _viewport,
                                  runtimeSnapshot: _simulation.snapshot,
                                  simulationRunning: _simulation.running,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _simulation.removeListener(_onSimulationChanged);
    _simulation.dispose();
    _viewport.dispose();
    super.dispose();
  }
}

class _ProofBadge extends StatelessWidget {
  const _ProofBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5EE),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF8CC8A4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF195C37),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _PilotCard extends StatelessWidget {
  const _PilotCard({required this.definition});

  final F9PaletteDefinition definition;

  @override
  Widget build(BuildContext context) {
    final String type = definition.modelType.toLowerCase();
    final bool source =
        type == 'dc_voltage_source' || type == 'voltage_source';
    final bool lamp = type == 'lamp';
    final bool breaker = type.startsWith('breaker');
    final bool push = type == 'push_button_no';
    final bool sw = type == 'switch' || type == 'switch_spst';

    return DecoratedBox(
      key: Key('point5-v1-pilot-${definition.keyName}'),
      decoration: BoxDecoration(
        color: ElectroSimColors.surfaceElevated,
        borderRadius: BorderRadius.circular(ElectroSimRadii.card),
        border: Border.all(color: ElectroSimColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: <Widget>[
            Text(
              definition.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            F18ComponentAssetVisual(
              modelType: definition.modelType,
              size: const Size(124, 76),
              energized: source || lamp,
              closed: breaker || sw,
              pressed: push,
              animationValue: .35,
            ),
            const Spacer(),
            Text(
              'V1 natif · sans image',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ElectroSimColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

CircuitState _buildPilotCircuit() {
  Terminal t(
    String id,
    String name, {
    TerminalRole role = TerminalRole.unspecified,
    PhaseTag phase = PhaseTag.none,
  }) =>
      Terminal(id: TerminalId(id), name: name, role: role, phase: phase);

  final Terminal sourcePos = t(
    'p5-source-pos',
    '+',
    role: TerminalRole.positive,
    phase: PhaseTag.dcPositive,
  );
  final Terminal sourceNeg = t(
    'p5-source-neg',
    '−',
    role: TerminalRole.negative,
    phase: PhaseTag.dcNegative,
  );
  final Terminal breakerA = t('p5-breaker-a', 'IN');
  final Terminal breakerB = t('p5-breaker-b', 'OUT');
  final Terminal switchA = t('p5-switch-a', '1');
  final Terminal switchB = t('p5-switch-b', '2');
  final Terminal pushA = t('p5-push-a', '13');
  final Terminal pushB = t('p5-push-b', '14');
  final Terminal lampA = t('p5-lamp-a', 'A');
  final Terminal lampB = t('p5-lamp-b', 'B');

  return CircuitState(
    circuitId: CircuitId('point5-v1-pilot'),
    revision: 1,
    mode: ElectricalMode.dc,
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('source-24v'),
        modelType: 'dc_voltage_source',
        terminals: <Terminal>[sourcePos, sourceNeg],
        parameters: const <String, Object?>{'voltageV': 24.0},
      ),
    ],
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId('breaker-1'),
        modelType: 'breaker_dc',
        terminals: <Terminal>[breakerA, breakerB],
        parameters: const <String, Object?>{
          'protectionRatedCurrentA': 10.0,
        },
        controlState: const <String, Object?>{
          'closed': true,
          'tripped': false,
        },
      ),
      ComponentInstance(
        id: ComponentId('switch-1'),
        modelType: 'switch',
        terminals: <Terminal>[switchA, switchB],
        controlState: const <String, Object?>{'closed': true},
      ),
      ComponentInstance(
        id: ComponentId('push-1'),
        modelType: 'push_button_no',
        terminals: <Terminal>[pushA, pushB],
        controlState: const <String, Object?>{'pressed': true},
      ),
      ComponentInstance(
        id: ComponentId('lamp-1'),
        modelType: 'lamp',
        terminals: <Terminal>[lampA, lampB],
        parameters: const <String, Object?>{'resistanceOhm': 24.0},
      ),
    ],
    connections: <Connection>[
      Connection(
        id: ConnectionId('wire-source-breaker'),
        fromTerminalId: sourcePos.id,
        toTerminalId: breakerB.id,
        phase: PhaseTag.dcPositive,
      ),
      Connection(
        id: ConnectionId('wire-breaker-switch'),
        fromTerminalId: breakerA.id,
        toTerminalId: switchB.id,
        phase: PhaseTag.dcPositive,
      ),
      Connection(
        id: ConnectionId('wire-switch-push'),
        fromTerminalId: switchA.id,
        toTerminalId: pushB.id,
        phase: PhaseTag.dcPositive,
      ),
      Connection(
        id: ConnectionId('wire-push-lamp'),
        fromTerminalId: pushA.id,
        toTerminalId: lampB.id,
        phase: PhaseTag.dcPositive,
      ),
      Connection(
        id: ConnectionId('wire-return'),
        fromTerminalId: lampA.id,
        toTerminalId: sourceNeg.id,
        phase: PhaseTag.dcNegative,
      ),
    ],
  );
}

CircuitVisualLayout _buildPilotLayout() {
  return CircuitVisualLayout(
    elementPositions: const <String, Offset>{
      'lamp-1': Offset(110, 112),
      'push-1': Offset(270, 112),
      'switch-1': Offset(430, 112),
      'breaker-1': Offset(590, 112),
      'source-24v': Offset(750, 112),
    },
    wireRoutes: const <String, List<Offset>>{
      'wire-return': <Offset>[
        Offset(58, 210),
        Offset(802, 210),
      ],
    },
  );
}
