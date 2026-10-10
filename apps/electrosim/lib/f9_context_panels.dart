import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_measurements/electrosim_measurements.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:electrosim_tp/electrosim_tp.dart';
import 'package:flutter/material.dart';

import 'f18_g7_property_presenter.dart';
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

  bool get showEie => role == F9UserRole.teacher;

  bool get showDiagnostic {
    if (role != F9UserRole.student || workspace != 'Recherche de dérangement') {
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

class _F9ContextPanelsState extends State<F9ContextPanels>
    with TickerProviderStateMixin {
  late TabController _controller;

  int get _tabCount =>
      2 + (widget.showEie ? 1 : 0) + (widget.showDiagnostic ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: _tabCount, vsync: this);
  }

  @override
  void didUpdateWidget(covariant F9ContextPanels oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.length != _tabCount) {
      final int previousIndex = _controller.index
          .clamp(0, _tabCount - 1)
          .toInt();
      _controller.dispose();
      _controller = TabController(
        length: _tabCount,
        vsync: this,
        initialIndex: previousIndex,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabHeight = (44 + MediaQuery.textScalerOf(context).scale(14) * 2.4)
        .clamp(72.0, 140.0);
    Widget tab(String label, IconData icon, {Key? key}) => Tooltip(
      message: label,
      child: Tab(
        key: key,
        height: tabHeight,
        icon: Icon(icon, size: 18),
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
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
                tab('Propriétés', Icons.tune_outlined),
                tab('Mesures', Icons.straighten_outlined),
                if (widget.showEie)
                  tab(
                    'EIE',
                    Icons.psychology_alt_outlined,
                    key: const Key('eie-tab'),
                  ),
                if (widget.showDiagnostic)
                  tab(
                    'Diagnostic',
                    Icons.fact_check_outlined,
                    key: const Key('diagnostic-tab'),
                  ),
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
                  runtimeSnapshot: widget.runtimeSnapshot,
                ),
                _MeasurementsPanel(
                  circuit: widget.circuit,
                  selectedId: widget.selectedId,
                  runtimeSnapshot: widget.runtimeSnapshot,
                ),
                if (widget.showEie)
                  _EiePanel(runtimeSnapshot: widget.runtimeSnapshot),
                if (widget.showDiagnostic)
                  _StudentDiagnosticPanel(
                    controller: widget.tpSessionController,
                  ),
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
    required this.runtimeSnapshot,
  });

  final CircuitState circuit;
  final String? selectedId;
  final String status;
  final VoidCallback? onTogglePrimaryState;
  final VoidCallback? onReplaceSelected;
  final ValueChanged<String?> onSelectElement;
  final ElectroSimRuntimeSnapshot runtimeSnapshot;

  @override
  Widget build(BuildContext context) {
    final F9ElementDetails? details = F9ElementEditor.describe(
      circuit,
      selectedId,
    );
    final bool? primaryToggleValue = details?.primaryToggleValue;
    final bool directCanvasControl = switch (details?.modelType.toLowerCase()) {
      'switch' ||
      'switch_spst' ||
      'push_button_no' ||
      'push_button_nc' ||
      'breaker_dc' ||
      'breaker_ac1' ||
      'breaker' => true,
      _ => false,
    };
    final F18G7PropertySnapshot? propertySnapshot = details == null
        ? null
        : F18G7PropertyPresenter.describe(
            details: details,
            runtimeSnapshot: runtimeSnapshot,
          );
    return ListView(
      key: const Key('properties-panel'),
      padding: const EdgeInsets.all(ElectroSimSpacing.md),
      children: <Widget>[
        const ElectroSimSectionTitle(
          title: 'Propriétés',
          subtitle: 'Réglages et état du composant',
        ),
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
                  (SourceInstance source) => DropdownMenuItem<String>(
                    value: source.id.value,
                    child: Text(
                      '${f9ModelLabel(source.modelType)} · ${source.id.value}',
                    ),
                  ),
                ),
                ...circuit.components.map(
                  (ComponentInstance component) => DropdownMenuItem<String>(
                    value: component.id.value,
                    child: Text(
                      '${f9ModelLabel(component.modelType)} · ${component.id.value}',
                    ),
                  ),
                ),
                ...circuit.connections.map(
                  (Connection connection) => DropdownMenuItem<String>(
                    value: connection.id.value,
                    child: Text('Fil · ${connection.id.value}'),
                  ),
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
          Text(
            details.kind == F9ElementKind.connection
                ? 'Fil'
                : f9ModelLabel(details.modelType),
            key: const Key('properties-model-type'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: ElectroSimSpacing.xxs),
          Text(
            details.id,
            key: const Key('properties-element-id'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: ElectroSimColors.textSecondary,
            ),
          ),
          const SizedBox(height: ElectroSimSpacing.md),
          _PropertyLine(
            label: 'Type',
            value: switch (details.kind) {
              F9ElementKind.source => 'Source',
              F9ElementKind.component => 'Composant',
              F9ElementKind.connection => 'Fil',
            },
          ),
          _PropertyLine(label: 'État déclaré', value: details.stateLabel),
          _PropertyLine(
            label: 'Bornes',
            value: details.terminalLabels.join(' · '),
          ),
          if (primaryToggleValue != null && !directCanvasControl) ...<Widget>[
            const SizedBox(height: ElectroSimSpacing.sm),
            SwitchListTile.adaptive(
              key: const Key('properties-primary-toggle'),
              contentPadding: EdgeInsets.zero,
              title: Text(details.primaryToggleLabel ?? 'État'),
              subtitle: const Text('Commande explicite du CircuitState'),
              value: primaryToggleValue,
              onChanged: onTogglePrimaryState == null
                  ? null
                  : (_) => onTogglePrimaryState!(),
            ),
          ],
          if (primaryToggleValue != null && directCanvasControl) ...<Widget>[
            const SizedBox(height: ElectroSimSpacing.sm),
            const ElectroSimStatusChip(
              key: Key('properties-direct-control-hint'),
              label: 'Commande directe sur la platine',
              icon: Icons.ads_click_outlined,
              emphasized: true,
            ),
            const SizedBox(height: ElectroSimSpacing.xs),
            const Text(
              'Double-cliquez sur la zone de commande du composant '
              '(manette, bascule ou bouton-poussoir).',
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
          if (propertySnapshot != null) ...<Widget>[
            const SizedBox(height: ElectroSimSpacing.sm),
            Text(
              'État physique',
              key: const Key('properties-runtime-heading'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: ElectroSimSpacing.xs),
            _PropertyLine(
              label: 'Domaine',
              value: propertySnapshot.domainLabel,
            ),
            _PropertyLine(
              label: 'Solveur',
              value: propertySnapshot.solverLabel,
            ),
            if (propertySnapshot.runtimeStateLabel != null)
              _PropertyLine(
                label: 'État calculé',
                value: propertySnapshot.runtimeStateLabel!,
              ),
            ...propertySnapshot.runtimeValues.map(
              (F18G7PropertyRow row) =>
                  _PropertyLine(label: row.label, value: row.value),
            ),
            if (propertySnapshot.evidenceIds.isNotEmpty)
              ExpansionTile(
                key: const Key('properties-runtime-evidence'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text('Preuves de calcul'),
                children: propertySnapshot.evidenceIds
                    .map(
                      (String evidence) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          evidence,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: ElectroSimColors.textSecondary),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
          ],
          if (propertySnapshot?.parameters.isNotEmpty == true) ...<Widget>[
            const SizedBox(height: ElectroSimSpacing.sm),
            Text(
              'Paramètres électriques',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: ElectroSimSpacing.xs),
            ...propertySnapshot!.parameters.map(
              (F18G7PropertyRow row) =>
                  _PropertyLine(label: row.label, value: row.value),
            ),
          ],
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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: ElectroSimColors.textSecondary,
            ),
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

    final bool ac3 =
        runtimeSnapshot.solverKind == ElectroSimRuntimeSolverKind.ac3;
    final MeasurementResult? phaseSequence = ac3
        ? runtimeSnapshot.measurePhaseSequence()
        : null;
    final MeasurementResult? totalActive = ac3
        ? runtimeSnapshot.measureActivePower()
        : null;
    final MeasurementResult? totalReactive = ac3
        ? runtimeSnapshot.measureReactivePower()
        : null;
    final MeasurementResult? totalApparent = ac3
        ? runtimeSnapshot.measureApparentPower()
        : null;

    final _MeasurementTarget? target = _target();
    if (target == null) {
      return ListView(
        key: const Key('measurements-panel'),
        padding: const EdgeInsets.all(ElectroSimSpacing.md),
        children: <Widget>[
          const ElectroSimSectionTitle(
            title: 'Mesures',
            subtitle: 'Valeurs calculées par la simulation',
          ),
          const SizedBox(height: ElectroSimSpacing.md),
          if (ac3) ...<Widget>[
            ElectroSimStatusChip(
              label: phaseSequence?.isValid == true
                  ? 'Réseau triphasé mesurable'
                  : 'Mesure triphasée indisponible',
              icon: Icons.threesixty_outlined,
              emphasized: phaseSequence?.isValid == true,
            ),
            const SizedBox(height: ElectroSimSpacing.sm),
            _InstrumentReading(
              key: const Key('measurement-phase-sequence-meter'),
              icon: Icons.rotate_right_outlined,
              title: 'Contrôleur d’ordre des phases',
              reading: phaseSequence!,
              readingKey: const Key('measurement-phase-sequence-reading'),
            ),
            const SizedBox(height: ElectroSimSpacing.sm),
            _InstrumentReading(
              icon: Icons.bolt_outlined,
              title: 'Puissance active totale P',
              reading: totalActive!,
              readingKey: const Key('measurement-active-power-reading'),
            ),
            const SizedBox(height: ElectroSimSpacing.sm),
            _InstrumentReading(
              icon: Icons.waves_outlined,
              title: 'Puissance réactive totale Q',
              reading: totalReactive!,
              readingKey: const Key('measurement-reactive-power-reading'),
            ),
            const SizedBox(height: ElectroSimSpacing.sm),
            _InstrumentReading(
              icon: Icons.electric_meter_outlined,
              title: 'Puissance apparente totale S',
              reading: totalApparent!,
              readingKey: const Key('measurement-apparent-power-reading'),
            ),
          ] else ...<Widget>[
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
        ],
      );
    }

    final bool ac =
        runtimeSnapshot.solverKind == ElectroSimRuntimeSolverKind.ac1 ||
        runtimeSnapshot.solverKind == ElectroSimRuntimeSolverKind.ac3;
    final MeasurementResult voltage = ac
        ? runtimeSnapshot.measureAcVoltage(
            positiveProbe: target.terminals[0].id,
            negativeProbe: target.terminals[1].id,
          )
        : runtimeSnapshot.measureVoltage(
            positiveProbe: target.terminals[0].id,
            negativeProbe: target.terminals[1].id,
          );
    final MeasurementResult current = ac
        ? runtimeSnapshot.measureAcCurrent(branchId: target.branchId)
        : runtimeSnapshot.measureCurrent(branchId: target.branchId);
    final MeasurementResult? frequency = ac
        ? runtimeSnapshot.measureFrequency()
        : null;
    final MeasurementResult? activePower = ac
        ? (ac3
              ? totalActive
              : runtimeSnapshot.measureActivePower(branchId: target.branchId))
        : null;
    final MeasurementResult? reactivePower = ac
        ? (ac3
              ? totalReactive
              : runtimeSnapshot.measureReactivePower(branchId: target.branchId))
        : null;
    final MeasurementResult? apparentPower = ac
        ? (ac3
              ? totalApparent
              : runtimeSnapshot.measureApparentPower(branchId: target.branchId))
        : null;
    final bool available =
        voltage.isValid &&
        current.isValid &&
        (frequency == null || frequency.isValid) &&
        (activePower == null || activePower.isValid) &&
        (reactivePower == null || reactivePower.isValid) &&
        (apparentPower == null || apparentPower.isValid);

    return ListView(
      key: const Key('measurements-panel'),
      padding: const EdgeInsets.all(ElectroSimSpacing.md),
      children: <Widget>[
        const ElectroSimSectionTitle(
          title: 'Mesures',
          subtitle: 'Valeurs issues du calcul électrique courant',
        ),
        const SizedBox(height: ElectroSimSpacing.md),
        ElectroSimStatusChip(
          key: const Key('measurement-engine-status'),
          label: available
              ? 'Mesures moteur disponibles'
              : 'Mesure indisponible',
          icon: available
              ? Icons.verified_outlined
              : Icons.warning_amber_outlined,
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
          title: ac ? 'Voltmètre AC RMS' : 'Voltmètre CC',
          reading: voltage,
          readingKey: const Key('measurement-voltage-reading'),
        ),
        const SizedBox(height: ElectroSimSpacing.sm),
        _InstrumentReading(
          key: const Key('measurement-ammeter'),
          icon: Icons.electric_meter_outlined,
          title: ac ? 'Ampèremètre AC RMS' : 'Ampèremètre CC',
          reading: current,
          readingKey: const Key('measurement-current-reading'),
        ),
        if (frequency != null) ...<Widget>[
          const SizedBox(height: ElectroSimSpacing.sm),
          _InstrumentReading(
            key: const Key('measurement-frequency-meter'),
            icon: Icons.graphic_eq_outlined,
            title: 'Fréquencemètre',
            reading: frequency,
            readingKey: const Key('measurement-frequency-reading'),
          ),
        ],
        if (phaseSequence != null) ...<Widget>[
          const SizedBox(height: ElectroSimSpacing.sm),
          _InstrumentReading(
            key: const Key('measurement-phase-sequence-meter'),
            icon: Icons.rotate_right_outlined,
            title: 'Contrôleur d’ordre des phases',
            reading: phaseSequence,
            readingKey: const Key('measurement-phase-sequence-reading'),
          ),
        ],
        if (activePower != null) ...<Widget>[
          const SizedBox(height: ElectroSimSpacing.sm),
          _InstrumentReading(
            icon: Icons.bolt_outlined,
            title: ac3 ? 'Puissance active totale P' : 'Puissance active P',
            reading: activePower,
            readingKey: const Key('measurement-active-power-reading'),
          ),
          const SizedBox(height: ElectroSimSpacing.sm),
          _InstrumentReading(
            icon: Icons.waves_outlined,
            title: ac3 ? 'Puissance réactive totale Q' : 'Puissance réactive Q',
            reading: reactivePower!,
            readingKey: const Key('measurement-reactive-power-reading'),
          ),
          const SizedBox(height: ElectroSimSpacing.sm),
          _InstrumentReading(
            icon: Icons.electric_meter_outlined,
            title: ac3
                ? 'Puissance apparente totale S'
                : 'Puissance apparente S',
            reading: apparentPower!,
            readingKey: const Key('measurement-apparent-power-reading'),
          ),
        ],
        if (!available) ...<Widget>[
          const SizedBox(height: ElectroSimSpacing.md),
          Text(
            voltage.message ??
                current.message ??
                'Résultat électrique indisponible.',
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
        if (pv.controllerPresent) ...<Widget>[
          Text(
            '${(pv.controllerEfficiency * 100).toStringAsFixed(1)} %',
            key: const Key('pv-controller-efficiency-reading'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Text('Rendement régulateur'),
          const SizedBox(height: ElectroSimSpacing.sm),
        ],
        if (pv.batteryPresent) ...<Widget>[
          Text(
            '${(pv.batterySoc * 100).toStringAsFixed(1)} %',
            key: const Key('pv-battery-soc-reading'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            'SOC batterie · ${pv.batteryVoltageV.toStringAsFixed(1)} V · '
            '${pv.batteryStoredEnergyWh.toStringAsFixed(0)} Wh',
          ),
          const SizedBox(height: ElectroSimSpacing.sm),
          Text(
            '${pv.batteryPowerW.abs().toStringAsFixed(1)} W',
            key: const Key('pv-battery-power-reading'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            pv.batteryPowerW > 1e-9
                ? 'Batterie en décharge'
                : pv.batteryPowerW < -1e-9
                ? 'Batterie en charge'
                : 'Batterie au repos',
          ),
          const SizedBox(height: ElectroSimSpacing.sm),
        ],
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
    final String value = reading.isValid
        ? (reading.displayText ?? _formatQuantity(reading.reading!))
        : '—';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(ElectroSimSpacing.md),
        child: Row(
          children: <Widget>[
            Icon(
              icon,
              color: reading.isValid
                  ? ElectroSimColors.primary
                  : ElectroSimColors.textSecondary,
            ),
            const SizedBox(width: ElectroSimSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: ElectroSimSpacing.xxs),
                  Text(
                    value,
                    key: readingKey,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
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
      ElectricalUnit.watt => 'W',
      ElectricalUnit.wattHour => 'Wh',
      ElectricalUnit.kilowattHour => 'kWh',
      ElectricalUnit.hertz => 'Hz',
      ElectricalUnit.voltAmpere => 'VA',
      ElectricalUnit.varUnit => 'var',
      ElectricalUnit.degree => '°',
      ElectricalUnit.radian => 'rad',
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
          subtitle:
              'Intelligence interne fondée uniquement sur les preuves moteur',
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
                        initiallyExpanded: false,
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        title: const Text('Détails techniques'),
                        children: <Widget>[
                          for (final String evidenceId in item.evidenceIds)
                            Builder(
                              builder: (BuildContext context) {
                                final evidence = report.evidence.firstWhere(
                                  (candidate) => candidate.id == evidenceId,
                                );
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: ElectroSimSpacing.xs,
                                    ),
                                    child: Text(
                                      '$evidenceId\n${evidence.summary}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color:
                                                ElectroSimColors.textSecondary,
                                          ),
                                    ),
                                  ),
                                );
                              },
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
  final TextEditingController _symptom = TextEditingController();
  final TextEditingController _hypothesis = TextEditingController();
  final TextEditingController _conclusion = TextEditingController();
  String _status = '';

  @override
  Widget build(BuildContext context) {
    final ElectroSimTpSessionController? controller = widget.controller;
    final int savedCount =
        controller?.session?.diagnosticSheet.entries.length ?? 0;
    return ListView(
      key: const Key('student-diagnostic-panel'),
      padding: const EdgeInsets.all(ElectroSimSpacing.md),
      children: <Widget>[
        const ElectroSimSectionTitle(
          title: 'Fiche de diagnostic',
          subtitle:
              'Visible uniquement pour l’élève pendant la recherche de dérangement',
        ),
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
        const SizedBox(height: ElectroSimSpacing.md),
        FilledButton.icon(
          key: const Key('diagnostic-save'),
          onPressed: controller == null ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Enregistrer dans le TP'),
        ),
        const SizedBox(height: ElectroSimSpacing.xs),
        Text(
          'Entrées enregistrées : $savedCount',
          key: const Key('diagnostic-saved-count'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: ElectroSimColors.textSecondary,
          ),
        ),
        if (_status.isNotEmpty) ...<Widget>[
          const SizedBox(height: ElectroSimSpacing.xs),
          Text(
            _status,
            key: const Key('diagnostic-save-status'),
            style: Theme.of(context).textTheme.bodySmall,
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
    final List<DiagnosticEntry> entries = <DiagnosticEntry>[
      if (_symptom.text.trim().isNotEmpty)
        DiagnosticEntry(promptId: 'symptom', answer: _symptom.text.trim()),
      if (_hypothesis.text.trim().isNotEmpty)
        DiagnosticEntry(
          promptId: 'hypothesis',
          answer: _hypothesis.text.trim(),
        ),
      if (_conclusion.text.trim().isNotEmpty)
        DiagnosticEntry(
          promptId: 'conclusion',
          answer: _conclusion.text.trim(),
        ),
    ];
    if (entries.isEmpty) {
      setState(() => _status = 'Aucune réponse à enregistrer.');
      return;
    }
    for (final DiagnosticEntry entry in entries) {
      controller.addDiagnosticEntry(
        promptId: entry.promptId,
        answer: entry.answer,
      );
    }
    _symptom.clear();
    _hypothesis.clear();
    _conclusion.clear();
    setState(() => _status = 'Fiche enregistrée dans le TP.');
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: ElectroSimSpacing.xs),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final labelWidget = Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: ElectroSimColors.textSecondary,
          ),
        );
        if (constraints.maxWidth < 260 ||
            MediaQuery.textScalerOf(context).scale(14) > 18) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [labelWidget, const SizedBox(height: 4), Text(value)],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: (constraints.maxWidth * .42).clamp(88.0, 128.0),
              child: labelWidget,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(value)),
          ],
        );
      },
    ),
  );
}
