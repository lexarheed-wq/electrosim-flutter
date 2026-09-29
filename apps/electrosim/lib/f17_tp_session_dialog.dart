import 'package:electrosim_tp/electrosim_tp.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';

import 'f9_ui_context.dart';
import 'runtime/electrosim_tp_session_controller.dart';

class F17TpSessionDialog extends StatefulWidget {
  const F17TpSessionDialog({
    super.key,
    required this.controller,
    required this.role,
    required this.onStudentStarted,
  });

  final ElectroSimTpSessionController controller;
  final F9UserRole role;
  final ValueChanged<TpSession> onStudentStarted;

  @override
  State<F17TpSessionDialog> createState() => _F17TpSessionDialogState();
}

class _F17TpSessionDialogState extends State<F17TpSessionDialog> {
  final TextEditingController _score = TextEditingController();

  bool get _teacher => widget.role == F9UserRole.teacher;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gérer la session'),
      content: SizedBox(
        width: 480,
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (BuildContext context, Widget? child) {
            final TpSession? current = widget.controller.session;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ElectroSimStatusChip(
                  key: const Key('tp-lifecycle-status'),
                  label: current == null
                      ? 'Aucun TP'
                      : _lifecycleLabel(current.lifecycle),
                  icon: Icons.assignment_outlined,
                  emphasized: current != null,
                ),
                const SizedBox(height: ElectroSimSpacing.md),
                if (current == null)
                  const Text(
                    'Aucune activité n’est encore créée pour cette session.',
                  )
                else ...<Widget>[
                  Text(
                    current.definition.title,
                    key: const Key('tp-session-title'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: ElectroSimSpacing.xs),
                  Text(
                    'Mode : ${current.definition.mode == TpMode.troubleshooting ? 'Recherche de dérangement' : 'Câblage'}',
                  ),
                  Text('État : ${_lifecycleLabel(current.lifecycle)}'),
                  Text('Lecture seule : ${current.readOnly ? 'oui' : 'non'}'),
                  if (current.evaluation != null) ...<Widget>[
                    const SizedBox(height: ElectroSimSpacing.sm),
                    Text(
                      'Score : ${current.evaluation!.score}/${current.definition.maxScore}',
                      key: const Key('tp-score-label'),
                    ),
                    Text(
                      'Fonctionnel : ${current.evaluation!.functional ? 'oui' : 'non'} · '
                      'Sécurité : ${current.evaluation!.safetyOk ? 'oui' : 'non'} · '
                      'Mesures : ${current.evaluation!.measurementsOk ? 'oui' : 'non'}',
                    ),
                  ],
                ],
                const SizedBox(height: ElectroSimSpacing.md),
                if (_teacher) ..._teacherActions(current),
                if (!_teacher) ..._studentActions(current),
              ],
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }

  List<Widget> _teacherActions(TpSession? session) {
    if (session == null) {
      return <Widget>[
        FilledButton.icon(
          key: const Key('tp-create-draft'),
          onPressed: () => widget.controller.createDraft(),
          icon: const Icon(Icons.add_task_outlined),
          label: const Text('Créer le TP'),
        ),
      ];
    }
    switch (session.lifecycle) {
      case TpLifecycle.draft:
        return <Widget>[
          FilledButton.icon(
            key: const Key('tp-publish'),
            onPressed: widget.controller.publish,
            icon: const Icon(Icons.publish_outlined),
            label: const Text('Publier'),
          ),
        ];
      case TpLifecycle.submitted:
        return <Widget>[
          TextField(
            key: const Key('tp-teacher-score'),
            controller: _score,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Note professeur / ${session.definition.maxScore}',
              hintText: '${session.evaluation?.score ?? 0}',
            ),
          ),
          const SizedBox(height: ElectroSimSpacing.sm),
          FilledButton.icon(
            key: const Key('tp-evaluate'),
            onPressed: () {
              final String raw = _score.text.trim();
              final int? score = raw.isEmpty ? null : int.tryParse(raw);
              if (raw.isNotEmpty && score == null) {
                _showError('La note doit être un nombre entier.');
                return;
              }
              try {
                widget.controller.evaluateTeacher(score: score);
              } on RangeError {
                _showError(
                  'La note doit être comprise entre 0 et ${session.definition.maxScore}.',
                );
              }
            },
            icon: const Icon(Icons.grading_outlined),
            label: const Text('Valider la note'),
          ),
        ];
      case TpLifecycle.evaluated:
        return <Widget>[
          FilledButton.icon(
            key: const Key('tp-close'),
            onPressed: widget.controller.closeTeacher,
            icon: const Icon(Icons.lock_outline),
            label: const Text('Clôturer le TP'),
          ),
        ];
      case TpLifecycle.published:
      case TpLifecycle.started:
      case TpLifecycle.closed:
        return const <Widget>[];
    }
  }

  List<Widget> _studentActions(TpSession? session) {
    if (session == null) {
      return const <Widget>[
        Text('Aucun TP publié par le professeur.'),
      ];
    }
    switch (session.lifecycle) {
      case TpLifecycle.published:
        return <Widget>[
          FilledButton.icon(
            key: const Key('tp-student-start'),
            onPressed: () {
              final TpSession started = widget.controller.startStudent();
              widget.onStudentStarted(started);
            },
            icon: const Icon(Icons.play_arrow_outlined),
            label: const Text('Commencer le TP'),
          ),
        ];
      case TpLifecycle.started:
        return <Widget>[
          FilledButton.icon(
            key: const Key('tp-student-submit'),
            onPressed: widget.controller.submitStudent,
            icon: const Icon(Icons.send_outlined),
            label: const Text('Remettre le TP'),
          ),
        ];
      case TpLifecycle.submitted:
      case TpLifecycle.evaluated:
      case TpLifecycle.closed:
        return const <Widget>[
          Text(
            'Le TP a été remis. Le montage est désormais en lecture seule.',
            key: Key('tp-student-readonly-message'),
          ),
        ];
      case TpLifecycle.draft:
        return const <Widget>[
          Text('Le TP est encore en préparation par le professeur.'),
        ];
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static String _lifecycleLabel(TpLifecycle lifecycle) => switch (lifecycle) {
    TpLifecycle.draft => 'Brouillon',
    TpLifecycle.published => 'Publié',
    TpLifecycle.started => 'En cours',
    TpLifecycle.submitted => 'Remis',
    TpLifecycle.evaluated => 'Noté',
    TpLifecycle.closed => 'Clôturé',
  };

  @override
  void dispose() {
    _score.dispose();
    super.dispose();
  }
}
