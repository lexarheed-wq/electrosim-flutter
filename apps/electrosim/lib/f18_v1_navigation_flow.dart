import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
    this.joinUrl,
    this.connectedStudentNames = const <String>[],
    this.onEnableSharing,
    this.sharingStatus,
    this.canStart = true,
  });

  final String sessionName;
  final String sessionCode;
  final int connectedStudents;
  final Uri? joinUrl;
  final List<String> connectedStudentNames;
  final VoidCallback onHome;
  final VoidCallback onContinue;
  final VoidCallback? onEnableSharing;
  final String? sharingStatus;
  final bool canStart;

  @override
  Widget build(BuildContext context) {
    final Uri? browserUrl = joinUrl;
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
            constraints: const BoxConstraints(maxWidth: 980),
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
                  browserUrl == null
                      ? 'Préparation du serveur local ElectroSim…'
                      : 'Les élèves rejoignent directement avec leur navigateur. Aucune application n’est à installer et Internet n’est pas nécessaire.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: ElectroSimColors.textSecondary,
                      ),
                ),
                const SizedBox(height: ElectroSimSpacing.xl),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final bool compact = constraints.maxWidth < 720;
                    final Widget access = _StudentBrowserAccessCard(
                      sessionCode: sessionCode,
                      joinUrl: browserUrl,
                    );
                    final Widget roster = _ConnectedStudentsCard(
                      count: connectedStudents,
                      names: connectedStudentNames,
                    );
                    if (compact) {
                      return Column(
                        children: <Widget>[
                          access,
                          const SizedBox(height: ElectroSimSpacing.md),
                          roster,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(child: access),
                        const SizedBox(width: ElectroSimSpacing.md),
                        Expanded(child: roster),
                      ],
                    );
                  },
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
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: ElectroSimColors.surfaceElevated,
            border: Border(
              top: BorderSide(color: ElectroSimColors.outline),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ElectroSimSpacing.xl,
              vertical: ElectroSimSpacing.md,
            ),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: ElectroSimSpacing.sm,
              runSpacing: ElectroSimSpacing.sm,
              children: <Widget>[
                if (browserUrl == null && onEnableSharing != null)
                  OutlinedButton.icon(
                    key: const Key('session-waiting-enable-sharing'),
                    onPressed: onEnableSharing,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer le serveur local'),
                  ),
                FilledButton.icon(
                  key: const Key('session-waiting-continue'),
                  onPressed: canStart ? onContinue : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Démarrer la séance'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentBrowserAccessCard extends StatelessWidget {
  const _StudentBrowserAccessCard({
    required this.sessionCode,
    required this.joinUrl,
  });

  final String sessionCode;
  final Uri? joinUrl;

  @override
  Widget build(BuildContext context) {
    final Uri? url = joinUrl;
    return DecoratedBox(
      key: const Key('session-browser-access-card'),
      decoration: BoxDecoration(
        color: ElectroSimColors.surfaceElevated,
        borderRadius: BorderRadius.circular(ElectroSimRadii.card),
        border: Border.all(color: ElectroSimColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ElectroSimSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Connexion élève',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: ElectroSimSpacing.sm),
            const Text(
              '1. Connectez le téléphone au même Wi-Fi que le professeur.\n'
              '2. Scannez le QR code.\n'
              '3. Le navigateur charge automatiquement ElectroSim Élève.',
            ),
            const SizedBox(height: ElectroSimSpacing.lg),
            Center(
              child: url == null
                  ? const SizedBox(
                      width: 180,
                      height: 180,
                      child: Center(
                        child: Icon(
                          Icons.qr_code_2_outlined,
                          size: 96,
                          color: ElectroSimColors.textSecondary,
                        ),
                      ),
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: QrImageView(
                          key: const Key('session-waiting-qr'),
                          data: url.toString(),
                          size: 180,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: ElectroSimSpacing.md),
            _WaitingInfoCard(
              icon: Icons.key_outlined,
              label: 'Code de secours',
              value: sessionCode,
              valueKey: const Key('session-waiting-code'),
            ),
            if (url != null) ...<Widget>[
              const SizedBox(height: ElectroSimSpacing.sm),
              SelectableText(
                url.toString(),
                key: const Key('session-waiting-browser-url'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConnectedStudentsCard extends StatelessWidget {
  const _ConnectedStudentsCard({
    required this.count,
    required this.names,
  });

  final int count;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('session-connected-students-card'),
      decoration: BoxDecoration(
        color: ElectroSimColors.surfaceElevated,
        borderRadius: BorderRadius.circular(ElectroSimRadii.card),
        border: Border.all(color: ElectroSimColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ElectroSimSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.people_outline, color: ElectroSimColors.primary),
                const SizedBox(width: ElectroSimSpacing.sm),
                Expanded(
                  child: Text(
                    'Élèves connectés',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  '$count',
                  key: const Key('session-waiting-connected'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: ElectroSimSpacing.md),
            if (names.isEmpty)
              const Text(
                'En attente des élèves…',
                key: Key('session-waiting-no-students'),
              )
            else
              ...names.map(
                (String name) => Padding(
                  padding: const EdgeInsets.only(bottom: ElectroSimSpacing.xs),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.check_circle_outline, size: 18),
                      const SizedBox(width: ElectroSimSpacing.xs),
                      Expanded(child: Text(name)),
                    ],
                  ),
                ),
              ),
          ],
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
        color: ElectroSimColors.background,
        borderRadius: BorderRadius.circular(ElectroSimRadii.card),
        border: Border.all(color: ElectroSimColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ElectroSimSpacing.md),
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
