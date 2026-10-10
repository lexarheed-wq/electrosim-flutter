import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_scenarios/electrosim_scenarios.dart';
import 'package:electrosim_tp/electrosim_tp.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';

import 'f9_ui_context.dart';
import 'runtime/electrosim_lan_sync.dart';
import 'runtime/electrosim_tp_session_controller.dart';

class F17TpSessionDialog extends StatefulWidget {
  const F17TpSessionDialog({
    super.key,
    required this.controller,
    required this.role,
    required this.onStudentStarted,
    this.draftMode = TpMode.troubleshooting,
    this.wiringReferenceCircuit,
    this.onEnableLanSharing,
    this.initialLanHostInfo,
    this.onCloseClassroomSession,
  });

  final ElectroSimTpSessionController controller;
  final F9UserRole role;
  final ValueChanged<TpSession> onStudentStarted;
  final TpMode draftMode;
  final CircuitState? wiringReferenceCircuit;
  final Future<ElectroSimLanHostInfo> Function()? onEnableLanSharing;
  final ElectroSimLanHostInfo? initialLanHostInfo;
  final VoidCallback? onCloseClassroomSession;

  @override
  State<F17TpSessionDialog> createState() => _F17TpSessionDialogState();
}

class _F17TpSessionDialogState extends State<F17TpSessionDialog> {
  final TextEditingController _score = TextEditingController();
  ElectroSimLanHostInfo? _lanInfo;
  String? _lanError;
  bool _startingLan = false;
  String? _selectedWiringExampleId;
  String? _selectedFaultScenarioId;
  late final List<ExampleDefinition> _wiringExamples =
      buildV2ProductExampleRepository().all;

  bool _hasWiredReference(CircuitState? circuit) =>
      circuit != null &&
      circuit.sources.isNotEmpty &&
      circuit.components.isNotEmpty &&
      circuit.connections.isNotEmpty;

  ExampleDefinition? get _selectedWiringExample {
    for (final ExampleDefinition example in _wiringExamples) {
      if (example.id.value == _selectedWiringExampleId) return example;
    }
    return null;
  }

  CircuitState? get _wiringReference =>
      _selectedWiringExample?.circuit ?? widget.wiringReferenceCircuit;

  @override
  void initState() {
    super.initState();
    _lanInfo = widget.initialLanHostInfo;
  }

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
                if (_teacher && widget.onEnableLanSharing != null) ...<Widget>[
                  _networkSharingSection(context),
                  const SizedBox(height: ElectroSimSpacing.md),
                ],
                if (_teacher &&
                    current != null &&
                    current.definition.mode != widget.draftMode) ...<Widget>[
                  const Text(
                    'Une activité d’un autre type est déjà présente dans '
                    'cette session. Terminez ou supprimez-la avant de '
                    'créer un nouveau TP.',
                  ),
                  const SizedBox(height: ElectroSimSpacing.sm),
                ],
                if (_teacher) ..._teacherActions(current),
                if (!_teacher) ..._studentActions(current),
              ],
            );
          },
        ),
      ),
      actions: <Widget>[
        if (_teacher && widget.onCloseClassroomSession != null)
          TextButton.icon(
            key: const Key('tp-close-classroom-session'),
            onPressed: () {
              widget.onCloseClassroomSession!();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Terminer la séance'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }

  Widget _networkSharingSection(BuildContext context) {
    final ElectroSimLanHostInfo? info = _lanInfo;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: ElectroSimColors.outline),
        borderRadius: BorderRadius.circular(ElectroSimRadii.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ElectroSimSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Partage réseau local',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: ElectroSimSpacing.xs),
            if (info == null)
              FilledButton.tonalIcon(
                key: const Key('tp-network-share'),
                onPressed: _startingLan ? null : _enableLanSharing,
                icon: const Icon(Icons.wifi_tethering_outlined),
                label: Text(
                  _startingLan
                      ? 'Activation…'
                      : 'Activer le partage professeur',
                ),
              )
            else ...<Widget>[
              Text(
                'Code : ${info.sessionCode}',
                key: const Key('tp-network-code'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: ElectroSimSpacing.xxs),
              SelectableText(
                info.preferredJoinUrl.toString(),
                key: const Key('tp-network-endpoint'),
              ),
              const SizedBox(height: ElectroSimSpacing.xxs),
              const Text(
                'Les élèves ouvrent cette adresse dans leur navigateur ou scannent le QR code de la salle d’attente.',
              ),
              if (info.endpoints.length > 1)
                Text(
                  'Adresses disponibles : ${info.endpoints.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
            if (_lanError != null) ...<Widget>[
              const SizedBox(height: ElectroSimSpacing.xs),
              Text(
                _lanError!,
                key: const Key('tp-network-error'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _enableLanSharing() async {
    final Future<ElectroSimLanHostInfo> Function()? callback =
        widget.onEnableLanSharing;
    if (callback == null || _startingLan) return;
    setState(() {
      _startingLan = true;
      _lanError = null;
    });
    try {
      final ElectroSimLanHostInfo info = await callback();
      if (!mounted) return;
      setState(() {
        _lanInfo = info;
        _startingLan = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _lanError = 'Partage réseau indisponible : $error';
        _startingLan = false;
      });
    }
  }

  List<Widget> _teacherActions(TpSession? session) {
    if (session == null) {
      final CircuitState? reference = _wiringReference;
      final bool needsReference =
          widget.draftMode == TpMode.wiring && !_hasWiredReference(reference);
      return <Widget>[
        Text(
          widget.draftMode == TpMode.wiring
              ? 'Créer un TP de câblage'
              : 'Créer un TP de recherche de dérangement',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: ElectroSimSpacing.sm),
        if (widget.draftMode == TpMode.wiring) ...<Widget>[
          if (_hasWiredReference(widget.wiringReferenceCircuit))
            const Text(
              'Montage de référence : circuit préparé dans l’atelier.',
            ),
          DropdownButton<String>(
            key: const Key('tp-wiring-reference-example'),
            isExpanded: true,
            value: _selectedWiringExampleId,
            hint: const Text('Ou choisir un schéma sain natif V2'),
            items: <DropdownMenuItem<String>>[
              for (final ExampleDefinition example in _wiringExamples)
                DropdownMenuItem<String>(
                  value: example.id.value,
                  child: Text(example.title),
                ),
            ],
            onChanged: (String? id) {
              setState(() {
                _selectedWiringExampleId = id;
              });
            },
          ),
          if (needsReference)
            const Text(
              'Choisissez un schéma V2 ou préparez votre montage '
              'dans l’atelier avant la publication.',
              key: Key('tp-wiring-reference-required'),
            ),
          const SizedBox(height: ElectroSimSpacing.sm),
        ] else ...<Widget>[
          DropdownButton<String>(
            key: const Key('tp-fault-scenario-select'),
            isExpanded: true,
            value: _selectedFaultScenarioId ??
                widget.controller.defaultFaultScenarioId,
            items: <DropdownMenuItem<String>>[
              for (final scenario in widget.controller.availableFaultScenarios)
                DropdownMenuItem<String>(
                  value: scenario.id.value,
                  child: Text(scenario.title),
                ),
            ],
            onChanged: (String? value) {
              setState(() {
                _selectedFaultScenarioId = value;
              });
            },
          ),
          const SizedBox(height: ElectroSimSpacing.sm),
        ],
        FilledButton.icon(
          key: const Key('tp-create-draft'),
          onPressed: needsReference
              ? null
              : () {
                  final ExampleDefinition? example = _selectedWiringExample;
                  try {
                    widget.controller.createDraft(
                      mode: widget.draftMode,
                      wiringReferenceCircuit: reference,
                      troubleshootingScenarioId: _selectedFaultScenarioId,
                      activityTitle: example == null
                          ? null
                          : 'TP de câblage — ${example.title}',
                    );
                  } on Object catch (error) {
                    _showError('Création du TP impossible : $error');
                  }
                },
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
          const SizedBox(height: ElectroSimSpacing.sm),
          OutlinedButton.icon(
            key: const Key('tp-delete'),
            onPressed: widget.controller.deleteTeacherActivity,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Supprimer l’activité'),
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
        return <Widget>[
          FilledButton.icon(
            key: const Key('tp-teacher-start'),
            onPressed: () {
              final TpSession started = widget.controller.startTeacher();
              widget.onStudentStarted(started);
            },
            icon: const Icon(Icons.play_arrow_outlined),
            label: const Text('Démarrer le TP'),
          ),
          const SizedBox(height: ElectroSimSpacing.sm),
          OutlinedButton.icon(
            key: const Key('tp-teacher-cancel'),
            onPressed: widget.controller.cancelTeacher,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Annuler le TP'),
          ),
          const SizedBox(height: ElectroSimSpacing.sm),
          OutlinedButton.icon(
            key: const Key('tp-delete'),
            onPressed: widget.controller.deleteTeacherActivity,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Supprimer l’activité'),
          ),
        ];
      case TpLifecycle.started:
        return <Widget>[
          OutlinedButton.icon(
            key: const Key('tp-teacher-cancel'),
            onPressed: widget.controller.cancelTeacher,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Annuler le TP'),
          ),
        ];
      case TpLifecycle.closed:
        return <Widget>[
          OutlinedButton.icon(
            key: const Key('tp-delete'),
            onPressed: widget.controller.deleteTeacherActivity,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Supprimer l’activité terminée'),
          ),
        ];
    }
  }

  List<Widget> _studentActions(TpSession? session) {
    if (session == null) {
      return const <Widget>[Text('Aucun TP publié par le professeur.')];
    }
    switch (session.lifecycle) {
      case TpLifecycle.published:
        return const <Widget>[
          Text(
            'Prêt — en attente du démarrage collectif par le professeur.',
            key: Key('tp-student-waiting-start'),
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
