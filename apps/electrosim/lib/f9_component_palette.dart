import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';

import 'f18_component_archetypes.dart';
import 'f18_component_asset_visual.dart';

enum F9PaletteElementKind { source, component }

@immutable
class F9PaletteTerminalSpec {
  const F9PaletteTerminalSpec(
    this.label, {
    this.role = TerminalRole.generic,
    this.phase = PhaseTag.none,
    this.idSuffix,
  });

  final String label;
  final TerminalRole role;
  final PhaseTag phase;
  final String? idSuffix;
}

@immutable
class F9PaletteDefinition {
  const F9PaletteDefinition({
    required this.keyName,
    required this.title,
    required this.category,
    required this.modelType,
    required this.icon,
    required this.kind,
    required this.terminalLabels,
    this.terminals = const <F9PaletteTerminalSpec>[],
    this.defaultParameters = const <String, Object?>{},
    this.defaultControlState = const <String, Object?>{},
    this.subtitle,
  });

  final String keyName;
  final String title;
  final String category;
  final String modelType;
  final IconData icon;
  final F9PaletteElementKind kind;
  final List<String> terminalLabels;
  final List<F9PaletteTerminalSpec> terminals;
  final Map<String, Object?> defaultParameters;
  final Map<String, Object?> defaultControlState;
  final String? subtitle;
}

const List<F9PaletteDefinition> f9PaletteCatalog = <F9PaletteDefinition>[
  F9PaletteDefinition(
    keyName: 'source-dc-24v',
    title: 'Source CC 24 V',
    category: 'Sources',
    modelType: 'dc_voltage_source',
    icon: Icons.battery_charging_full,
    kind: F9PaletteElementKind.source,
    terminalLabels: <String>['+', '−'],
    subtitle: '24 V CC',
  ),
  F9PaletteDefinition(
    keyName: 'switch-no',
    title: 'Interrupteur NO',
    category: 'Commande',
    modelType: 'switch',
    icon: Icons.toggle_on_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['1', '2'],
    subtitle: 'Contact 2 bornes',
  ),
  F9PaletteDefinition(
    keyName: 'lamp',
    title: 'Lampe',
    category: 'Récepteurs',
    modelType: 'lamp',
    icon: Icons.lightbulb_outline,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['A', 'B'],
    subtitle: 'Charge résistive',
  ),
  F9PaletteDefinition(
    keyName: 'resistor',
    title: 'Résistance',
    category: 'Passifs',
    modelType: 'resistor',
    icon: Icons.linear_scale,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['1', '2'],
    subtitle: '100 Ω',
  ),
  F9PaletteDefinition(
    keyName: 'breaker',
    title: 'Disjoncteur',
    category: 'Protection',
    modelType: 'breaker_dc',
    icon: Icons.electrical_services_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['IN', 'OUT'],
    subtitle: 'Protection 2 bornes',
  ),
  F9PaletteDefinition(
    keyName: 'push-button-no',
    title: 'Bouton-poussoir NO',
    category: 'Commande',
    modelType: 'push_button_no',
    icon: Icons.radio_button_checked,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['13', '14'],
    subtitle: 'Commande momentanée',
  ),
  F9PaletteDefinition(
    keyName: 'push-button-nc',
    title: 'Bouton-poussoir NC',
    category: 'Commande',
    modelType: 'push_button_nc',
    icon: Icons.radio_button_unchecked,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['21', '22'],
    subtitle: 'Arrêt momentanée NC',
  ),
  F9PaletteDefinition(
    keyName: 'buzzer',
    title: 'Buzzer',
    category: 'Récepteurs',
    modelType: 'buzzer',
    icon: Icons.volume_up_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['+', '−'],
    subtitle: 'Avertisseur CC',
  ),
  F9PaletteDefinition(
    keyName: 'fuse',
    title: 'Fusible',
    category: 'Protection',
    modelType: 'fuse_dc',
    icon: Icons.horizontal_rule,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['IN', 'OUT'],
    subtitle: 'Protection simple',
  ),
  F9PaletteDefinition(
    keyName: 'diode',
    title: 'Diode',
    category: 'Passifs',
    modelType: 'diode',
    icon: Icons.play_arrow_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['A', 'K'],
    subtitle: 'Semi-conducteur',
  ),
  F9PaletteDefinition(
    keyName: 'fan-dc',
    title: 'Ventilateur CC',
    category: 'Récepteurs',
    modelType: 'fan_dc',
    icon: Icons.air,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['+', '−'],
    subtitle: 'Actionneur rotatif',
  ),
  F9PaletteDefinition(
    keyName: 'motor-dc',
    title: 'Moteur CC',
    category: 'Récepteurs',
    modelType: 'motor_dc',
    icon: Icons.settings_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['+', '−'],
    subtitle: 'Charge électromécanique',
  ),
  F9PaletteDefinition(
    keyName: 'relay-coil',
    title: 'Bobine relais',
    category: 'Commande',
    modelType: 'relay_coil',
    icon: Icons.sync_alt,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['A1', 'A2'],
    subtitle: 'Commande électromagnétique',
  ),

  // C14 Wave 1 — canonical models already supported by the V2 electrical core.
  F9PaletteDefinition(
    keyName: 'capacitor',
    title: 'Condensateur',
    category: 'Passifs',
    modelType: 'capacitor',
    icon: Icons.view_column_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['1', '2'],
    defaultParameters: <String, Object?>{'capacitanceF': 0.0001},
    subtitle: '100 µF — AC1/AC3',
  ),
  F9PaletteDefinition(
    keyName: 'inductor',
    title: 'Inductance',
    category: 'Passifs',
    modelType: 'inductor',
    icon: Icons.waves_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['1', '2'],
    defaultParameters: <String, Object?>{'inductanceH': 0.1},
    subtitle: '100 mH — AC1/AC3',
  ),
  F9PaletteDefinition(
    keyName: 'impedance',
    title: 'Impédance',
    category: 'Passifs',
    modelType: 'impedance',
    icon: Icons.show_chart,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['1', '2'],
    defaultParameters: <String, Object?>{
      'resistanceOhm': 20.0,
      'reactanceOhm': 10.0,
    },
    subtitle: 'R + jX — AC1/AC3',
  ),
  F9PaletteDefinition(
    keyName: 'breaker-ac1',
    title: 'Disjoncteur AC 1φ',
    category: 'Protection',
    modelType: 'breaker_ac1',
    icon: Icons.electrical_services_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['L', 'T'],
    defaultParameters: <String, Object?>{'ratedCurrentA': 10.0},
    defaultControlState: <String, Object?>{'closed': true, 'tripped': false},
    subtitle: 'Protection monophasée',
  ),
  F9PaletteDefinition(
    keyName: 'fuse-ac1',
    title: 'Fusible AC 1φ',
    category: 'Protection',
    modelType: 'fuse_ac1',
    icon: Icons.horizontal_rule,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['L', 'T'],
    defaultParameters: <String, Object?>{'ratedCurrentA': 10.0},
    defaultControlState: <String, Object?>{'closed': true, 'tripped': false},
    subtitle: 'Fusible monophasé',
  ),
  F9PaletteDefinition(
    keyName: 'aux-contact-no',
    title: 'Contact auxiliaire NO',
    category: 'Commande',
    modelType: 'contactor_aux_no',
    icon: Icons.call_split_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['13', '14'],
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        '13',
        role: TerminalRole.auxiliaryNormallyOpen,
        idSuffix: '13',
      ),
      F9PaletteTerminalSpec(
        '14',
        role: TerminalRole.auxiliaryNormallyOpen,
        idSuffix: '14',
      ),
    ],
    defaultControlState: <String, Object?>{'actuated': false},
    subtitle: 'Contact lié au contacteur',
  ),
  F9PaletteDefinition(
    keyName: 'aux-contact-nc',
    title: 'Contact auxiliaire NC',
    category: 'Commande',
    modelType: 'contactor_aux_nc',
    icon: Icons.call_merge_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['21', '22'],
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        '21',
        role: TerminalRole.auxiliaryNormallyClosed,
        idSuffix: '21',
      ),
      F9PaletteTerminalSpec(
        '22',
        role: TerminalRole.auxiliaryNormallyClosed,
        idSuffix: '22',
      ),
    ],
    defaultControlState: <String, Object?>{'actuated': false},
    subtitle: 'Contact lié au contacteur',
  ),
  F9PaletteDefinition(
    keyName: 'contactor-ac1',
    title: 'Contacteur AC 1φ',
    category: 'Commande',
    modelType: 'contactor_ac1',
    icon: Icons.hub_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['1L1', '2T1', 'A1', 'A2'],
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        '1L1',
        role: TerminalRole.lineL1,
        phase: PhaseTag.l1,
        idSuffix: '1l1',
      ),
      F9PaletteTerminalSpec(
        '2T1',
        role: TerminalRole.loadT1,
        phase: PhaseTag.l1,
        idSuffix: '2t1',
      ),
      F9PaletteTerminalSpec(
        'A1',
        role: TerminalRole.coilA1,
        phase: PhaseTag.l1,
        idSuffix: 'a1',
      ),
      F9PaletteTerminalSpec(
        'A2',
        role: TerminalRole.coilA2,
        phase: PhaseTag.neutral,
        idSuffix: 'a2',
      ),
    ],
    defaultParameters: <String, Object?>{
      'coilResistanceOhm': 1000.0,
      'coilInductanceH': 0.0,
      'coilPickupVoltageV': 180.0,
      'coilDropoutVoltageV': 100.0,
    },
    defaultControlState: <String, Object?>{'actuated': false},
    subtitle: 'Puissance + bobine A1/A2',
  ),
  F9PaletteDefinition(
    keyName: 'contactor-3p',
    title: 'Contacteur 3P',
    category: 'Triphasé',
    modelType: 'contactor_3p',
    icon: Icons.hub,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>[
      '1L1',
      '3L2',
      '5L3',
      '2T1',
      '4T2',
      '6T3',
      'A1',
      'A2',
    ],
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        '1L1',
        role: TerminalRole.lineL1,
        phase: PhaseTag.l1,
        idSuffix: '1l1',
      ),
      F9PaletteTerminalSpec(
        '3L2',
        role: TerminalRole.lineL2,
        phase: PhaseTag.l2,
        idSuffix: '3l2',
      ),
      F9PaletteTerminalSpec(
        '5L3',
        role: TerminalRole.lineL3,
        phase: PhaseTag.l3,
        idSuffix: '5l3',
      ),
      F9PaletteTerminalSpec(
        '2T1',
        role: TerminalRole.loadT1,
        phase: PhaseTag.l1,
        idSuffix: '2t1',
      ),
      F9PaletteTerminalSpec(
        '4T2',
        role: TerminalRole.loadT2,
        phase: PhaseTag.l2,
        idSuffix: '4t2',
      ),
      F9PaletteTerminalSpec(
        '6T3',
        role: TerminalRole.loadT3,
        phase: PhaseTag.l3,
        idSuffix: '6t3',
      ),
      F9PaletteTerminalSpec(
        'A1',
        role: TerminalRole.coilA1,
        phase: PhaseTag.l1,
        idSuffix: 'a1',
      ),
      F9PaletteTerminalSpec(
        'A2',
        role: TerminalRole.coilA2,
        phase: PhaseTag.neutral,
        idSuffix: 'a2',
      ),
    ],
    defaultParameters: <String, Object?>{
      'coilResistanceOhm': 1000.0,
      'coilInductanceH': 0.0,
      'coilPickupVoltageV': 180.0,
      'coilDropoutVoltageV': 100.0,
    },
    defaultControlState: <String, Object?>{'actuated': false},
    subtitle: '3 pôles + bobine A1/A2',
  ),
  F9PaletteDefinition(
    keyName: 'breaker-3p',
    title: 'Disjoncteur 3P',
    category: 'Triphasé',
    modelType: 'breaker_3p',
    icon: Icons.electrical_services,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>[
      '1L1',
      '3L2',
      '5L3',
      '2T1',
      '4T2',
      '6T3',
    ],
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        '1L1',
        role: TerminalRole.lineL1,
        phase: PhaseTag.l1,
        idSuffix: '1l1',
      ),
      F9PaletteTerminalSpec(
        '3L2',
        role: TerminalRole.lineL2,
        phase: PhaseTag.l2,
        idSuffix: '3l2',
      ),
      F9PaletteTerminalSpec(
        '5L3',
        role: TerminalRole.lineL3,
        phase: PhaseTag.l3,
        idSuffix: '5l3',
      ),
      F9PaletteTerminalSpec(
        '2T1',
        role: TerminalRole.loadT1,
        phase: PhaseTag.l1,
        idSuffix: '2t1',
      ),
      F9PaletteTerminalSpec(
        '4T2',
        role: TerminalRole.loadT2,
        phase: PhaseTag.l2,
        idSuffix: '4t2',
      ),
      F9PaletteTerminalSpec(
        '6T3',
        role: TerminalRole.loadT3,
        phase: PhaseTag.l3,
        idSuffix: '6t3',
      ),
    ],
    defaultParameters: <String, Object?>{'ratedCurrentA': 10.0},
    defaultControlState: <String, Object?>{'closed': true, 'tripped': false},
    subtitle: 'Protection triphasée',
  ),
  F9PaletteDefinition(
    keyName: 'thermal-overload-3p',
    title: 'Relais thermique 3P',
    category: 'Triphasé',
    modelType: 'thermal_overload_3p',
    icon: Icons.device_thermostat_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>[
      '1L1',
      '3L2',
      '5L3',
      '2T1',
      '4T2',
      '6T3',
    ],
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        '1L1',
        role: TerminalRole.lineL1,
        phase: PhaseTag.l1,
        idSuffix: '1l1',
      ),
      F9PaletteTerminalSpec(
        '3L2',
        role: TerminalRole.lineL2,
        phase: PhaseTag.l2,
        idSuffix: '3l2',
      ),
      F9PaletteTerminalSpec(
        '5L3',
        role: TerminalRole.lineL3,
        phase: PhaseTag.l3,
        idSuffix: '5l3',
      ),
      F9PaletteTerminalSpec(
        '2T1',
        role: TerminalRole.loadT1,
        phase: PhaseTag.l1,
        idSuffix: '2t1',
      ),
      F9PaletteTerminalSpec(
        '4T2',
        role: TerminalRole.loadT2,
        phase: PhaseTag.l2,
        idSuffix: '4t2',
      ),
      F9PaletteTerminalSpec(
        '6T3',
        role: TerminalRole.loadT3,
        phase: PhaseTag.l3,
        idSuffix: '6t3',
      ),
    ],
    defaultParameters: <String, Object?>{'ratedCurrentA': 5.0},
    defaultControlState: <String, Object?>{'closed': true, 'tripped': false},
    subtitle: 'Surcharge moteur 3φ',
  ),
];

class F9ComponentPalette extends StatefulWidget {
  const F9ComponentPalette({
    super.key,
    required this.onStatus,
    required this.onQuickAdd,
  });

  final ValueChanged<String> onStatus;
  final ValueChanged<F9PaletteDefinition> onQuickAdd;

  @override
  State<F9ComponentPalette> createState() => _F9ComponentPaletteState();
}

class _F9ComponentPaletteState extends State<F9ComponentPalette> {
  static const int _collapsedLimit = 5;

  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _category = 'Tous';
  bool _expanded = false;

  List<String> get _categories => <String>{
    'Tous',
    ...f9PaletteCatalog.map((F9PaletteDefinition item) => item.category),
  }.toList(growable: false);

  List<F9PaletteDefinition> get _filtered {
    final String q = _query.trim().toLowerCase();
    return f9PaletteCatalog.where((F9PaletteDefinition item) {
      final bool categoryMatches = _category == 'Tous' || item.category == _category;
      final bool queryMatches = q.isEmpty ||
          item.title.toLowerCase().contains(q) ||
          item.category.toLowerCase().contains(q) ||
          item.modelType.toLowerCase().contains(q);
      return categoryMatches && queryMatches;
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final List<F9PaletteDefinition> filtered = _filtered;
    final bool canExpand = filtered.length > _collapsedLimit;
    final List<F9PaletteDefinition> visible = !_expanded && canExpand
        ? filtered.take(_collapsedLimit).toList(growable: false)
        : filtered;

    return ColoredBox(
      color: ElectroSimColors.surfaceElevated,
      child: Padding(
        padding: const EdgeInsets.all(ElectroSimSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const ElectroSimSectionTitle(
              title: 'Composants',
              subtitle: 'Recherchez puis ajoutez un composant à la platine',
            ),
            const SizedBox(height: ElectroSimSpacing.md),
            TextField(
              key: const Key('palette-search-field'),
              controller: _searchController,
              onChanged: (String value) => setState(() {
                _query = value;
                _expanded = true;
              }),
              decoration: InputDecoration(
                hintText: 'Rechercher un composant',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        key: const Key('palette-clear-search'),
                        tooltip: 'Effacer la recherche',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _query = '';
                            _expanded = false;
                          });
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: ElectroSimSpacing.sm),
            DropdownButtonFormField<String>(
              key: const Key('palette-category-selector'),
              initialValue: _category,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Catégorie',
                isDense: true,
              ),
              items: <DropdownMenuItem<String>>[
                for (final String category in _categories)
                  DropdownMenuItem<String>(
                    value: category,
                    child: Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (String? category) {
                if (category == null) {
                  return;
                }
                setState(() {
                  _category = category;
                  _expanded = false;
                });
              },
            ),
            const SizedBox(height: ElectroSimSpacing.md),
            Expanded(
              child: visible.isEmpty
                  ? const Center(child: Text('Aucun composant correspondant.'))
                  : ListView.builder(
                      key: const Key('palette-results-list'),
                      clipBehavior: Clip.hardEdge,
                      padding: const EdgeInsets.only(bottom: ElectroSimSpacing.md),
                      itemCount: visible.length,
                      itemBuilder: (BuildContext context, int index) {
                        final F9PaletteDefinition item = visible[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: ElectroSimSpacing.sm),
                          child: _PaletteDraggableTile(
                            definition: item,
                            onStatus: widget.onStatus,
                            onQuickAdd: widget.onQuickAdd,
                          ),
                        );
                      },
                    ),
            ),
            if (canExpand && !_expanded) ...<Widget>[
              const SizedBox(height: ElectroSimSpacing.xs),
              OutlinedButton.icon(
                key: const Key('palette-show-all'),
                onPressed: () => setState(() => _expanded = true),
                icon: const Icon(Icons.apps_outlined),
                label: const Text('Voir tous les composants'),
              ),
            ],
            const SizedBox(height: ElectroSimSpacing.xs),
            Text(
              '${filtered.length} composant${filtered.length > 1 ? 's' : ''} disponible${filtered.length > 1 ? 's' : ''}',
              key: const Key('palette-result-count'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ElectroSimColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

}

class _PaletteDraggableTile extends StatelessWidget {
  const _PaletteDraggableTile({
    required this.definition,
    required this.onStatus,
    required this.onQuickAdd,
  });

  final F9PaletteDefinition definition;
  final ValueChanged<String> onStatus;
  final ValueChanged<F9PaletteDefinition> onQuickAdd;

  @override
  Widget build(BuildContext context) {
    final Widget tile = Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('palette-item-${definition.keyName}'),
        borderRadius: BorderRadius.circular(ElectroSimRadii.card),
        onTap: () => onStatus(
          'Palette : ${definition.title} sélectionné — glissez-le sur la platine ou utilisez +.',
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ElectroSimSpacing.sm,
            vertical: ElectroSimSpacing.xs,
          ),
          child: Row(
            children: <Widget>[
              F9ComponentPreview(definition: definition, compact: true),
              const SizedBox(width: ElectroSimSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      definition.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      definition.subtitle ?? definition.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ElectroSimColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: Key('palette-quick-add-${definition.keyName}'),
                tooltip: 'Ajouter au centre de la platine',
                onPressed: () => onQuickAdd(definition),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: '${definition.title}, ${definition.category}',
      hint: 'Glisser sur la platine ou utiliser le bouton ajouter',
      child: Draggable<F9PaletteDefinition>(
      data: definition,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.94,
          child: F18ComponentAssetVisual(
            modelType: definition.modelType,
            size: F18ReferenceComponentVisuals.supports(definition.modelType)
                ? F18ReferenceComponentMetrics.dragSizeFor(definition.modelType)
                : F18ComponentIdentityMetrics.dragSize,
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: tile),
      onDragStarted: () => onStatus('Déplacement depuis la palette : ${definition.title}'),
      onDraggableCanceled: (_, __) => onStatus('Ajout annulé : ${definition.title}'),
      child: tile,
      ),
    );
  }
}

class F9ComponentPreview extends StatelessWidget {
  const F9ComponentPreview({
    super.key,
    required this.definition,
    this.compact = false,
  });

  final F9PaletteDefinition definition;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return F18ComponentAssetVisual(
      key: Key('component-identity-preview-${definition.keyName}'),
      modelType: definition.modelType,
      size: F18ReferenceComponentVisuals.supports(definition.modelType)
          ? (compact
              ? F18ReferenceComponentMetrics.paletteSizeFor(definition.modelType)
              : F18ReferenceComponentMetrics.dragSizeFor(definition.modelType))
          : (compact
              ? F18ComponentIdentityMetrics.paletteSize
              : F18ComponentIdentityMetrics.dragSize),
    );
  }
}
