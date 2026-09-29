import 'package:electrosim_tp/electrosim_tp.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';

import 'runtime/electrosim_tp_session_controller.dart';

class F17TpSupervisionPanel extends StatelessWidget {
  const F17TpSupervisionPanel({
    super.key,
    required this.controller,
  });

  final ElectroSimTpSessionController controller;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: ElectroSimColors.surfaceElevated,
      child: AnimatedBuilder(
        animation: controller,
        builder: (BuildContext context, Widget? child) {
          final TpSession? session = controller.session;
          return ListView(
            key: const Key('tp-supervision-panel'),
            padding: const EdgeInsets.all(ElectroSimSpacing.md),
            children: <Widget>[
              const ElectroSimSectionTitle(
                title: 'Supervision',
                subtitle: 'État réel du TP partagé',
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
                _SupervisionLine(
                  label: 'Modification',
                  value: session.readOnly ? 'Lecture seule' : 'Autorisée',
                ),
                _SupervisionLine(
                  label: 'Révision circuit',
                  value: '${session.studentCircuit.revision}',
                ),
                if (session.evaluation != null) ...<Widget>[
                  const Divider(height: ElectroSimSpacing.xl),
                  Text(
                    'Résultat',
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
