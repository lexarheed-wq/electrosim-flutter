import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';

import 'f9_component_palette.dart';
import 'f9_component_visuals.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Point5IdentityProofApp());
}

class _Point5IdentityProofApp extends StatelessWidget {
  const _Point5IdentityProofApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ElectroSimTheme.light(),
      home: const _Point5IdentityProofPage(),
    );
  }
}

class _Point5IdentityProofPage extends StatelessWidget {
  const _Point5IdentityProofPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElectroSimColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ElectroSimSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Point 5 — même représentation partout',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: ElectroSimSpacing.xs),
              const Text(
                'Chaque carte compare le rendu utilisé dans la palette au rendu réel de la platine.',
              ),
              const SizedBox(height: ElectroSimSpacing.md),
              Expanded(
                child: GridView.builder(
                  key: const Key('point5-identity-grid'),
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.48,
                  ),
                  itemCount: f9PaletteCatalog.length,
                  itemBuilder: (BuildContext context, int index) {
                    return _IdentityPairCard(
                      definition: f9PaletteCatalog[index],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdentityPairCard extends StatelessWidget {
  const _IdentityPairCard({required this.definition});

  final F9PaletteDefinition definition;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: Key('point5-pair-${definition.keyName}'),
      decoration: BoxDecoration(
        color: ElectroSimColors.surfaceElevated,
        borderRadius: BorderRadius.circular(ElectroSimRadii.card),
        border: Border.all(color: ElectroSimColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ElectroSimSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              definition.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: ElectroSimSpacing.xs),
            Expanded(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        const Text('PALETTE'),
                        const Spacer(),
                        F9ComponentPreview(
                          definition: definition,
                          compact: true,
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    color: ElectroSimColors.outline,
                  ),
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        const Text('PLATINE'),
                        const Spacer(),
                        SizedBox(
                          width: 118,
                          height: 72,
                          child: _BoardIdentityPreview(
                            definition: definition,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardIdentityPreview extends StatefulWidget {
  const _BoardIdentityPreview({required this.definition});

  final F9PaletteDefinition definition;

  @override
  State<_BoardIdentityPreview> createState() =>
      _BoardIdentityPreviewState();
}

class _BoardIdentityPreviewState extends State<_BoardIdentityPreview> {
  late final ViewportController _viewport =
      ViewportController(translation: const Offset(0, 0));

  @override
  Widget build(BuildContext context) {
    final String id = 'proof-' + widget.definition.keyName;
    final List<Terminal> terminals = <Terminal>[
      Terminal(
        id: TerminalId(id + '-a'),
        name: widget.definition.terminalLabels.first,
      ),
      Terminal(
        id: TerminalId(id + '-b'),
        name: widget.definition.terminalLabels.length > 1
            ? widget.definition.terminalLabels[1]
            : '2',
      ),
    ];
    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('point5-' + widget.definition.keyName),
      revision: 0,
      mode: ElectricalMode.dc,
      sources: widget.definition.kind == F9PaletteElementKind.source
          ? <SourceInstance>[
              SourceInstance(
                id: SourceId(id),
                modelType: widget.definition.modelType,
                terminals: terminals,
              ),
            ]
          : const <SourceInstance>[],
      components: widget.definition.kind == F9PaletteElementKind.component
          ? <ComponentInstance>[
              ComponentInstance(
                id: ComponentId(id),
                modelType: widget.definition.modelType,
                terminals: terminals,
              ),
            ]
          : const <ComponentInstance>[],
    );
    final CircuitVisualLayout layout = CircuitVisualLayout(
      elementPositions: <String, Offset>{
        id: const Offset(59, 36),
      },
    );

    return ClipRect(
      child: F9CanvasVisualOverlay(
        circuit: circuit,
        layout: layout,
        viewport: _viewport,
      ),
    );
  }

  @override
  void dispose() {
    _viewport.dispose();
    super.dispose();
  }
}
