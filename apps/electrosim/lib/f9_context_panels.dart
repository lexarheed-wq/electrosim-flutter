import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_measurements/electrosim_measurements.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:electrosim_tp/electrosim_tp.dart';
import 'package:flutter/material.dart';

import 'f9_element_editor.dart';
import 'f9_model_labels.dart';
import 'f9_ui_context.dart';
import 'runtime/electrosim_runtime_engine.dart';
import 'runtime/electrosim_tp_session_controller.dart';

class F9ContextPanels extends StatefulWidget {
  const F9ContextPanels({
    super.key,
    required this.circuit,
    required this.selectedId,
    required this.status,
    required this.workspace,
    required this.role,
    required this.onTogglePrimaryState,
    required this.onReplaceSelected,
    required this.onSelectElement,
    required this.runtimeSnapshot,
    this.tpSessionController,
  });

  final CircuitState circuit;
  final String? selectedId;
  final String status;
  final String workspace;
  final F9UserRole role;
  final VoidCallback? onTogglePrimaryState;
  final VoidCallback? onReplaceSelected;
  final ValueChanged<String?> onSelectElement;
  final ElectroSimRuntimeSnapshot runtimeSnapshot;
  final ElectroSimTpSessionController? tpSessionController;

  bool get showDiagnostic {
    if (role != F9UserRole.student ||
        workspace != 'Recherche de dérangement') {
      return false;
    }
    final ElectroSimTpSessionController? controller = tpSessionController;
    if (controller == null) {
      return true;
    }
    final TpSession? session = controller.session;
    return session?.diagnosticSheetVisibleFor(TpRole.student) ?? false;
  }

  @override
  State<F9ContextPanels> createState() => _F9ContextPanelsState();
}

class _F9ContextPanelsState extends State<F9ContextPanels> with TickerProviderStateMixin {
  late TabController _controller;

  int get _tabCount => 3;

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
          SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.showDiagnostic ? 'Panneau élève' : 'Inspecteur',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: ElectroSimColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Material(
            color: ElectroSimColors.surfaceElevated,
            child: TabBar(
              controller: _controller,
              isScrollable: false,
              labelStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
              tabs: <Widget>[
                const Tab(text: 'Propriétés'),
                const Tab(text: 'Mesures'),
                if (widget.showDiagnostic)
                  const Tab(
                    key: Key('diagnostic-tab'),
                    text: 'Diagnostic',
                  )
                else
                  const Tab(text: 'EIE'),
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
                  onReplaceSelected: widget.onReplaceSelected,
                  onSelectElement: widget.onSelectElement,
                ),
                _MeasurementsPanel(
                  circuit: widget.circuit,
                  selectedId: widget.selectedId,
                  runtimeSnapshot: widget.runtimeSnapshot,
                ),
                if (widget.showDiagnostic)
                  _StudentDiagnosticPanel(
                    controller: widget.tpSessionController,
                  )
                else
                  _EiePanel(runtimeSnapshot: widget.runtimeSnapshot),
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
    required this.onReplaceSelected,
    required this.onSelectElement,
  });

  final CircuitState circuit;
  final String? selectedId;
  final String status;
  final VoidCallback? onTogglePrimaryState;
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
                  (SourceInstance source) => DropdownMenuItem<String>(value: source.id.value, child: Text('${f9ModelLabel(source.modelType)} · ${source.id.value}')),
                ),
                ...circuit.components.map(
                  (ComponentInstance component) => DropdownMenuItem<String>(value: component.id.value, child: Text('${f9ModelLabel(component.modelType)} · ${component.id.value}')),
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
          Text(f9ModelLabel(details.modelType), key: const Key('properties-model-type'), style: Theme.of(context).textTheme.titleMedium),
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
  const _MeasurementsPanel({
    required this.circuit,
    required this.selectedId,
    required this.runtimeSnapshot,
  });

  final CircuitState circuit;
  final String? selectedId;
  final ElectroSimRuntimeSnapshot runtimeSnapshot;

  @override
  Widget build(BuildContext context) {
    if (runtimeSnapshot.solverKind == ElectroSimRuntimeSolverKind.pv) {
      return _PvRuntimePanel(runtimeSnapshot: runtimeSnapshot);
    }

    final _MeasurementTarget? target = _target();
    if (target == null) {
      return ListView(
        key: const Key('measurements-panel'),
        padding: const EdgeInsets.all(ElectroSimSpacing.md),
        children: <Widget>[
          const ElectroSimSectionTitle(
            title: 'Mesures',
            subtitle: 'Valeurs calculées uniquement par MeasurementEngine',
          ),
          const SizedBox(height: ElectroSimSpacing.md),
          const ElectroSimStatusChip(
            label: 'Sélectionnez un élément à 2 bornes',
            icon: Icons.touch_app_outlined,
          ),
          const SizedBox(height: ElectroSimSpacing.sm),
          const Text(
            'Le voltmètre et l’ampèremètre utilisent le résultat électrique courant. '
            'Aucune valeur n’est calculée ou inventée par l’interface.',
          ),
        ],
      );
    }

    final MeasurementResult voltage = runtimeSnapshot.measureVoltage(
      positiveProbe: target.terminals[0].id,
      negativeProbe: target.terminals[1].id,
    );
    final MeasurementResult current = runtimeSnapshot.measureCurrent(
      branchId: target.branchId,
    );
    final bool available = voltage.isValid && current.isValid;

    return ListView(
      key: const Key('measurements-panel'),
      padding: const EdgeInsets.all(ElectroSimSpacing.md),
      children: <Widget>[
        const ElectroSimSectionTitle(
          title: 'Mesures',
          subtitle: 'MeasurementEngine + résultat solveur courant',
        ),
        const SizedBox(height: ElectroSimSpacing.md),
        ElectroSimStatusChip(
          key: const Key('measurement-engine-status'),
          label: available ? 'Mesures moteur disponibles' : 'Mesure indisponible',
          icon: available ? Icons.verified_outlined : Icons.warning_amber_outlined,
          emphasized: available,
        ),
        const SizedBox(height: ElectroSimSpacing.md),
        Text(
          target.label,
          key: const Key('measurement-target-label'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: ElectroSimSpacing.xs),
        Text(
          'Bornes ${target.terminals[0].name} → ${target.terminals[1].name}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: ElectroSimColors.textSecondary,
          ),
        ),
        const SizedBox(height: ElectroSimSpacing.md),
        _InstrumentReading(
          key: const Key('measurement-voltmeter'),
          icon: Icons.speed_outlined,
          title: 'Voltmètre CC',
          reading: voltage,
          readingKey: const Key('measurement-voltage-reading'),
        ),
        const SizedBox(height: ElectroSimSpacing.sm),
        _InstrumentReading(
          key: const Key('measurement-ammeter'),
          icon: Icons.electric_meter_outlined,
          title: 'Ampèremètre CC',
          reading: current,
          readingKey: const Key('measurement-current-reading'),
        ),
        if (!available) ...<Widget>[
          const SizedBox(height: ElectroSimSpacing.md),
          Text(
            voltage.message ?? current.message ?? 'Résultat électrique indisponible.',
            key: const Key('measurement-error-message'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: ElectroSimColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  _MeasurementTarget? _target() {
    final String? id = selectedId;
    if (id == null) return null;
    for (final ComponentInstance component in circuit.components) {
      if (component.id.value == id && component.terminals.length == 2) {
        return _MeasurementTarget(
          label: '${f9ModelLabel(component.modelType)} · ${component.id.value}',
          terminals: component.terminals,
          branchId: 'component:${component.id.value}',
        );
      }
    }
    for (final SourceInstance source in circuit.sources) {
      if (source.id.value == id && source.terminals.length == 2) {
        return _MeasurementTarget(
          label: '${f9ModelLabel(source.modelType)} · ${source.id.value}',
          terminals: source.terminals,
          branchId: 'source:${source.id.value}',
        );
      }
    }
    return null;
  }
}

class _PvRuntimePanel extends StatelessWidget {
  const _PvRuntimePanel({required this.runtimeSnapshot});

  final ElectroSimRuntimeSnapshot runtimeSnapshot;

  @override
  Widget build(BuildContext context) {
    final pv = runtimeSnapshot.pv;
    if (!pv.isSolved) {
      return ListView(
        key: const Key('measurements-panel'),
        padding: const EdgeInsets.all(ElectroSimSpacing.md),
        children: <Widget>[
          const ElectroSimSectionTitle(
            title: 'Production PV',
            subtitle: 'Résultat direct du SolverPV',
          ),
          const SizedBox(height: ElectroSimSpacing.md),
          const ElectroSimStatusChip(
            key: Key('pv-runtime-status'),
            label: 'Circuit PV invalide',
            icon: Icons.warning_amber_outlined,
          ),
          const SizedBox(height: ElectroSimSpacing.sm),
          ...pv.diagnostics.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: ElectroSimSpacing.xs),
              child: Text(item.message),
            ),
          ),
        ],
      );
    }

    final sample = runtimeSnapshot.energyPowerSample();
    return ListView(
      key: const Key('measurements-panel'),
      padding: const EdgeInsets.all(ElectroSimSpacing.md),
      children: <Widget>[
        const ElectroSimSectionTitle(
          title: 'Production PV',
          subtitle: 'SolverPV + EnergyEngine',
        ),
        const SizedBox(height: ElectroSimSpacing.md),
        const ElectroSimStatusChip(
          key: Key('pv-runtime-status'),
          label: 'Solveur PV actif',
          icon: Icons.solar_power_outlined,
          emphasized: true,
        ),
        const SizedBox(height: ElectroSimSpacing.md),
        Text(
          '${pv.irradianceWm2.toStringAsFixed(1)} W/m²',
          key: const Key('pv-irradiance-reading'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Text('Irradiance'),
        const SizedBox(height: ElectroSimSpacing.sm),
        Text(
          '${pv.cellTemperatureC.toStringAsFixed(1)} °C',
          key: const Key('pv-temperature-reading'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Text('Température cellule'),
        const SizedBox(height: ElectroSimSpacing.sm),
        Text(
          '${pv.pvAvailablePowerW.toStringAsFixed(1)} W',
          key: const Key('pv-available-power-reading'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Text('Puissance PV disponible'),
        const SizedBox(height: ElectroSimSpacing.sm),
        Text(
          '${pv.inverterOutputPowerW.toStringAsFixed(1)} W',
          key: const Key('pv-output-power-reading'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text('Sortie onduleur · ${pv.inverterState.name}'),
        const SizedBox(height: ElectroSimSpacing.sm),
        Text(
          '${sample.lossPowerW.toStringAsFixed(1)} W',
          key: const Key('pv-loss-power-reading'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Text('Pertes instantanées routées vers EnergyEngine'),
        const SizedBox(height: ElectroSimSpacing.md),
        const Text(
          'L’énergie cumulée n’avance que lorsqu’une durée de simulation explicite est fournie. '
          'Le temps de rendu de l’interface n’est jamais comptabilisé.',
          key: Key('pv-energy-time-policy'),
        ),
      ],
    );
  }
}

final class _MeasurementTarget {
  const _MeasurementTarget({
    required this.label,
    required this.terminals,
    required this.branchId,
  });
  final String label;
  final List<Terminal> terminals;
  final String branchId;
}

class _InstrumentReading extends StatelessWidget {
  const _InstrumentReading({
    super.key,
    required this.icon,
    required this.title,
    required this.reading,
    required this.readingKey,
  });
  final IconData icon;
  final String title;
  final MeasurementResult reading;
  final Key readingKey;

  @override
  Widget build(BuildContext context) {
    final String value = reading.isValid ? _formatQuantity(reading.reading!) : '—';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(ElectroSimSpacing.md),
        child: Row(
          children: <Widget>[
            Icon(icon, color: reading.isValid ? ElectroSimColors.primary : ElectroSimColors.textSecondary),
            const SizedBox(width: ElectroSimSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: ElectroSimSpacing.xxs),
                  Text(value, key: readingKey, style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatQuantity(ElectricalQuantity quantity) {
    final String unit = switch (quantity.unit) {
      ElectricalUnit.volt => 'V',
      ElectricalUnit.ampere => 'A',
      ElectricalUnit.ohm => 'Ω',
      _ => quantity.unit.name,
    };
    final double value = quantity.value.abs() < 1e-12 ? 0.0 : quantity.value;
    return '${value.toStringAsFixed(3)} $unit';
  }
}
class _EiePanel extends StatelessWidget {
  const _EiePanel({required this.runtimeSnapshot});

  final ElectroSimRuntimeSnapshot runtimeSnapshot;

  @override
  Widget build(BuildContext context) {
    final report = runtimeSnapshot.diagnostics;
    final bool available = runtimeSnapshot.diagnosticsAvailable;
    final bool hasAdvice = available && report.advice.isNotEmpty;
    return ListView(
      key: const Key('eie-panel'),
      padding: const EdgeInsets.all(ElectroSimSpacing.md),
      children: <Widget>[
        const ElectroSimSectionTitle(
          title: 'EIE',
          subtitle: 'Diagnostic fondé uniquement sur les preuves moteur',
        ),
        const SizedBox(height: ElectroSimSpacing.md),
        ElectroSimStatusChip(
          key: const Key('eie-engine-status'),
          label: !available
              ? 'EIE non intégré pour ce mode'
              : hasAdvice
                  ? 'Anomalie étayée détectée'
                  : 'Aucune anomalie étayée',
          icon: !available
              ? Icons.info_outline
              : hasAdvice
                  ? Icons.warning_amber_outlined
                  : Icons.verified_outlined,
          emphasized: hasAdvice,
        ),
        const SizedBox(height: ElectroSimSpacing.sm),
        if (!available)
          Text(
            'Le solveur ${runtimeSnapshot.solverKind.name.toUpperCase()} est actif, mais l’EIE actuel ne consomme encore que les preuves du solveur CC. Aucun diagnostic pour ce mode n’est inventé.',
            key: const Key('eie-ac-unavailable'),
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else if (!hasAdvice)
          Text(
            'Le moteur EIE ne dispose actuellement d’aucune preuve suffisante pour proposer un diagnostic.',
            key: const Key('eie-no-advice'),
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          ...report.advice.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: ElectroSimSpacing.sm),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(ElectroSimSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.title,
                        key: Key('eie-advice-${item.code.name}'),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: ElectroSimSpacing.xs),
                      Text(item.explanation),
                      const SizedBox(height: ElectroSimSpacing.xs),
                      ExpansionTile(
                        key: Key('eie-evidence-${item.code.name}'),
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        title: const Text('Preuves'),
                        children: <Widget>[
                          for (final String evidenceId in item.evidenceIds)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                evidenceId,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: ElectroSimColors.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
class _StudentDiagnosticPanel extends StatefulWidget {
  const _StudentDiagnosticPanel({this.controller});

  final ElectroSimTpSessionController? controller;

  @override
  State<_StudentDiagnosticPanel> createState() =>
      _StudentDiagnosticPanelState();
}

class _StudentDiagnosticPanelState extends State<_StudentDiagnosticPanel> {
  static const List<String> _locations = <String>[
    'Source / alimentation',
    'Circuit de commande',
    'Récepteur / lampe',
  ];

  static const List<String> _suspects = <String>[
    'G1 — Alimentation',
    'QF1 — Disjoncteur',
    'S1 — Interrupteur',
    'H1 — Lampe',
  ];

  final TextEditingController _evidence = TextEditingController();
  final TextEditingController _conclusion = TextEditingController();
  String _location = 'Circuit de commande';
  String _suspect = 'S1 — Interrupteur';
  String _status = '';

  @override
  Widget build(BuildContext context) {
    final ElectroSimTpSessionController? controller = widget.controller;
    final int savedCount =
        controller?.session?.diagnosticSheet.entries.length ?? 0;
    final bool readOnly = controller?.readOnly ?? false;

    return ListView(
      key: const Key('student-diagnostic-panel'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border.all(color: const Color(0xFFD7E0EA)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'FICHE DE DIAGNOSTIC',
                      style: TextStyle(
                        color: ElectroSimColors.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: savedCount == 0
                          ? const Color(0xFFFFF1E8)
                          : const Color(0xFFEFF4FF),
                      borderRadius:
                          BorderRadius.circular(ElectroSimRadii.pill),
                    ),
                    child: Text(
                      savedCount == 0 ? 'À compléter' : 'En cours',
                      style: TextStyle(
                        color: savedCount == 0
                            ? ElectroSimColors.warning
                            : ElectroSimColors.info,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Renseignez votre raisonnement avant d’accéder à la réparation.',
                style: TextStyle(
                  color: ElectroSimColors.textSecondary,
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _DiagnosticQuestionCard(
          title: '1. Où situez-vous la panne ?',
          child: Column(
            children: <Widget>[
              for (final String location in _locations)
                _DiagnosticRadioRow(
                  key: Key(
                    'diagnostic-location-${_diagnosticSlug(location)}',
                  ),
                  label: location,
                  selected: _location == location,
                  enabled: !readOnly,
                  onTap: () {
                    if (readOnly) return;
                    setState(() => _location = location);
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _DiagnosticQuestionCard(
          title: '2. Composant suspecté',
          child: InputDecorator(
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: const Key('diagnostic-suspect'),
                value: _suspect,
                isExpanded: true,
                items: _suspects
                    .map(
                      (String value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: readOnly
                    ? null
                    : (String? value) {
                        if (value != null) {
                          setState(() => _suspect = value);
                        }
                      },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _DiagnosticQuestionCard(
          title: '3. Preuve de mesure',
          child: TextField(
            key: const Key('diagnostic-evidence'),
            controller: _evidence,
            enabled: !readOnly,
            minLines: 3,
            maxLines: 5,
            style: const TextStyle(fontSize: 10),
            decoration: const InputDecoration(
              hintText:
                  'Ex. indiquez les valeurs réellement mesurées et l’endroit où la tension disparaît.',
              hintStyle: TextStyle(fontSize: 9),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _DiagnosticQuestionCard(
          title: '4. Conclusion / action proposée',
          child: TextField(
            key: const Key('diagnostic-conclusion'),
            controller: _conclusion,
            enabled: !readOnly,
            minLines: 2,
            maxLines: 4,
            style: const TextStyle(fontSize: 10),
            decoration: const InputDecoration(
              hintText: 'Décrivez la vérification ou la réparation à réaliser.',
              hintStyle: TextStyle(fontSize: 9),
            ),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          key: const Key('diagnostic-save'),
          onPressed: controller == null || readOnly ? null : _save,
          icon: const Icon(Icons.save_outlined, size: 17),
          label: const Text('Enregistrer le diagnostic'),
        ),
        const SizedBox(height: 8),
        Text(
          'Entrées enregistrées : $savedCount',
          key: const Key('diagnostic-saved-count'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ElectroSimColors.textSecondary,
                fontSize: 9,
              ),
        ),
        if (_status.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            _status,
            key: const Key('diagnostic-save-status'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 9,
                ),
          ),
        ],
      ],
    );
  }

  void _save() {
    final ElectroSimTpSessionController? controller = widget.controller;
    if (controller == null) {
      return;
    }
    final String evidence = _evidence.text.trim();
    final String conclusion = _conclusion.text.trim();
    final List<DiagnosticEntry> entries = <DiagnosticEntry>[
      DiagnosticEntry(
        promptId: 'fault_location',
        answer: _location,
      ),
      DiagnosticEntry(
        promptId: 'suspected_component',
        answer: _suspect,
      ),
      if (evidence.isNotEmpty)
        DiagnosticEntry(
          promptId: 'measurement_evidence',
          answer: evidence,
        ),
      if (conclusion.isNotEmpty)
        DiagnosticEntry(
          promptId: 'conclusion',
          answer: conclusion,
        ),
    ];
    for (final DiagnosticEntry entry in entries) {
      controller.addDiagnosticEntry(
        promptId: entry.promptId,
        answer: entry.answer,
      );
    }
    _evidence.clear();
    _conclusion.clear();
    setState(() => _status = 'Diagnostic enregistré dans le TP.');
  }

  @override
  void dispose() {
    _evidence.dispose();
    _conclusion.dispose();
    super.dispose();
  }
}

class _DiagnosticQuestionCard extends StatelessWidget {
  const _DiagnosticQuestionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ElectroSimColors.surfaceElevated,
        border: Border.all(color: const Color(0xFFD7E0EA)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: ElectroSimColors.textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _DiagnosticRadioRow extends StatelessWidget {
  const _DiagnosticRadioRow({
    super.key,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            minHeight: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD7E0EA)),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? ElectroSimColors.info
                          : const Color(0xFF9FB0C4),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: selected
                      ? Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: ElectroSimColors.info,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: ElectroSimColors.textPrimary,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _diagnosticSlug(String value) {
  return value
      .toLowerCase()
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('à', 'a')
      .replaceAll(' / ', '-')
      .replaceAll(' ', '-');
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
