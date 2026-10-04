import 'package:electrosim_tp/electrosim_tp.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';

import 'runtime/electrosim_tp_session_controller.dart';

final class F17StudentSupervisionItem {
  const F17StudentSupervisionItem({
    required this.clientId,
    required this.displayName,
    required this.connected,
    required this.session,
    this.lastActivityAtUtc,
  });

  final String clientId;
  final String displayName;
  final bool connected;
  final TpSession? session;
  final DateTime? lastActivityAtUtc;
}

final class F17StudentGradeRequest {
  const F17StudentGradeRequest({
    required this.clientId,
    required this.score,
  });

  final String clientId;
  final int? score;
}

class F17TpSupervisionPanel extends StatelessWidget {
  const F17TpSupervisionPanel({
    super.key,
    required this.controller,
    this.students = const <F17StudentSupervisionItem>[],
    this.onGradeStudent,
    this.onCloseStudent,
  });

  final ElectroSimTpSessionController controller;
  final List<F17StudentSupervisionItem> students;
  final ValueChanged<F17StudentGradeRequest>? onGradeStudent;
  final ValueChanged<String>? onCloseStudent;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: ElectroSimColors.surfaceElevated,
      child: AnimatedBuilder(
        animation: controller,
        builder: (BuildContext context, Widget? child) {
          final TpSession? session = controller.session;
          final int connected =
              students.where((F17StudentSupervisionItem s) => s.connected).length;
          final int submitted = students.where((F17StudentSupervisionItem s) {
            final TpLifecycle? lifecycle = s.session?.lifecycle;
            return lifecycle == TpLifecycle.submitted ||
                lifecycle == TpLifecycle.evaluated ||
                lifecycle == TpLifecycle.closed;
          }).length;
          final int graded = students.where((F17StudentSupervisionItem s) {
            final TpLifecycle? lifecycle = s.session?.lifecycle;
            return lifecycle == TpLifecycle.evaluated ||
                lifecycle == TpLifecycle.closed;
          }).length;

          return ListView(
            key: const Key('tp-supervision-panel'),
            padding: const EdgeInsets.all(ElectroSimSpacing.md),
            children: <Widget>[
              const ElectroSimSectionTitle(
                title: 'Supervision',
                subtitle: 'État réel de la séance et progression individuelle',
              ),
              const SizedBox(height: ElectroSimSpacing.md),
              _SummaryStrip(
                connected: connected,
                total: students.length,
                submitted: submitted,
                graded: graded,
              ),
              const SizedBox(height: ElectroSimSpacing.md),
              if (session == null) ...<Widget>[
                const ElectroSimStatusChip(
                  label: 'Aucun TP actif',
                  icon: Icons.assignment_outlined,
                ),
                const SizedBox(height: ElectroSimSpacing.sm),
                const Text(
                  'Créez puis publiez un TP depuis « Gérer la session ».',
                ),
              ] else ...<Widget>[
                ElectroSimStatusChip(
                  key: const Key('supervision-lifecycle'),
                  label: _lifecycleLabel(session.lifecycle),
                  icon: _statusIcon(session.lifecycle),
                  emphasized: session.lifecycle != TpLifecycle.draft,
                ),
                const SizedBox(height: ElectroSimSpacing.md),
                Text(
                  session.definition.title,
                  key: const Key('supervision-title'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: ElectroSimSpacing.sm),
                _SupervisionLine(
                  label: 'TP',
                  value: session.definition.id.value,
                ),
                _SupervisionLine(
                  label: 'Mode',
                  value: session.definition.mode == TpMode.troubleshooting
                      ? 'Recherche de dérangement'
                      : 'Câblage',
                ),
                if (session.evaluation != null) ...<Widget>[
                  const Divider(height: ElectroSimSpacing.lg),
                  Text(
                    'Résultat global',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: ElectroSimSpacing.xs),
                  _SupervisionLine(
                    label: 'Note',
                    value:
                        '${session.evaluation!.score}/${session.definition.maxScore}',
                    valueKey: const Key('supervision-score'),
                  ),
                  _SupervisionLine(
                    label: 'Fonctionnel',
                    value: session.evaluation!.functional ? 'Oui' : 'Non',
                  ),
                  _SupervisionLine(
                    label: 'Sécurité',
                    value: session.evaluation!.safetyOk ? 'Oui' : 'Non',
                  ),
                  _SupervisionLine(
                    label: 'Mesures',
                    value: session.evaluation!.measurementsOk ? 'Oui' : 'Non',
                  ),
                ],
              ],
              const Divider(height: ElectroSimSpacing.xl),
              Text(
                'Élèves',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: ElectroSimSpacing.sm),
              if (students.isEmpty)
                const Text(
                  'Aucun élève n’a encore rejoint cette séance.',
                  key: Key('supervision-no-students'),
                )
              else
                ...students.map(
                  (F17StudentSupervisionItem student) =>
                      _StudentSupervisionCard(
                    key: ValueKey<String>(
                      'supervision-student-${student.clientId}',
                    ),
                    student: student,
                    onGradeStudent: onGradeStudent,
                    onCloseStudent: onCloseStudent,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static String _lifecycleLabel(TpLifecycle lifecycle) => switch (lifecycle) {
        TpLifecycle.draft => 'Brouillon',
        TpLifecycle.published => 'Publié — en attente élève',
        TpLifecycle.started => 'TP en cours',
        TpLifecycle.submitted => 'TP remis — à noter',
        TpLifecycle.evaluated => 'TP noté',
        TpLifecycle.closed => 'TP clôturé',
      };

  static IconData _statusIcon(TpLifecycle lifecycle) => switch (lifecycle) {
        TpLifecycle.draft => Icons.edit_note_outlined,
        TpLifecycle.published => Icons.publish_outlined,
        TpLifecycle.started => Icons.play_circle_outline,
        TpLifecycle.submitted => Icons.mark_email_read_outlined,
        TpLifecycle.evaluated => Icons.grading_outlined,
        TpLifecycle.closed => Icons.lock_outline,
      };
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.connected,
    required this.total,
    required this.submitted,
    required this.graded,
  });

  final int connected;
  final int total;
  final int submitted;
  final int graded;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: ElectroSimSpacing.sm,
      runSpacing: ElectroSimSpacing.sm,
      children: <Widget>[
        _SummaryChip(
          key: const Key('supervision-connected-count'),
          icon: Icons.people_outline,
          label: 'Connectés',
          value: '$connected/$total',
        ),
        _SummaryChip(
          key: const Key('supervision-submitted-count'),
          icon: Icons.mark_email_read_outlined,
          label: 'Remis',
          value: '$submitted/$total',
        ),
        _SummaryChip(
          key: const Key('supervision-graded-count'),
          icon: Icons.grading_outlined,
          label: 'Notés',
          value: '$graded/$total',
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ElectroSimColors.background,
        borderRadius: BorderRadius.circular(ElectroSimRadii.card),
        border: Border.all(color: ElectroSimColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ElectroSimSpacing.md,
          vertical: ElectroSimSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 18),
            const SizedBox(width: ElectroSimSpacing.xs),
            Text('$label : $value'),
          ],
        ),
      ),
    );
  }
}

class _StudentSupervisionCard extends StatefulWidget {
  const _StudentSupervisionCard({
    super.key,
    required this.student,
    required this.onGradeStudent,
    required this.onCloseStudent,
  });

  final F17StudentSupervisionItem student;
  final ValueChanged<F17StudentGradeRequest>? onGradeStudent;
  final ValueChanged<String>? onCloseStudent;

  @override
  State<_StudentSupervisionCard> createState() =>
      _StudentSupervisionCardState();
}

class _StudentSupervisionCardState extends State<_StudentSupervisionCard> {
  final TextEditingController _score = TextEditingController();
  String? _error;

  @override
  Widget build(BuildContext context) {
    final TpSession? session = widget.student.session;
    final TpLifecycle? lifecycle = session?.lifecycle;
    return Card(
      margin: const EdgeInsets.only(bottom: ElectroSimSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(ElectroSimSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  widget.student.connected
                      ? Icons.check_circle_outline
                      : Icons.cloud_off_outlined,
                  size: 20,
                ),
                const SizedBox(width: ElectroSimSpacing.xs),
                Expanded(
                  child: Text(
                    widget.student.displayName,
                    key: Key(
                      'supervision-student-name-${widget.student.clientId}',
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  widget.student.connected ? 'Connecté' : 'Déconnecté',
                  key: Key(
                    'supervision-student-connection-${widget.student.clientId}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: ElectroSimSpacing.sm),
            Text(
              session == null
                  ? 'En attente d’un TP publié'
                  : _studentLifecycleLabel(lifecycle!),
              key: Key(
                'supervision-student-state-${widget.student.clientId}',
              ),
            ),
            if (session?.evaluation != null) ...<Widget>[
              const SizedBox(height: ElectroSimSpacing.xs),
              Text(
                lifecycle == TpLifecycle.submitted
                    ? 'Score automatique : ${session!.evaluation!.score}/${session.definition.maxScore}'
                    : 'Note : ${session!.evaluation!.score}/${session.definition.maxScore}',
                key: Key(
                  'supervision-student-score-${widget.student.clientId}',
                ),
              ),
            ],
            if (lifecycle == TpLifecycle.submitted &&
                widget.onGradeStudent != null) ...<Widget>[
              const SizedBox(height: ElectroSimSpacing.md),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final Widget field = TextField(
                    key: Key(
                      'supervision-grade-input-${widget.student.clientId}',
                    ),
                    controller: _score,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText:
                          'Note professeur / ${session!.definition.maxScore}',
                      errorText: _error,
                    ),
                  );
                  final Widget button = FilledButton.icon(
                    key: Key(
                      'supervision-grade-submit-${widget.student.clientId}',
                    ),
                    onPressed: _submitGrade,
                    icon: const Icon(Icons.grading_outlined),
                    label: const Text('Valider la note'),
                  );
                  if (constraints.maxWidth < 560) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        field,
                        const SizedBox(height: ElectroSimSpacing.sm),
                        button,
                      ],
                    );
                  }
                  return Row(
                    children: <Widget>[
                      Expanded(child: field),
                      const SizedBox(width: ElectroSimSpacing.sm),
                      button,
                    ],
                  );
                },
              ),
            ],
            if (lifecycle == TpLifecycle.evaluated &&
                widget.onCloseStudent != null) ...<Widget>[
              const SizedBox(height: ElectroSimSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: Key(
                    'supervision-close-student-${widget.student.clientId}',
                  ),
                  onPressed: () =>
                      widget.onCloseStudent!(widget.student.clientId),
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Clôturer le résultat'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _submitGrade() {
    final TpSession? session = widget.student.session;
    if (session == null) return;
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
        _error = 'Note comprise entre 0 et ${session.definition.maxScore}.';
      });
      return;
    }
    setState(() {
      _error = null;
    });
    widget.onGradeStudent!(
      F17StudentGradeRequest(
        clientId: widget.student.clientId,
        score: score,
      ),
    );
  }

  static String _studentLifecycleLabel(TpLifecycle lifecycle) =>
      switch (lifecycle) {
        TpLifecycle.draft => 'TP en préparation',
        TpLifecycle.published => 'Publié — en attente du démarrage',
        TpLifecycle.started => 'TP en cours',
        TpLifecycle.submitted => 'TP remis — à noter',
        TpLifecycle.evaluated => 'TP noté — lecture seule',
        TpLifecycle.closed => 'TP clôturé — lecture seule',
      };

  @override
  void dispose() {
    _score.dispose();
    super.dispose();
  }
}

class _SupervisionLine extends StatelessWidget {
  const _SupervisionLine({
    required this.label,
    required this.value,
    this.valueKey,
  });

  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ElectroSimSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          Expanded(
            child: Text(value, key: valueKey),
          ),
        ],
      ),
    );
  }
}
