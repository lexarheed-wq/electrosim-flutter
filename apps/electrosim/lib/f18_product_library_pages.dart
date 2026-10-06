import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_scenarios/electrosim_scenarios.dart';
import 'package:flutter/material.dart';

class F18SchemaLibraryPage extends StatefulWidget {
  const F18SchemaLibraryPage({
    super.key,
    required this.library,
    required this.onOpen,
  });

  final V2ProductLibrary library;
  final ValueChanged<ExampleDefinition> onOpen;

  @override
  State<F18SchemaLibraryPage> createState() => _F18SchemaLibraryPageState();
}

class _F18SchemaLibraryPageState extends State<F18SchemaLibraryPage> {
  final TextEditingController _search = TextEditingController();
  ElectricalMode? _mode;

  @override
  Widget build(BuildContext context) {
    final String query = _search.text.trim().toLowerCase();
    final List<ExampleDefinition> visible = widget.library.schemas
        .where(
          (ExampleDefinition item) =>
              (_mode == null || item.circuit.mode == _mode) &&
              (query.isEmpty ||
                  item.title.toLowerCase().contains(query) ||
                  item.description.toLowerCase().contains(query) ||
                  item.id.value.toLowerCase().contains(query)),
        )
        .toList(growable: false);

    return _LibraryScaffold(
      key: const Key('schema-library-page'),
      title: 'Bibliothèque de schémas',
      subtitle:
          'Schémas sains V2 validés — version ${widget.library.version}',
      searchKey: const Key('schema-library-search'),
      searchController: _search,
      searchHint: 'Rechercher un schéma',
      selectedMode: _mode,
      onSearchChanged: (_) => setState(() {}),
      onModeChanged: (ElectricalMode? value) => setState(() => _mode = value),
      emptyMessage: 'Aucun schéma ne correspond aux filtres.',
      children: visible
          .map(
            (ExampleDefinition item) => _ProductLibraryCard(
              key: Key('schema-card-${item.id.value}'),
              previewKey: Key('schema-preview-${item.id.value}'),
              title: item.title,
              description: item.description,
              circuit: item.circuit,
              badges: <String>[
                _modeLabel(item.circuit.mode),
                'Schéma sain',
                'V2 natif',
              ],
              actionKey: Key('schema-open-${item.id.value}'),
              actionLabel: 'Ouvrir dans le simulateur',
              onPressed: () => widget.onOpen(item),
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }
}

class F18FaultLibraryPage extends StatefulWidget {
  const F18FaultLibraryPage({
    super.key,
    required this.library,
    required this.onLaunch,
  });

  final V2ProductLibrary library;
  final ValueChanged<FaultScenarioDefinition> onLaunch;

  @override
  State<F18FaultLibraryPage> createState() => _F18FaultLibraryPageState();
}

class _F18FaultLibraryPageState extends State<F18FaultLibraryPage> {
  final TextEditingController _search = TextEditingController();
  ElectricalMode? _mode;

  @override
  Widget build(BuildContext context) {
    final String query = _search.text.trim().toLowerCase();
    final List<FaultScenarioDefinition> visible = widget.library.faultScenarios
        .where(
          (FaultScenarioDefinition item) =>
              (_mode == null || item.faultyCircuit.mode == _mode) &&
              (query.isEmpty ||
                  item.title.toLowerCase().contains(query) ||
                  item.studentBrief.toLowerCase().contains(query) ||
                  item.id.value.toLowerCase().contains(query)),
        )
        .toList(growable: false);

    return _LibraryScaffold(
      key: const Key('fault-library-page'),
      title: 'Bibliothèque de pannes',
      subtitle:
          'Circuits défectueux autonomes V2 — version ${widget.library.version}',
      searchKey: const Key('fault-library-search'),
      searchController: _search,
      searchHint: 'Rechercher une panne',
      selectedMode: _mode,
      onSearchChanged: (_) => setState(() {}),
      onModeChanged: (ElectricalMode? value) => setState(() => _mode = value),
      emptyMessage: 'Aucune panne ne correspond aux filtres.',
      children: visible
          .map(
            (FaultScenarioDefinition item) => _ProductLibraryCard(
              key: Key('fault-card-${item.id.value}'),
              previewKey: Key('fault-preview-${item.id.value}'),
              title: item.title,
              description: item.studentBrief,
              circuit: item.faultyCircuit,
              badges: <String>[
                _modeLabel(item.faultyCircuit.mode),
                _difficultyLabel(item.difficulty),
                '${item.estimatedDurationMinutes} min',
                'V2 natif',
              ],
              actionKey: Key('fault-launch-${item.id.value}'),
              actionLabel: 'Lancer la recherche de dérangement',
              onPressed: () => widget.onLaunch(item),
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }
}

class _LibraryScaffold extends StatelessWidget {
  const _LibraryScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.searchKey,
    required this.searchController,
    required this.searchHint,
    required this.selectedMode,
    required this.onSearchChanged,
    required this.onModeChanged,
    required this.emptyMessage,
    required this.children,
  });

  final String title;
  final String subtitle;
  final Key searchKey;
  final TextEditingController searchController;
  final String searchHint;
  final ElectricalMode? selectedMode;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ElectricalMode?> onModeChanged;
  final String emptyMessage;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title), scrolledUnderElevation: 0),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double width = constraints.maxWidth;
            final int columns = width >= 1180
                ? 3
                : width >= 720
                ? 2
                : 1;
            final double horizontalPadding = width < 520 ? 16 : 24;
            return CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      20,
                      horizontalPadding,
                      12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          subtitle,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          key: searchKey,
                          controller: searchController,
                          onChanged: onSearchChanged,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: searchHint,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          key: const Key('library-mode-filters'),
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            FilterChip(
                              key: const Key('library-filter-all'),
                              label: const Text('Tous'),
                              selected: selectedMode == null,
                              onSelected: (_) => onModeChanged(null),
                            ),
                            for (final ElectricalMode mode
                                in ElectricalMode.values)
                              FilterChip(
                                key: Key('library-filter-${mode.name}'),
                                label: Text(_modeLabel(mode)),
                                selected: selectedMode == mode,
                                onSelected: (_) => onModeChanged(mode),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (children.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          emptyMessage,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      8,
                      horizontalPadding,
                      28,
                    ),
                    sliver: SliverGrid(
                      delegate: SliverChildListDelegate(children),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: columns == 1 ? 1.22 : 1.08,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProductLibraryCard extends StatelessWidget {
  const _ProductLibraryCard({
    super.key,
    required this.previewKey,
    required this.title,
    required this.description,
    required this.circuit,
    required this.badges,
    required this.actionKey,
    required this.actionLabel,
    required this.onPressed,
  });

  final Key previewKey;
  final String title;
  final String description;
  final CircuitState circuit;
  final List<String> badges;
  final Key actionKey;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _CircuitPreview(key: previewKey, circuit: circuit),
            const SizedBox(height: 14),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: badges
                  .map(
                    (String badge) => Chip(
                      label: Text(badge),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                description,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: actionKey,
                onPressed: onPressed,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircuitPreview extends StatelessWidget {
  const _CircuitPreview({super.key, required this.circuit});

  final CircuitState circuit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ComponentInstance? receiver = circuit.components.isEmpty
        ? null
        : circuit.components.first;
    return Semantics(
      label:
          'Aperçu du circuit : ${circuit.sources.length} source, '
          '${circuit.components.length} composant, '
          '${circuit.connections.length} liaison',
      child: Container(
        height: 116,
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Column(
          children: <Widget>[
            Expanded(
              child: Row(
                children: <Widget>[
                  _PreviewNode(
                    icon: Icons.battery_charging_full_rounded,
                    label: circuit.sources.isEmpty ? 'Source' : 'Source CC',
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _PreviewLink(
                        connected: circuit.connections.length >= 2,
                      ),
                    ),
                  ),
                  _PreviewNode(
                    icon: _componentIcon(receiver?.modelType),
                    label: _componentLabel(receiver?.modelType),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${circuit.sources.length} source · '
              '${circuit.components.length} récepteur · '
              '${circuit.connections.length} liaison'
              '${circuit.connections.length == 1 ? '' : 's'}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewNode extends StatelessWidget {
  const _PreviewNode({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 76,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(icon, size: 30),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    ),
  );
}

class _PreviewLink extends StatelessWidget {
  const _PreviewLink({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.outline;
    return SizedBox(
      height: 34,
      child: CustomPaint(
        painter: _PreviewLinkPainter(color: color, connected: connected),
      ),
    );
  }
}

class _PreviewLinkPainter extends CustomPainter {
  const _PreviewLinkPainter({required this.color, required this.connected});

  final Color color;
  final bool connected;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double top = size.height * .28;
    final double bottom = size.height * .72;
    final Path upper = Path()
      ..moveTo(0, top)
      ..lineTo(size.width, top);
    final Path lower = Path()
      ..moveTo(0, bottom)
      ..lineTo(connected ? size.width : size.width * .58, bottom);
    canvas.drawPath(upper, paint);
    canvas.drawPath(lower, paint);

    if (!connected) {
      final double x = size.width * .72;
      canvas.drawLine(
        Offset(x - 4, bottom - 5),
        Offset(x + 4, bottom + 5),
        paint,
      );
      canvas.drawLine(
        Offset(x - 4, bottom + 5),
        Offset(x + 4, bottom - 5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PreviewLinkPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.connected != connected;
}

IconData _componentIcon(String? modelType) => switch (modelType) {
  'lamp' => Icons.lightbulb_outline_rounded,
  'motor_dc' => Icons.settings_rounded,
  _ => Icons.electrical_services_rounded,
};

String _componentLabel(String? modelType) => switch (modelType) {
  'lamp' => 'Voyant',
  'motor_dc' => 'Moteur CC',
  _ => 'Récepteur',
};

String _modeLabel(ElectricalMode mode) => switch (mode) {
  ElectricalMode.dc => 'CC',
  ElectricalMode.ac1 => 'AC1',
  ElectricalMode.ac3 => 'AC3',
  ElectricalMode.pv => 'PV',
};

String _difficultyLabel(FaultDifficulty difficulty) => switch (difficulty) {
  FaultDifficulty.basic => 'Débutant',
  FaultDifficulty.intermediate => 'Intermédiaire',
  FaultDifficulty.advanced => 'Avancé',
};
