import 'package:electrosim_tp/electrosim_tp.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';

import 'runtime/electrosim_tp_session_controller.dart';

class ElectroSimSectionPage extends StatelessWidget {
  const ElectroSimSectionPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: trailing == null
            ? null
            : <Widget>[
                Padding(
                  padding: const EdgeInsets.only(right: ElectroSimSpacing.md),
                  child: Center(child: trailing),
                ),
              ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: ListView(
              padding: const EdgeInsets.all(ElectroSimSpacing.lg),
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: ElectroSimSpacing.xs),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: ElectroSimColors.textSecondary,
                      ),
                ),
                const SizedBox(height: ElectroSimSpacing.xl),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NewSessionPage extends StatefulWidget {
  const NewSessionPage({super.key, required this.onCreate});

  final ValueChanged<String> onCreate;

  @override
  State<NewSessionPage> createState() => _NewSessionPageState();
}

class _NewSessionPageState extends State<NewSessionPage> {
  final TextEditingController _name =
      TextEditingController(text: 'Session atelier');

  @override
  Widget build(BuildContext context) {
    return ElectroSimSectionPage(
      key: const Key('new-session-page'),
      title: 'Nouvelle session',
      subtitle:
          'Créez d’abord la session. Le simulateur ne s’ouvre qu’après le choix d’une activité.',
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(ElectroSimSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Informations de session',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: ElectroSimSpacing.md),
                TextField(
                  key: const Key('new-session-name'),
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Nom de la session',
                    hintText: 'Ex. BEP2 — diagnostic circuit CC',
                  ),
                ),
                const SizedBox(height: ElectroSimSpacing.lg),
                FilledButton.icon(
                  key: const Key('new-session-create'),
                  onPressed: _create,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Créer et ouvrir le tableau de bord'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _create() {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donnez un nom à la session.')),
      );
      return;
    }
    widget.onCreate(name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }
}

class DesignCenterPage extends StatelessWidget {
  const DesignCenterPage({
    super.key,
    required this.onNewWiring,
    required this.onOpenExamples,
  });

  final VoidCallback onNewWiring;
  final VoidCallback onOpenExamples;

  @override
  Widget build(BuildContext context) {
    return ElectroSimSectionPage(
      key: const Key('design-center-page'),
      title: 'Centre de conception',
      subtitle:
          'Concevez un nouveau circuit ou partez d’un schéma sain qualifié.',
      children: <Widget>[
        _ActionTile(
          key: const Key('design-new-wiring'),
          icon: Icons.cable_outlined,
          title: 'Nouveau câblage',
          description:
              'Ouvrir une platine de travail pour créer et vérifier un circuit.',
          onTap: onNewWiring,
        ),
        const SizedBox(height: ElectroSimSpacing.md),
        _ActionTile(
          key: const Key('design-example-library'),
          icon: Icons.library_books_outlined,
          title: 'Bibliothèque de schémas sains',
          description:
              'Consulter les exemples validés avant de les ouvrir dans le simulateur.',
          onTap: onOpenExamples,
        ),
      ],
    );
  }
}

class MaintenanceCenterPage extends StatelessWidget {
  const MaintenanceCenterPage({
    super.key,
    required this.onOpenFaultLibrary,
    required this.onStartTroubleshooting,
  });

  final VoidCallback onOpenFaultLibrary;
  final VoidCallback onStartTroubleshooting;

  @override
  Widget build(BuildContext context) {
    return ElectroSimSectionPage(
      key: const Key('maintenance-center-page'),
      title: 'Centre de maintenance',
      subtitle:
          'Préparez une activité de diagnostic ou consultez les scénarios de panne qualifiés.',
      children: <Widget>[
        _ActionTile(
          key: const Key('maintenance-fault-library'),
          icon: Icons.report_problem_outlined,
          title: 'Bibliothèque de pannes',
          description:
              'Voir les scénarios défectueux disponibles et leur niveau de difficulté.',
          onTap: onOpenFaultLibrary,
        ),
        const SizedBox(height: ElectroSimSpacing.md),
        _ActionTile(
          key: const Key('maintenance-start-troubleshooting'),
          icon: Icons.troubleshoot_outlined,
          title: 'Lancer une recherche de dérangement',
          description:
              'Choisir explicitement une panne avant d’ouvrir le simulateur.',
          onTap: onStartTroubleshooting,
        ),
      ],
    );
  }
}

class SessionDashboardPage extends StatelessWidget {
  const SessionDashboardPage({
    super.key,
    required this.sessionName,
    required this.controller,
    required this.onOpenWiring,
    required this.onOpenTroubleshooting,
    required this.onOpenSupervision,
    required this.onManageSession,
  });

  final String sessionName;
  final ElectroSimTpSessionController controller;
  final VoidCallback onOpenWiring;
  final VoidCallback onOpenTroubleshooting;
  final VoidCallback onOpenSupervision;
  final VoidCallback onManageSession;

  @override
  Widget build(BuildContext context) {
    return ElectroSimSectionPage(
      key: const Key('session-dashboard-page'),
      title: 'Tableau de bord',
      subtitle: sessionName,
      trailing: OutlinedButton.icon(
        key: const Key('dashboard-manage-session'),
        onPressed: onManageSession,
        icon: const Icon(Icons.settings_outlined),
        label: const Text('Gérer la session'),
      ),
      children: <Widget>[
        AnimatedBuilder(
          animation: controller,
          builder: (BuildContext context, Widget? child) {
            final TpSession? session = controller.session;
            final String state =
                session == null ? 'Aucun TP publié' : lifecycleLabel(session.lifecycle);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(ElectroSimSpacing.md),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.info_outline),
                    const SizedBox(width: ElectroSimSpacing.sm),
                    Expanded(
                      child: Text(
                        'État de la session : $state',
                        key: const Key('dashboard-session-state'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: ElectroSimSpacing.lg),
        Wrap(
          spacing: ElectroSimSpacing.md,
          runSpacing: ElectroSimSpacing.md,
          children: <Widget>[
            SizedBox(
              width: 300,
              child: _ActionTile(
                key: const Key('dashboard-open-wiring'),
                icon: Icons.cable_outlined,
                title: 'Câblage',
                description:
                    'Accéder au simulateur uniquement pour une activité de câblage.',
                onTap: onOpenWiring,
              ),
            ),
            SizedBox(
              width: 300,
              child: _ActionTile(
                key: const Key('dashboard-open-troubleshooting'),
                icon: Icons.troubleshoot_outlined,
                title: 'Recherche de dérangement',
                description:
                    'Préparer ou réaliser un TP de diagnostic.',
                onTap: onOpenTroubleshooting,
              ),
            ),
            SizedBox(
              width: 300,
              child: _ActionTile(
                key: const Key('dashboard-open-supervision'),
                icon: Icons.monitor_heart_outlined,
                title: 'Supervision',
                description:
                    'Suivre le cycle du TP, les remises et la notation.',
                onTap: onOpenSupervision,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String lifecycleLabel(TpLifecycle lifecycle) => switch (lifecycle) {
      TpLifecycle.draft => 'Brouillon',
      TpLifecycle.published => 'Publié',
      TpLifecycle.started => 'En cours',
      TpLifecycle.submitted => 'Remis',
      TpLifecycle.evaluated => 'Noté',
      TpLifecycle.closed => 'Clôturé',
    };

class SessionManagementPage extends StatefulWidget {
  const SessionManagementPage({
    super.key,
    required this.controller,
  });

  final ElectroSimTpSessionController controller;

  @override
  State<SessionManagementPage> createState() => _SessionManagementPageState();
}

class _SessionManagementPageState extends State<SessionManagementPage> {
  final TextEditingController _score = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return ElectroSimSectionPage(
      key: const Key('session-management-page'),
      title: 'Gestion de la session',
      subtitle:
          'Publication, remise, notation et clôture sont gérées hors du simulateur.',
      children: <Widget>[
        AnimatedBuilder(
          animation: widget.controller,
          builder: (BuildContext context, Widget? child) {
            final TpSession? session = widget.controller.session;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(ElectroSimSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      session?.definition.title ?? 'Aucun TP préparé',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: ElectroSimSpacing.xs),
                    Text(
                      session == null
                          ? 'Créez un TP avant de le publier aux élèves.'
                          : 'État : ${lifecycleLabel(session.lifecycle)}',
                      key: const Key('management-lifecycle'),
                    ),
                    const SizedBox(height: ElectroSimSpacing.lg),
                    ..._actions(session),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  List<Widget> _actions(TpSession? session) {
    if (session == null) {
      return <Widget>[
        FilledButton.icon(
          key: const Key('management-create-tp'),
          onPressed: widget.controller.createDraft,
          icon: const Icon(Icons.add_task_outlined),
          label: const Text('Créer un TP de recherche de dérangement'),
        ),
      ];
    }
    return switch (session.lifecycle) {
      TpLifecycle.draft => <Widget>[
          FilledButton.icon(
            key: const Key('management-publish-tp'),
            onPressed: widget.controller.publish,
            icon: const Icon(Icons.publish_outlined),
            label: const Text('Publier aux élèves'),
          ),
        ],
      TpLifecycle.published => const <Widget>[
          Text('TP publié. En attente du démarrage élève.'),
        ],
      TpLifecycle.started => const <Widget>[
          Text('TP en cours côté élève.'),
        ],
      TpLifecycle.submitted => <Widget>[
          TextField(
            key: const Key('management-score'),
            controller: _score,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Note / ${session.definition.maxScore}',
              hintText: '${session.evaluation?.score ?? 0}',
            ),
          ),
          const SizedBox(height: ElectroSimSpacing.sm),
          FilledButton.icon(
            key: const Key('management-evaluate'),
            onPressed: () {
              final int? score = int.tryParse(_score.text.trim());
              if (score == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Saisissez une note entière.')),
                );
                return;
              }
              try {
                widget.controller.evaluateTeacher(score: score);
              } on RangeError {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'La note doit être comprise entre 0 et ${session.definition.maxScore}.',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.grading_outlined),
            label: const Text('Valider la note'),
          ),
        ],
      TpLifecycle.evaluated => <Widget>[
          FilledButton.icon(
            key: const Key('management-close-tp'),
            onPressed: widget.controller.closeTeacher,
            icon: const Icon(Icons.lock_outline),
            label: const Text('Clôturer le TP'),
          ),
        ],
      TpLifecycle.closed => const <Widget>[
          Text('TP clôturé. Le travail élève est définitivement en lecture seule.'),
        ],
    };
  }

  @override
  void dispose() {
    _score.dispose();
    super.dispose();
  }
}

class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String title;
  final String subtitle;
}

class CatalogPage extends StatelessWidget {
  const CatalogPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.onOpen,
  });

  final String title;
  final String subtitle;
  final List<CatalogItem> items;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return ElectroSimSectionPage(
      key: Key('catalog-page-$title'),
      title: title,
      subtitle: subtitle,
      children: <Widget>[
        if (items.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(ElectroSimSpacing.lg),
              child: Text('Aucun contenu qualifié disponible.'),
            ),
          )
        else
          for (final CatalogItem item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: ElectroSimSpacing.sm),
              child: Card(
                child: ListTile(
                  key: Key('catalog-item-${item.id}'),
                  leading: const Icon(Icons.electrical_services_outlined),
                  title: Text(item.title),
                  subtitle: Text(item.subtitle),
                  trailing: FilledButton(
                    onPressed: () => onOpen(item.id),
                    child: const Text('Ouvrir'),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ElectroSimRadii.panel),
        child: Padding(
          padding: const EdgeInsets.all(ElectroSimSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 30, color: ElectroSimColors.primary),
              const SizedBox(width: ElectroSimSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: ElectroSimSpacing.xs),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: ElectroSimColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
