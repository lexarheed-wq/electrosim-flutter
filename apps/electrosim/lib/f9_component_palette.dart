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
    title: 'Alimentation DC',
    category: 'Source',
    modelType: 'dc_voltage_source',
    icon: Icons.battery_charging_full,
    kind: F9PaletteElementKind.source,
    terminalLabels: <String>['+', '−'],
    subtitle: 'Source',
  ),
  F9PaletteDefinition(
    keyName: 'breaker',
    title: 'Disjoncteur',
    category: 'Protection',
    modelType: 'breaker',
    icon: Icons.electrical_services_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['1', '2'],
    subtitle: 'Protection',
  ),
  F9PaletteDefinition(
    keyName: 'switch-no',
    title: 'Interrupteur',
    category: 'Commande',
    modelType: 'switch',
    icon: Icons.toggle_on_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['1', '2'],
    subtitle: 'Commande',
  ),
  F9PaletteDefinition(
    keyName: 'lamp',
    title: 'Lampe',
    category: 'Charge',
    modelType: 'lamp',
    icon: Icons.lightbulb_outline,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['L', 'N'],
    subtitle: 'Charge',
  ),
  F9PaletteDefinition(
    keyName: 'multimeter',
    title: 'Multimètre',
    category: 'Mesure',
    modelType: 'multimeter',
    icon: Icons.speed_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['COM', 'VΩ'],
    subtitle: 'Mesure',
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
    category: 'Charge',
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
    modelType: 'fuse',
    icon: Icons.horizontal_rule,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['1', '2'],
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
    category: 'Charge',
    modelType: 'fan_dc',
    icon: Icons.air,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['+', '−'],
    subtitle: 'Actionneur rotatif',
  ),
  F9PaletteDefinition(
    keyName: 'motor-dc',
    title: 'Moteur CC',
    category: 'Machine',
    modelType: 'motor_dc',
    icon: Icons.settings_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['U1', 'W1'],
    subtitle: 'Machine',
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
  String _domain = 'CC';
  bool _expanded = false;

  List<F9PaletteDefinition> get _filtered {
    final String q = _query.trim().toLowerCase();
    return f9PaletteCatalog.where((F9PaletteDefinition item) {
      return q.isEmpty ||
          item.title.toLowerCase().contains(q) ||
          item.category.toLowerCase().contains(q) ||
          item.modelType.toLowerCase().contains(q);
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
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: 40,
              child: TextField(
                key: const Key('palette-search-field'),
                controller: _searchController,
                onChanged: (String value) => setState(() {
                  _query = value;
                  _expanded = value.trim().isNotEmpty;
                }),
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Rechercher',
                  prefixIcon: const Icon(Icons.search, size: 16),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
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
                          icon: const Icon(Icons.close, size: 16),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'COMPOSANTS',
                    style: TextStyle(
                      color: ElectroSimColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                if (canExpand && !_expanded)
                  TextButton(
                    key: const Key('palette-show-all'),
                    onPressed: () => setState(() => _expanded = true),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    child: const Text(
                      'Voir tous',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            if (!_expanded && _query.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Les plus utilisés',
                  style: TextStyle(
                    color: ElectroSimColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ),
            Expanded(
              child: visible.isEmpty
                  ? const Center(child: Text('Aucun composant correspondant.'))
                  : ListView.separated(
                      key: const Key('palette-results-list'),
                      clipBehavior: Clip.hardEdge,
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (BuildContext context, int index) {
                        final F9PaletteDefinition item = visible[index];
                        return _PaletteDraggableTile(
                          definition: item,
                          onStatus: widget.onStatus,
                          onQuickAdd: widget.onQuickAdd,
                        );
                      },
                    ),
            ),
            const Divider(height: 18),
            const Text(
              'DOMAINES',
              style: TextStyle(
                color: ElectroSimColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final String domain in const <String>['CC', 'AC1', 'AC3', 'PV'])
                  SizedBox(
                    width: 112,
                    height: 36,
                    child: ChoiceChip(
                      key: Key('palette-domain-${domain.toLowerCase()}'),
                      label: SizedBox(
                        width: double.infinity,
                        child: Text(
                          domain,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      selected: _domain == domain,
                      onSelected: (_) {
                        setState(() => _domain = domain);
                        widget.onStatus('Domaine de palette : $domain');
                      },
                    ),
                  ),
              ],
            ),
            Offstage(
              offstage: true,
              child: Text(
                '${filtered.length}',
                key: const Key('palette-result-count'),
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
        borderRadius: BorderRadius.circular(ElectroSimRadii.compact),
        onTap: () => onStatus(
          'Palette : ${definition.title} — glissez le composant sur la platine.',
        ),
        onDoubleTap: () => onQuickAdd(definition),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: <Widget>[
              F9ComponentPreview(definition: definition, compact: true),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      definition.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: ElectroSimColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      definition.subtitle ?? definition.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: ElectroSimColors.textSecondary,
                            fontSize: 10,
                          ),
                    ),
                  ],
                ),
              ),
              Offstage(
                offstage: true,
                child: IconButton(
                  key: Key('palette-quick-add-${definition.keyName}'),
                  onPressed: () => onQuickAdd(definition),
                  icon: const Icon(Icons.add),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: '${definition.title}, ${definition.category}',
      hint: 'Glisser sur la platine. Double clic pour ajout rapide.',
      child: Draggable<F9PaletteDefinition>(
        data: definition,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: Material(
          color: Colors.transparent,
          child: Opacity(
            opacity: 0.94,
            child: Container(
              width: 210,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ElectroSimColors.surfaceElevated,
                border: Border.all(color: const Color(0xFFD7E0EA)),
                borderRadius: BorderRadius.circular(ElectroSimRadii.compact),
                boxShadow: ElectroSimComponentTokens.cardElevation,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  F9ComponentPreview(definition: definition, compact: true),
                  const SizedBox(width: 10),
                  Flexible(child: Text(definition.title)),
                ],
              ),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: tile),
        onDragStarted: () =>
            onStatus('Déplacement depuis la palette : ${definition.title}'),
        onDraggableCanceled: (_, __) =>
            onStatus('Ajout annulé : ${definition.title}'),
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
    final double width = compact ? 68 : 112;
    final double height = compact ? 68 : 82;
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
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(compact ? 9 : 11),
                border: Border.all(color: const Color(0xFFC8D4E2)),
                boxShadow: compact
                    ? const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x120F172A),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: F18ComponentArchetypeGlyph(
                  modelType: definition.modelType,
                  size: compact ? 32 : 40,
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
