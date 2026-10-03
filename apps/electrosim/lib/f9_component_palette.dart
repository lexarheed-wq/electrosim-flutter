import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';

import 'f18_component_archetypes.dart';

enum F9PaletteElementKind { source, component }

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
    this.subtitle,
  });

  final String keyName;
  final String title;
  final String category;
  final String modelType;
  final IconData icon;
  final F9PaletteElementKind kind;
  final List<String> terminalLabels;
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
            Wrap(
              spacing: ElectroSimSpacing.xs,
              runSpacing: ElectroSimSpacing.xs,
              children: <Widget>[
                for (final String category in _categories)
                  ChoiceChip(
                    key: Key('palette-category-${_slug(category)}'),
                    label: Text(category),
                    selected: _category == category,
                    onSelected: (_) => setState(() {
                      _category = category;
                      _expanded = false;
                    }),
                  ),
              ],
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

  static String _slug(String input) => input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
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
      color: ElectroSimColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ElectroSimRadii.card),
        side: const BorderSide(color: ElectroSimColors.outline),
      ),
      child: InkWell(
        key: Key('palette-item-${definition.keyName}'),
        borderRadius: BorderRadius.circular(ElectroSimRadii.card),
        onTap: () => onStatus(
          'Palette : ${definition.title} sélectionné — glissez-le sur la platine ou utilisez +.',
        ),
        child: Padding(
          padding: const EdgeInsets.all(ElectroSimSpacing.sm),
          child: Row(
            children: <Widget>[
              F9ComponentPreview(definition: definition, compact: true),
              const SizedBox(width: ElectroSimSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(definition.title, style: Theme.of(context).textTheme.labelLarge),
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
          opacity: 0.92,
          child: SizedBox(
            width: 210,
            child: Card(
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(ElectroSimSpacing.sm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    F9ComponentPreview(definition: definition, compact: true),
                    const SizedBox(width: ElectroSimSpacing.sm),
                    Flexible(child: Text(definition.title)),
                  ],
                ),
              ),
            ),
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
    final double width = compact ? 72 : 112;
    final double height = compact ? 48 : 72;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            left: 5,
            right: 5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: definition.kind == F9PaletteElementKind.source
                    ? const Color(0xFFEFF6FF)
                    : Colors.white,
                borderRadius: BorderRadius.circular(compact ? 8 : 10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Center(
                child: F18ComponentArchetypeGlyph(
                  modelType: definition.modelType,
                  size: compact ? 26 : 38,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: height / 2 - 5,
            child: const _TerminalDot(),
          ),
          Positioned(
            right: 0,
            top: height / 2 - 5,
            child: const _TerminalDot(),
          ),
        ],
      ),
    );
  }
}

class _TerminalDot extends StatelessWidget {
  const _TerminalDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF0F172A), width: 1.5),
      ),
    );
  }
}
