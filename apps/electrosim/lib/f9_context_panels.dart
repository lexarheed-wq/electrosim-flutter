import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';

import 'f9_element_editor.dart';
import 'f9_ui_context.dart';

class F9ContextPanels extends StatefulWidget {
  const F9ContextPanels({
    super.key,
    required this.circuit,
    required this.selectedId,
    required this.status,
    required this.workspace,
    required this.role,
    required this.onTogglePrimaryState,
    required this.onDeleteSelected,
    required this.onReplaceSelected,
    required this.onSelectElement,
  });

  final CircuitState circuit;
  final String? selectedId;
  final String status;
  final String workspace;
  final F9UserRole role;
  final VoidCallback? onTogglePrimaryState;
  final VoidCallback? onDeleteSelected;
  final VoidCallback? onReplaceSelected;
  final ValueChanged<String?> onSelectElement;

  bool get showDiagnostic => role == F9UserRole.student && workspace == 'Recherche de dérangement';

  @override
  State<F9ContextPanels> createState() => _F9ContextPanelsState();
}

class _F9ContextPanelsState extends State<F9ContextPanels> with TickerProviderStateMixin {
  late TabController _controller;

  int get _tabCount => widget.showDiagnostic ? 4 : 3;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: _tabCount, vsync: this);
  }

  @override
  void didUpdateWidget(covariant F9ContextPanels oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showDiagnostic != widget.showDiagnostic) {
      final int previousIndex = _controller.index.clamp(0, _tabCount - 1).toInt();
      _controller.dispose();
      _controller = TabController(length: _tabCount, vsync: this, initialIndex: previousIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: ElectroSimColors.surfaceElevated,
      child: Column(
        children: <Widget>[
          Material(
            color: ElectroSimColors.surfaceElevated,
            child: TabBar(
              controller: _controller,
              // Keep every contextual action directly reachable. In particular, the
              // student-only Diagnostic tab must not be pushed outside the 304 px
              // expanded context panel where a widget-test tap (and a real pointer)
              // cannot hit it without first scrolling the tab strip.
              isScrollable: false,
              tabs: <Widget>[
                const Tab(icon: Icon(Icons.tune_outlined), text: 'Propriétés'),
                const Tab(icon: Icon(Icons.straighten_outlined), text: 'Mesures'),
                const Tab(icon: Icon(Icons.psychology_alt_outlined), text: 'EIE'),
                if (widget.showDiagnostic)
                  const Tab(key: Key('diagnostic-tab'), icon: Icon(Icons.fact_check_outlined), text: 'Diagnostic'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _controller,
              children: <Widget>[
                _PropertiesPanel(
                  circuit: widget.circuit,
                  selectedId: widget.selectedId,
                  status: widget.status,
                  onTogglePrimaryState: widget.onTogglePrimaryState,
                  onDeleteSelected: widget.onDeleteSelected,
                  onReplaceSelected: widget.onReplaceSelected,
                  onSelectElement: widget.onSelectElement,
                ),
                const _MeasurementsPanel(),
                const _EiePanel(),
                if (widget.showDiagnostic) const _StudentDiagnosticPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _PropertiesPanel extends StatelessWidget {
  const _PropertiesPanel({
    required this.circuit,
    required this.selectedId,
    required this.status,
    required this.onTogglePrimaryState,
    required this.onDeleteSelected,
    required this.onReplaceSelected,
    required this.onSelectElement,
  });

  final CircuitState circuit;
  final String? selectedId;
  final String status;
  final VoidCallback? onTogglePrimaryState;
  final VoidCallback? onDeleteSelected;
  final VoidCallback? onReplaceSelected;
  final ValueChanged<String?> onSelectElement;

  @override
  Widget build(BuildContext context) {
    final F9ElementDetails? details = F9ElementEditor.describe(circuit, selectedId);
    final bool? primaryToggleValue = details?.primaryToggleValue;
    return ListView(
      key: const Key('properties-panel'),
      padding: const EdgeInsets.all(ElectroSimSpacing.md),
      children: <Widget>[
        const ElectroSimSectionTitle(title: 'Propriétés', subtitle: 'État UI séparé de l’état électrique'),
        const SizedBox(height: ElectroSimSpacing.md),
        InputDecorator(
          decoration: const InputDecoration(labelText: 'Sélection clavier'),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: const Key('properties-element-selector'),
              value: details?.id,
              isExpanded: true,
              hint: const Text('Choisir un élément'),
              items: <DropdownMenuItem<String>>[
                ...circuit.sources.map(
                  (SourceInstance source) => DropdownMenuItem<String>(value: source.id.value, child: Text('${source.modelType} · ${source.id.value}')),
                ),
                ...circuit.components.map(
                  (ComponentInstance component) => DropdownMenuItem<String>(value: component.id.value, child: Text('${component.modelType} · ${component.id.value}')),
                ),
              ],
              onChanged: onSelectElement,
            ),
          ),
        ),
        const SizedBox(height: ElectroSimSpacing.md),
        if (details == null) ...<Widget>[
          Text('Sélection', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: ElectroSimSpacing.xs),
          const Text('Aucun élément sélectionné'),
        ] else ...<Widget>[
          Text(details.modelType, key: const Key('properties-model-type'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: ElectroSimSpacing.xxs),
          Text(details.id, key: const Key('properties-element-id'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ElectroSimColors.textSecondary)),
          const SizedBox(height: ElectroSimSpacing.md),
          _PropertyLine(label: 'Type', value: details.kind == F9ElementKind.source ? 'Source' : 'Composant'),
          _PropertyLine(label: 'État', value: details.stateLabel),
          _PropertyLine(label: 'Bornes', value: details.terminalLabels.join(' · ')),
          if (details.parameters.isNotEmpty) ...<Widget>[
            const SizedBox(height: ElectroSimSpacing.sm),
            Text('Paramètres', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: ElectroSimSpacing.xs),
            ...details.parameters.entries.map(
              (MapEntry<String, Object?> entry) => _PropertyLine(label: entry.key, value: '${entry.value}'),
            ),
          ],
          if (primaryToggleValue != null) ...<Widget>[
            const SizedBox(height: ElectroSimSpacing.sm),
            SwitchListTile.adaptive(
              key: const Key('properties-primary-toggle'),
              contentPadding: EdgeInsets.zero,
              title: Text(details.primaryToggleLabel ?? 'État'),
              subtitle: const Text('Commande explicite du CircuitState'),
              value: primaryToggleValue,
              onChanged: onTogglePrimaryState == null ? null : (_) => onTogglePrimaryState!(),
            ),
          ],
          const SizedBox(height: ElectroSimSpacing.sm),
          if (details.kind == F9ElementKind.component)
            OutlinedButton.icon(
              key: const Key('properties-replace-element'),
              onPressed: onReplaceSelected,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Remplacer…'),
            ),
          const SizedBox(height: ElectroSimSpacing.xs),
          OutlinedButton.icon(
            key: const Key('properties-delete-element'),
            onPressed: onDeleteSelected,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Supprimer du circuit'),
          ),
        ],
        const SizedBox(height: ElectroSimSpacing.lg),
        Text('Activité', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: ElectroSimSpacing.xs),
        Semantics(
          liveRegion: true,
          label: 'État de l’activité',
          child: Text(
            status,
            key: const Key('context-status-message'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ElectroSimColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _MeasurementsPanel extends StatelessWidget {
  const _MeasurementsPanel();

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('measurements-panel'),
      padding: const EdgeInsets.all(ElectroSimSpacing.md),
      children: <Widget>[
        const ElectroSimSectionTitle(title: 'Mesures', subtitle: 'Aucune valeur n’est inventée par l’interface'),
        const SizedBox(height: ElectroSimSpacing.md),
        const ElectroSimStatusChip(label: 'En attente du moteur de mesure', icon: Icons.hourglass_empty),
        const SizedBox(height: ElectroSimSpacing.sm),
        Text(
          'F9 fournit le conteneur de présentation. Les tensions, courants et puissances seront affichés uniquement lorsqu’un résultat de mesure validé sera injecté.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _EiePanel extends StatelessWidget {
  const _EiePanel();

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('eie-panel'),
      padding: const EdgeInsets.all(ElectroSimSpacing.md),
      children: <Widget>[
        const ElectroSimSectionTitle(title: 'EIE', subtitle: 'Interface explicable, sans diagnostic spéculatif'),
        const SizedBox(height: ElectroSimSpacing.md),
        const ElectroSimStatusChip(label: 'Preuves moteur requises', icon: Icons.verified_outlined),
        const SizedBox(height: ElectroSimSpacing.sm),
        Text(
          'Le panneau reste volontairement neutre tant que les moteurs de topologie, de résolution et de diagnostic ne fournissent pas de preuves exploitables.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _StudentDiagnosticPanel extends StatefulWidget {
  const _StudentDiagnosticPanel();

  @override
  State<_StudentDiagnosticPanel> createState() => _StudentDiagnosticPanelState();
}

class _StudentDiagnosticPanelState extends State<_StudentDiagnosticPanel> {
  final TextEditingController _symptom = TextEditingController();
  final TextEditingController _hypothesis = TextEditingController();
  final TextEditingController _conclusion = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('student-diagnostic-panel'),
      padding: const EdgeInsets.all(ElectroSimSpacing.md),
      children: <Widget>[
        const ElectroSimSectionTitle(title: 'Fiche de diagnostic', subtitle: 'Visible uniquement pour l’élève en recherche de dérangement'),
        const SizedBox(height: ElectroSimSpacing.md),
        TextField(
          key: const Key('diagnostic-symptom'),
          controller: _symptom,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Symptôme observé'),
        ),
        const SizedBox(height: ElectroSimSpacing.sm),
        TextField(
          key: const Key('diagnostic-hypothesis'),
          controller: _hypothesis,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Hypothèse'),
        ),
        const SizedBox(height: ElectroSimSpacing.sm),
        TextField(
          key: const Key('diagnostic-conclusion'),
          controller: _conclusion,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Conclusion'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _symptom.dispose();
    _hypothesis.dispose();
    _conclusion.dispose();
    super.dispose();
  }
}

class _PropertyLine extends StatelessWidget {
  const _PropertyLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ElectroSimSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: 72, child: Text(label, style: Theme.of(context).textTheme.labelMedium)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
