import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';

final class F18SessionCreationDraft {
  const F18SessionCreationDraft({required this.name});

  final String name;
}

class F18CreateSessionDialog extends StatefulWidget {
  const F18CreateSessionDialog({super.key});

  @override
  State<F18CreateSessionDialog> createState() => _F18CreateSessionDialogState();
}

class _F18CreateSessionDialogState extends State<F18CreateSessionDialog> {
  final TextEditingController _name =
      TextEditingController(text: 'Nouvelle session');
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('session-create-dialog'),
      title: const Text('Créer une nouvelle session'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Configurez la session avant d’ouvrir le tableau de bord professeur.',
            ),
            const SizedBox(height: ElectroSimSpacing.md),
            TextField(
              key: const Key('session-create-name'),
              controller: _name,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Nom de la session',
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: const Key('session-create-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          key: const Key('session-create-confirm'),
          onPressed: _submit,
          child: const Text('Créer la session'),
        ),
      ],
    );
  }

  void _submit() {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(() {
        _error = 'Le nom de la session est obligatoire.';
      });
      return;
    }
    Navigator.of(context).pop(F18SessionCreationDraft(name: name));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }
}

class F18SessionWaitingRoomPage extends StatelessWidget {
  const F18SessionWaitingRoomPage({
    super.key,
    required this.sessionName,
    required this.sessionCode,
    required this.connectedStudents,
    required this.onHome,
    required this.onContinue,
    this.onEnableSharing,
    this.sharingStatus,
  });

  final String sessionName;
  final String sessionCode;
  final int connectedStudents;
  final VoidCallback onHome;
  final VoidCallback onContinue;
  final VoidCallback? onEnableSharing;
  final String? sharingStatus;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('session-waiting-room-page'),
      backgroundColor: ElectroSimColors.background,
      appBar: AppBar(
        leading: IconButton(
          key: const Key('session-waiting-home'),
          tooltip: 'Accueil',
          onPressed: onHome,
          icon: const Icon(Icons.home_outlined),
        ),
        title: Text(sessionName),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(ElectroSimSpacing.xl),
              shrinkWrap: true,
              children: <Widget>[
                Text(
                  'Salle d’attente',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: ElectroSimSpacing.sm),
                Text(
                  'La session est créée. Les élèves peuvent rejoindre avant le démarrage de l’activité.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: ElectroSimColors.textSecondary,
                      ),
                ),
                const SizedBox(height: ElectroSimSpacing.xl),
                _WaitingInfoCard(
                  icon: Icons.pin_outlined,
                  label: 'Code de session',
                  value: sessionCode,
                  valueKey: const Key('session-waiting-code'),
                ),
                const SizedBox(height: ElectroSimSpacing.md),
                _WaitingInfoCard(
                  icon: Icons.people_outline,
                  label: 'Élèves connectés',
                  value: '$connectedStudents',
                  valueKey: const Key('session-waiting-connected'),
                ),
                if (sharingStatus != null) ...<Widget>[
                  const SizedBox(height: ElectroSimSpacing.md),
                  Text(
                    sharingStatus!,
                    key: const Key('session-waiting-sharing-status'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: ElectroSimSpacing.xl),
                Wrap(
                  spacing: ElectroSimSpacing.sm,
                  runSpacing: ElectroSimSpacing.sm,
                  children: <Widget>[
                    if (onEnableSharing != null)
                      OutlinedButton.icon(
                        key: const Key('session-waiting-enable-sharing'),
                        onPressed: onEnableSharing,
                        icon: const Icon(Icons.wifi_tethering_outlined),
                        label: const Text('Activer le partage réseau'),
                      ),
                    FilledButton.icon(
                      key: const Key('session-waiting-continue'),
                      onPressed: onContinue,
                      icon: const Icon(Icons.dashboard_outlined),
                      label: const Text('Ouvrir le tableau de bord'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WaitingInfoCard extends StatelessWidget {
  const _WaitingInfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueKey,
  });

  final IconData icon;
  final String label;
  final String value;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ElectroSimColors.surfaceElevated,
        borderRadius: BorderRadius.circular(ElectroSimRadii.card),
        border: Border.all(color: ElectroSimColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ElectroSimSpacing.lg),
        child: Row(
          children: <Widget>[
            Icon(icon, color: ElectroSimColors.primary),
            const SizedBox(width: ElectroSimSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: ElectroSimSpacing.xxs),
                  Text(
                    value,
                    key: valueKey,
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
}

class F18ActivitySetupPage extends StatelessWidget {
  const F18ActivitySetupPage({
    super.key,
    required this.pageKey,
    required this.title,
    required this.description,
    required this.parentLabel,
    required this.onBack,
    required this.onOpenWorkshop,
  });

  final Key pageKey;
  final String title;
  final String description;
  final String parentLabel;
  final VoidCallback onBack;
  final VoidCallback onOpenWorkshop;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: pageKey,
      backgroundColor: ElectroSimColors.background,
      appBar: AppBar(
        leading: IconButton(
          key: const Key('activity-setup-back'),
          onPressed: onBack,
          tooltip: 'Retour à $parentLabel',
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(title),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.all(ElectroSimSpacing.xl),
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: ElectroSimSpacing.sm),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: ElectroSimColors.textSecondary,
                      ),
                ),
                const SizedBox(height: ElectroSimSpacing.xl),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: ElectroSimColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(ElectroSimRadii.card),
                    border: Border.all(color: ElectroSimColors.outline),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(ElectroSimSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Préparation de l’activité',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: ElectroSimSpacing.xs),
                        Text(
                          'Cette étape reste distincte de l’atelier afin de préserver le parcours V1 : préparation d’abord, simulation ensuite.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: ElectroSimSpacing.xl),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    key: const Key('activity-setup-open-workshop'),
                    onPressed: onOpenWorkshop,
                    icon: const Icon(Icons.electrical_services_outlined),
                    label: const Text('Ouvrir l’atelier'),
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

class F18StudentSituationValidationPage extends StatefulWidget {
  const F18StudentSituationValidationPage({
    super.key,
    required this.onBack,
    required this.onLaunch,
  });

  final VoidCallback onBack;
  final void Function(String referenceCircuit, String faultScenario) onLaunch;

  @override
  State<F18StudentSituationValidationPage> createState() =>
      _F18StudentSituationValidationPageState();
}

class _F18StudentSituationValidationPageState
    extends State<F18StudentSituationValidationPage> {
  final TextEditingController _reference = TextEditingController();
  final TextEditingController _fault = TextEditingController();

  bool get _canLaunch =>
      _reference.text.trim().isNotEmpty && _fault.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('student-situation-validation-page'),
      backgroundColor: ElectroSimColors.background,
      appBar: AppBar(
        leading: IconButton(
          key: const Key('student-validation-back'),
          onPressed: widget.onBack,
          tooltip: 'Retour au centre de maintenance',
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Validation en situation élève'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.all(ElectroSimSpacing.xl),
              children: <Widget>[
                Text(
                  'Préparer la situation',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: ElectroSimSpacing.sm),
                const Text(
                  'Sélectionnez le circuit de référence et le scénario de panne avant d’ouvrir l’atelier de diagnostic.',
                ),
                const SizedBox(height: ElectroSimSpacing.xl),
                TextField(
                  key: const Key('student-validation-reference'),
                  controller: _reference,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Circuit de référence',
                    hintText: 'Sélection ou identifiant du circuit',
                  ),
                ),
                const SizedBox(height: ElectroSimSpacing.md),
                TextField(
                  key: const Key('student-validation-fault'),
                  controller: _fault,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Scénario de panne',
                    hintText: 'Sélection ou identifiant de la panne',
                  ),
                ),
                const SizedBox(height: ElectroSimSpacing.xl),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    key: const Key('student-validation-launch'),
                    onPressed: _canLaunch
                        ? () => widget.onLaunch(
                              _reference.text.trim(),
                              _fault.text.trim(),
                            )
                        : null,
                    icon: const Icon(Icons.play_arrow_outlined),
                    label: const Text('Lancer la situation'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _reference.dispose();
    _fault.dispose();
    super.dispose();
  }
}
