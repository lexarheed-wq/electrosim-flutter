import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_tp/electrosim_tp.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';

import 'f17_tp_supervision_panel.dart';
import 'runtime/electrosim_tp_session_controller.dart';

enum _LiveSupervisionFilter { all, online, active, completed, attention }

class F18LiveSupervisionPanel extends StatefulWidget {
  const F18LiveSupervisionPanel({
    super.key,
    required this.controller,
    this.students = const <F17StudentSupervisionItem>[],
    this.onGradeStudent,
    this.onCloseStudent,
    this.initialSelectedClientId,
  });

  final ElectroSimTpSessionController controller;
  final List<F17StudentSupervisionItem> students;
  final ValueChanged<F17StudentGradeRequest>? onGradeStudent;
  final ValueChanged<String>? onCloseStudent;
  final String? initialSelectedClientId;

  @override
  State<F18LiveSupervisionPanel> createState() =>
      _F18LiveSupervisionPanelState();
}

class _F18LiveSupervisionPanelState extends State<F18LiveSupervisionPanel> {
  _LiveSupervisionFilter _filter = _LiveSupervisionFilter.all;
  String? _selectedClientId;

  @override
  void initState() {
    super.initState();
    _selectedClientId = widget.initialSelectedClientId;
  }

  @override
  void didUpdateWidget(covariant F18LiveSupervisionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String? selected = _selectedClientId;
    if (selected != null &&
        !widget.students.any(
          (F17StudentSupervisionItem item) => item.clientId == selected,
        )) {
      _selectedClientId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: ElectroSimColors.surfaceElevated,
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (BuildContext context, Widget? child) {
          final TpSession? teacherSession = widget.controller.session;
          final List<F17StudentSupervisionItem> all = widget.students;
          final int online = all
              .where((F17StudentSupervisionItem item) => item.connected)
              .length;
          final int active = all
              .where(
                (F17StudentSupervisionItem item) =>
                    item.session?.lifecycle == TpLifecycle.started,
              )
              .length;
          final int completed = all.where((F17StudentSupervisionItem item) {
            final TpLifecycle? lifecycle = item.session?.lifecycle;
            return lifecycle == TpLifecycle.evaluated ||
                lifecycle == TpLifecycle.closed;
          }).length;
          final int attention = all.where(_needsAttention).length;
          final List<F17StudentSupervisionItem> visible =
              all.where(_matchesFilter).toList(growable: false);
          final F17StudentSupervisionItem? selected = _selectedStudent(all);

          return ListView(
            key: const Key('tp-supervision-panel'),
            padding: const EdgeInsets.all(ElectroSimSpacing.md),
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Expanded(
                    child: ElectroSimSectionTitle(
                      title: 'Supervision',
                      subtitle:
                          'Suivi en temps réel de la classe et du travail de chaque élève',
                    ),
                  ),
                  const SizedBox(width: ElectroSimSpacing.sm),
                  const _LiveUpdateBadge(),
                ],
              ),
              const SizedBox(height: ElectroSimSpacing.md),
              Wrap(
                spacing: ElectroSimSpacing.sm,
                runSpacing: ElectroSimSpacing.sm,
                children: <Widget>[
                  _MetricCard(
                    key: const Key('supervision-identified-count'),
                    label: 'Élèves identifiés',
                    value: all.length.toString(),
                    icon: Icons.badge_outlined,
                  ),
                  _MetricCard(
                    key: const Key('supervision-connected-count'),
                    label: 'En ligne',
                    value: online.toString(),
                    icon: Icons.wifi_outlined,
                  ),
                  _MetricCard(
                    key: const Key('supervision-active-count'),
                    label: 'En activité',
                    value: active.toString(),
                    icon: Icons.play_circle_outline,
                  ),
                  _MetricCard(
                    key: const Key('supervision-completed-count'),
                    label: 'Terminés',
                    value: completed.toString(),
                    icon: Icons.task_alt_outlined,
                  ),
                  _MetricCard(
                    key: const Key('supervision-attention-count'),
                    label: 'À surveiller',
                    value: attention.toString(),
                    icon: Icons.visibility_outlined,
                  ),
                ],
              ),
              const SizedBox(height: ElectroSimSpacing.md),
              if (teacherSession == null) ...<Widget>[
                const ElectroSimStatusChip(
                  label: 'Aucun TP actif',
                  icon: Icons.assignment_outlined,
                ),
                const SizedBox(height: ElectroSimSpacing.sm),
                const Text(
                  'Créez puis publiez un TP depuis « Gérer la session ».',
                ),
              ] else ...<Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        teacherSession.definition.title,
                        key: const Key('supervision-title'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    ElectroSimStatusChip(
                      key: const Key('supervision-lifecycle'),
                      label: _lifecycleLabel(teacherSession.lifecycle),
                      icon: _statusIcon(teacherSession.lifecycle),
                      emphasized:
                          teacherSession.lifecycle != TpLifecycle.draft,
                    ),
                  ],
                ),
                const SizedBox(height: ElectroSimSpacing.xs),
                Text(
                  'Activité : ' + _modeLabel(teacherSession.definition.mode),
                ),
                if (teacherSession.evaluation != null) ...<Widget>[
                  const SizedBox(height: ElectroSimSpacing.xs),
                  Text(
                    'Résultat global : ' +
                        teacherSession.evaluation!.score.toString() +
                        '/' +
                        teacherSession.definition.maxScore.toString(),
                    key: const Key('supervision-score'),
                  ),
                ],
              ],
              const SizedBox(height: ElectroSimSpacing.md),
              Wrap(
                spacing: ElectroSimSpacing.xs,
                runSpacing: ElectroSimSpacing.xs,
                children: <Widget>[
                  _FilterButton(
                    label: 'Tous ' + all.length.toString(),
                    selected: _filter == _LiveSupervisionFilter.all,
                    onTap: () => _setFilter(_LiveSupervisionFilter.all),
                  ),
                  _FilterButton(
                    label: 'En ligne ' + online.toString(),
                    selected: _filter == _LiveSupervisionFilter.online,
                    onTap: () => _setFilter(_LiveSupervisionFilter.online),
                  ),
                  _FilterButton(
                    label: 'En cours ' + active.toString(),
                    selected: _filter == _LiveSupervisionFilter.active,
                    onTap: () => _setFilter(_LiveSupervisionFilter.active),
                  ),
                  _FilterButton(
                    label: 'Terminés ' + completed.toString(),
                    selected: _filter == _LiveSupervisionFilter.completed,
                    onTap: () => _setFilter(_LiveSupervisionFilter.completed),
                  ),
                  _FilterButton(
                    label: 'À surveiller ' + attention.toString(),
                    selected: _filter == _LiveSupervisionFilter.attention,
                    onTap: () => _setFilter(_LiveSupervisionFilter.attention),
                  ),
                ],
              ),
              const SizedBox(height: ElectroSimSpacing.md),
              _StudentTable(
                students: visible,
                selectedClientId: _selectedClientId,
                onSelect: _selectStudent,
              ),
              const SizedBox(height: ElectroSimSpacing.md),
              if (selected == null)
                const _NoStudentSelectedPanel()
              else
                _StudentDetailPanel(
                  key: ValueKey<String>(
                    'supervision-detail-' + selected.clientId,
                  ),
                  student: selected,
                  onGradeStudent: widget.onGradeStudent,
                  onCloseStudent: widget.onCloseStudent,
                ),
            ],
          );
        },
      ),
    );
  }

  F17StudentSupervisionItem? _selectedStudent(
    List<F17StudentSupervisionItem> all,
  ) {
    final String? selected = _selectedClientId;
    if (selected == null) return null;
    for (final F17StudentSupervisionItem student in all) {
      if (student.clientId == selected) return student;
    }
    return null;
  }

  bool _matchesFilter(F17StudentSupervisionItem student) {
    switch (_filter) {
      case _LiveSupervisionFilter.all:
        return true;
      case _LiveSupervisionFilter.online:
        return student.connected;
      case _LiveSupervisionFilter.active:
        return student.session?.lifecycle == TpLifecycle.started;
      case _LiveSupervisionFilter.completed:
        final TpLifecycle? lifecycle = student.session?.lifecycle;
        return lifecycle == TpLifecycle.evaluated ||
            lifecycle == TpLifecycle.closed;
      case _LiveSupervisionFilter.attention:
        return _needsAttention(student);
    }
  }

  void _setFilter(_LiveSupervisionFilter value) {
    setState(() {
      _filter = value;
    });
  }

  void _selectStudent(String clientId) {
    setState(() {
      _selectedClientId = clientId;
    });
  }
}

class _LiveUpdateBadge extends StatelessWidget {
  const _LiveUpdateBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ElectroSimColors.background,
        border: Border.all(color: ElectroSimColors.outline),
        borderRadius: BorderRadius.circular(ElectroSimRadii.card),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: ElectroSimSpacing.sm,
          vertical: ElectroSimSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.circle, size: 9, color: Colors.green),
            SizedBox(width: ElectroSimSpacing.xs),
            Text('ACTUALISATION AUTOMATIQUE'),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 164,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ElectroSimColors.background,
          borderRadius: BorderRadius.circular(ElectroSimRadii.card),
          border: Border.all(color: ElectroSimColors.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(ElectroSimSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(icon, size: 18),
                  const SizedBox(width: ElectroSimSpacing.xs),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ElectroSimSpacing.xs),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _StudentTable extends StatelessWidget {
  const _StudentTable({
    required this.students,
    required this.selectedClientId,
    required this.onSelect,
  });

  final List<F17StudentSupervisionItem> students;
  final String? selectedClientId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: ElectroSimColors.outline),
        borderRadius: BorderRadius.circular(ElectroSimRadii.card),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 1030,
          child: Column(
            children: <Widget>[
              const _StudentTableHeader(),
              if (students.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(ElectroSimSpacing.md),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Aucun élève dans ce filtre.'),
                  ),
                )
              else
                ...students.map(
                  (F17StudentSupervisionItem student) => _StudentTableRow(
                    student: student,
                    selected: selectedClientId == student.clientId,
                    onSelect: () => onSelect(student.clientId),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentTableHeader extends StatelessWidget {
  const _StudentTableHeader();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: ElectroSimColors.background,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: ElectroSimSpacing.sm,
          vertical: ElectroSimSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            SizedBox(width: 190, child: Text('ÉLÈVE')),
            SizedBox(width: 125, child: Text('ÉTAT')),
            SizedBox(width: 190, child: Text('ACTIVITÉ')),
            SizedBox(width: 255, child: Text('PROGRESSION')),
            SizedBox(width: 130, child: Text('DERNIÈRE ACTIVITÉ')),
            SizedBox(width: 110, child: Text('ATTENTION')),
          ],
        ),
      ),
    );
  }
}

class _StudentTableRow extends StatelessWidget {
  const _StudentTableRow({
    required this.student,
    required this.selected,
    required this.onSelect,
  });

  final F17StudentSupervisionItem student;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final TpSession? session = student.session;
    final int progress = _progressPercent(session);
    return Material(
      color: selected
          ? ElectroSimColors.background
          : ElectroSimColors.surfaceElevated,
      child: InkWell(
        key: Key('supervision-student-open-' + student.clientId),
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ElectroSimSpacing.sm,
            vertical: ElectroSimSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 190,
                child: Row(
                  children: <Widget>[
                    Icon(
                      student.connected
                          ? Icons.check_circle_outline
                          : Icons.cloud_off_outlined,
                      size: 18,
                    ),
                    const SizedBox(width: ElectroSimSpacing.xs),
                    Expanded(
                      child: Text(
                        student.displayName,
                        key: Key(
                          'supervision-student-name-' + student.clientId,
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 125,
                child: Text(
                  student.connected ? 'En ligne' : 'Hors ligne',
                  key: Key(
                    'supervision-student-connection-' + student.clientId,
                  ),
                ),
              ),
              SizedBox(
                width: 190,
                child: Text(
                  _activityLabel(session),
                  key: Key(
                    'supervision-student-state-' + student.clientId,
                  ),
                ),
              ),
              SizedBox(
                width: 255,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: LinearProgressIndicator(
                        key: Key(
                          'supervision-progress-' + student.clientId,
                        ),
                        value: progress / 100,
                      ),
                    ),
                    const SizedBox(width: ElectroSimSpacing.xs),
                    SizedBox(
                      width: 40,
                      child: Text(progress.toString() + '%'),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 130,
                child: Text(_formatActivityTime(student.lastActivityAtUtc)),
              ),
              SizedBox(
                width: 110,
                child: Text(
                  _attentionLabel(student),
                  key: Key(
                    'supervision-attention-' + student.clientId,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoStudentSelectedPanel extends StatelessWidget {
  const _NoStudentSelectedPanel();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('supervision-no-selection'),
      decoration: BoxDecoration(
        color: ElectroSimColors.background,
        borderRadius: BorderRadius.circular(ElectroSimRadii.card),
        border: Border.all(color: ElectroSimColors.outline),
      ),
      child: const Padding(
        padding: EdgeInsets.all(ElectroSimSpacing.md),
        child: Row(
          children: <Widget>[
            Icon(Icons.touch_app_outlined),
            SizedBox(width: ElectroSimSpacing.sm),
            Expanded(
              child: Text(
                'Cliquez sur le nom d’un élève pour suivre son travail en temps réel.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentDetailPanel extends StatefulWidget {
  const _StudentDetailPanel({
    super.key,
    required this.student,
    required this.onGradeStudent,
    required this.onCloseStudent,
  });

  final F17StudentSupervisionItem student;
  final ValueChanged<F17StudentGradeRequest>? onGradeStudent;
  final ValueChanged<String>? onCloseStudent;

  @override
  State<_StudentDetailPanel> createState() => _StudentDetailPanelState();
}

class _StudentDetailPanelState extends State<_StudentDetailPanel> {
  final TextEditingController _score = TextEditingController();
  String? _error;

  @override
  void didUpdateWidget(covariant _StudentDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.student.clientId != widget.student.clientId) {
      _score.clear();
      _error = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final TpSession? session = widget.student.session;
    final int progress = _progressPercent(session);
    return DecoratedBox(
      key: Key('supervision-student-detail-' + widget.student.clientId),
      decoration: BoxDecoration(
        color: ElectroSimColors.background,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.student.displayName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: ElectroSimSpacing.xxs),
                      Text(
                        widget.student.connected
                            ? 'Suivi en direct — élève connecté'
                            : 'Dernier état reçu — élève déconnecté',
                      ),
                    ],
                  ),
                ),
                Text(
                  progress.toString() + '%',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: ElectroSimSpacing.sm),
            LinearProgressIndicator(
              key: Key(
                'supervision-detail-progress-' + widget.student.clientId,
              ),
              value: progress / 100,
            ),
            const SizedBox(height: ElectroSimSpacing.md),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final Widget circuit = _LiveCircuitSection(
                  student: widget.student,
                );
                final Widget details = _StudentWorkDetails(
                  student: widget.student,
                  scoreController: _score,
                  scoreError: _error,
                  onGrade: _submitGrade,
                  onClose: widget.onCloseStudent == null
                      ? null
                      : () => widget.onCloseStudent!(
                            widget.student.clientId,
                          ),
                );
                if (constraints.maxWidth < 800) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      circuit,
                      const SizedBox(height: ElectroSimSpacing.md),
                      details,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(flex: 6, child: circuit),
                    const SizedBox(width: ElectroSimSpacing.md),
                    Expanded(flex: 5, child: details),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _submitGrade() {
    final TpSession? session = widget.student.session;
    final ValueChanged<F17StudentGradeRequest>? callback =
        widget.onGradeStudent;
    if (session == null || callback == null) return;
    final String raw = _score.text.trim();
    final int? score = raw.isEmpty ? null : int.tryParse(raw);
    if (raw.isNotEmpty && score == null) {
      setState(() {
        _error = 'Saisissez un nombre entier.';
      });
      return;
    }
    if (score != null &&
        (score < 0 || score > session.definition.maxScore)) {
      setState(() {
        _error =
            'Note comprise entre 0 et ' +
            session.definition.maxScore.toString() +
            '.';
      });
      return;
    }
    setState(() {
      _error = null;
    });
    callback(
      F17StudentGradeRequest(
        clientId: widget.student.clientId,
        score: score,
      ),
    );
  }

  @override
  void dispose() {
    _score.dispose();
    super.dispose();
  }
}

class _LiveCircuitSection extends StatelessWidget {
  const _LiveCircuitSection({required this.student});

  final F17StudentSupervisionItem student;

  @override
  Widget build(BuildContext context) {
    final TpSession? session = student.session;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Montage actuel',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: ElectroSimSpacing.xs),
        Text(
          'Dernière activité reçue : ' +
              _formatActivityTime(student.lastActivityAtUtc),
        ),
        const SizedBox(height: ElectroSimSpacing.sm),
        SizedBox(
          height: 300,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: ElectroSimColors.surfaceElevated,
              borderRadius: BorderRadius.circular(ElectroSimRadii.card),
              border: Border.all(color: ElectroSimColors.outline),
            ),
            child: session == null
                ? const Center(
                    child: Text('Aucun montage élève disponible.'),
                  )
                : ClipRRect(
                    borderRadius:
                        BorderRadius.circular(ElectroSimRadii.card),
                    child: _LiveCircuitPreview(
                      key: Key(
                        'supervision-live-circuit-' + student.clientId,
                      ),
                      circuit: session.studentCircuit,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _LiveCircuitPreview extends StatefulWidget {
  const _LiveCircuitPreview({
    super.key,
    required this.circuit,
  });

  final CircuitState circuit;

  @override
  State<_LiveCircuitPreview> createState() => _LiveCircuitPreviewState();
}

class _LiveCircuitPreviewState extends State<_LiveCircuitPreview> {
  late final ViewportController _viewport =
      ViewportController(scale: .62, translation: const Offset(18, 18));

  @override
  Widget build(BuildContext context) {
    return SimulatorCanvas(
      circuit: widget.circuit,
      layout: _previewLayout(widget.circuit),
      viewportController: _viewport,
      enableInteraction: false,
      paintElementChrome: true,
    );
  }

  @override
  void dispose() {
    _viewport.dispose();
    super.dispose();
  }
}

class _StudentWorkDetails extends StatelessWidget {
  const _StudentWorkDetails({
    required this.student,
    required this.scoreController,
    required this.scoreError,
    required this.onGrade,
    required this.onClose,
  });

  final F17StudentSupervisionItem student;
  final TextEditingController scoreController;
  final String? scoreError;
  final VoidCallback onGrade;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final TpSession? session = student.session;
    if (session == null) {
      return const Text('Aucun TP publié pour cet élève.');
    }
    final TpLifecycle lifecycle = session.lifecycle;
    final List<DiagnosticEntry> entries = session.diagnosticSheet.entries;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Travail en cours',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: ElectroSimSpacing.sm),
        _DetailLine(label: 'État', value: _activityLabel(session)),
        _DetailLine(
          label: 'Activité',
          value: _modeLabel(session.definition.mode),
        ),
        _DetailLine(
          label: 'Circuit',
          value: 'révision ' + session.studentCircuit.revision.toString(),
        ),
        _DetailLine(
          label: 'Éléments',
          value: (session.studentCircuit.sources.length +
                  session.studentCircuit.components.length)
              .toString(),
        ),
        _DetailLine(
          label: 'Liaisons',
          value: session.studentCircuit.connections.length.toString(),
        ),
        _DetailLine(
          label: 'Diagnostic',
          value: entries.length.toString() + ' entrée(s)',
        ),
        const SizedBox(height: ElectroSimSpacing.sm),
        if (entries.isNotEmpty) ...<Widget>[
          Text(
            'Fiche diagnostic',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: ElectroSimSpacing.xs),
          ...entries.map(
            (DiagnosticEntry entry) => Padding(
              padding: const EdgeInsets.only(
                bottom: ElectroSimSpacing.xs,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: ElectroSimColors.surfaceElevated,
                  borderRadius:
                      BorderRadius.circular(ElectroSimRadii.compact),
                  border: Border.all(color: ElectroSimColors.outline),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(ElectroSimSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        entry.promptId,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: ElectroSimSpacing.xxs),
                      Text(entry.answer),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        if (session.evaluation != null) ...<Widget>[
          const Divider(height: ElectroSimSpacing.lg),
          Text(
            lifecycle == TpLifecycle.submitted
                ? 'Évaluation automatique'
                : 'Résultat',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: ElectroSimSpacing.xs),
          Text(
            (lifecycle == TpLifecycle.submitted
                    ? 'Score automatique : '
                    : 'Note : ') +
                session.evaluation!.score.toString() +
                '/' +
                session.definition.maxScore.toString(),
            key: Key('supervision-student-score-' + student.clientId),
          ),
          _DetailLine(
            label: 'Fonctionnel',
            value: session.evaluation!.functional ? 'Oui' : 'Non',
          ),
          _DetailLine(
            label: 'Sécurité',
            value: session.evaluation!.safetyOk ? 'Oui' : 'Non',
          ),
          _DetailLine(
            label: 'Mesures',
            value: session.evaluation!.measurementsOk ? 'Oui' : 'Non',
          ),
        ],
        if (lifecycle == TpLifecycle.submitted) ...<Widget>[
          const SizedBox(height: ElectroSimSpacing.md),
          TextField(
            key: Key('supervision-grade-input-' + student.clientId),
            controller: scoreController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText:
                  'Note professeur / ' +
                  session.definition.maxScore.toString(),
              errorText: scoreError,
            ),
          ),
          const SizedBox(height: ElectroSimSpacing.sm),
          FilledButton.icon(
            key: Key('supervision-grade-submit-' + student.clientId),
            onPressed: onGrade,
            icon: const Icon(Icons.grading_outlined),
            label: const Text('Valider la note'),
          ),
        ],
        if (lifecycle == TpLifecycle.evaluated && onClose != null) ...<Widget>[
          const SizedBox(height: ElectroSimSpacing.sm),
          OutlinedButton.icon(
            key: Key('supervision-close-student-' + student.clientId),
            onPressed: onClose,
            icon: const Icon(Icons.lock_outline),
            label: const Text('Clôturer le résultat'),
          ),
        ],
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ElectroSimSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

CircuitVisualLayout _previewLayout(CircuitState circuit) {
  final List<String> ids = <String>[
    ...circuit.sources.map((SourceInstance item) => item.id.value),
    ...circuit.components.map((ComponentInstance item) => item.id.value),
  ];
  final Map<String, Offset> positions = <String, Offset>{};
  for (var index = 0; index < ids.length; index++) {
    final int column = index % 3;
    final int row = index ~/ 3;
    positions[ids[index]] = Offset(
      90 + (column * 190.0),
      80 + (row * 130.0),
    );
  }
  return CircuitVisualLayout(elementPositions: positions);
}

bool _needsAttention(F17StudentSupervisionItem student) {
  if (!student.connected) return true;
  return student.session?.lifecycle == TpLifecycle.submitted;
}

String _attentionLabel(F17StudentSupervisionItem student) {
  if (!student.connected) return 'Hors ligne';
  if (student.session?.lifecycle == TpLifecycle.submitted) return 'À noter';
  return 'RAS';
}

int _progressPercent(TpSession? session) {
  if (session == null) return 0;
  return switch (session.lifecycle) {
    TpLifecycle.draft => 0,
    TpLifecycle.published => 10,
    TpLifecycle.started => session.definition.mode == TpMode.troubleshooting
        ? (35 + (session.diagnosticSheet.entries.length * 12))
            .clamp(35, 75)
            .toInt()
        : 55,
    TpLifecycle.submitted => 85,
    TpLifecycle.evaluated => 95,
    TpLifecycle.closed => 100,
  };
}

String _activityLabel(TpSession? session) {
  if (session == null) return 'En attente';
  return switch (session.lifecycle) {
    TpLifecycle.draft => 'Préparation',
    TpLifecycle.published => 'Publié — attente',
    TpLifecycle.started => 'TP en cours',
    TpLifecycle.submitted => 'TP remis — à noter',
    TpLifecycle.evaluated => 'TP noté',
    TpLifecycle.closed => 'TP clôturé',
  };
}

String _modeLabel(TpMode mode) => switch (mode) {
  TpMode.troubleshooting => 'Recherche de dérangement',
  TpMode.wiring => 'Câblage',
};

String _lifecycleLabel(TpLifecycle lifecycle) => switch (lifecycle) {
  TpLifecycle.draft => 'Brouillon',
  TpLifecycle.published => 'Publié — en attente élève',
  TpLifecycle.started => 'TP en cours',
  TpLifecycle.submitted => 'TP remis — à noter',
  TpLifecycle.evaluated => 'TP noté',
  TpLifecycle.closed => 'TP clôturé',
};

IconData _statusIcon(TpLifecycle lifecycle) => switch (lifecycle) {
  TpLifecycle.draft => Icons.edit_note_outlined,
  TpLifecycle.published => Icons.publish_outlined,
  TpLifecycle.started => Icons.play_circle_outline,
  TpLifecycle.submitted => Icons.mark_email_read_outlined,
  TpLifecycle.evaluated => Icons.grading_outlined,
  TpLifecycle.closed => Icons.lock_outline,
};

String _formatActivityTime(DateTime? value) {
  if (value == null) return '—';
  final DateTime local = value.toLocal();
  final String h = local.hour.toString().padLeft(2, '0');
  final String m = local.minute.toString().padLeft(2, '0');
  final String s = local.second.toString().padLeft(2, '0');
  return h + ':' + m + ':' + s;
}
