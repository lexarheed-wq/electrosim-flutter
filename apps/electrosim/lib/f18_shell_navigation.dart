import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';

class F18DesignCenterPage extends StatelessWidget {
  const F18DesignCenterPage({
    super.key,
    required this.onHome,
    required this.onWiring,
    required this.onSchemaLibrary,
  });

  final VoidCallback onHome;
  final VoidCallback onWiring;
  final VoidCallback onSchemaLibrary;

  @override
  Widget build(BuildContext context) {
    return _F18CenterScaffold(
      key: const Key('design-center-page'),
      eyebrow: 'CENTRE DE CONCEPTION',
      title: 'Concevoir et câbler',
      description:
          'Créez un circuit depuis un espace de câblage ou ouvrez une bibliothèque de schémas sains et fonctionnels.',
      onHome: onHome,
      actions: <_F18CenterAction>[
        _F18CenterAction(
          key: const Key('design-wiring'),
          icon: Icons.account_tree_outlined,
          title: 'Câblage',
          description:
              'Construire et raccorder un circuit électrique dans le simulateur.',
          actionLabel: 'Ouvrir le câblage',
          onTap: onWiring,
        ),
        _F18CenterAction(
          key: const Key('design-schema-library'),
          icon: Icons.library_books_outlined,
          title: 'Bibliothèque de schémas',
          description:
              'Consulter les circuits sains enregistrés pour l’apprentissage et la conception.',
          actionLabel: 'Ouvrir la bibliothèque',
          onTap: onSchemaLibrary,
        ),
      ],
    );
  }
}

class F18MaintenanceCenterPage extends StatelessWidget {
  const F18MaintenanceCenterPage({
    super.key,
    required this.onHome,
    required this.onTroubleshooting,
    required this.onFaultLibrary,
    required this.onStudentValidation,
  });

  final VoidCallback onHome;
  final VoidCallback onTroubleshooting;
  final VoidCallback onFaultLibrary;
  final VoidCallback onStudentValidation;

  @override
  Widget build(BuildContext context) {
    return _F18CenterScaffold(
      key: const Key('maintenance-center-page'),
      eyebrow: 'CENTRE DE MAINTENANCE',
      title: 'Diagnostiquer et intervenir',
      description:
          'Lancez une recherche de dérangement ou consultez la bibliothèque de circuits défectueux.',
      onHome: onHome,
      actions: <_F18CenterAction>[
        _F18CenterAction(
          key: const Key('maintenance-troubleshooting'),
          icon: Icons.build_circle_outlined,
          title: 'Recherche de dérangement',
          description:
              'Observer, mesurer, diagnostiquer puis réparer un circuit en défaut.',
          actionLabel: 'Démarrer le diagnostic',
          onTap: onTroubleshooting,
        ),
        _F18CenterAction(
          key: const Key('maintenance-fault-library'),
          icon: Icons.report_problem_outlined,
          title: 'Bibliothèque de pannes',
          description:
              'Consulter les scénarios autonomes contenant directement des défauts électriques.',
          actionLabel: 'Ouvrir la bibliothèque',
          onTap: onFaultLibrary,
        ),
        _F18CenterAction(
          key: const Key('maintenance-student-validation'),
          icon: Icons.fact_check_outlined,
          title: 'Validation en situation élève',
          description:
              'Préparer un circuit de référence et une panne avant de lancer la situation de diagnostic.',
          actionLabel: 'Préparer la situation',
          onTap: onStudentValidation,
        ),
      ],
    );
  }
}

class F18SessionShellPage extends StatelessWidget {
  const F18SessionShellPage({
    super.key,
    required this.onHome,
    required this.onWiring,
    required this.onTroubleshooting,
    required this.onSupervision,
    required this.onManageSession,
    this.sessionName,
  });

  final String? sessionName;
  final VoidCallback onHome;
  final VoidCallback onWiring;
  final VoidCallback onTroubleshooting;
  final VoidCallback onSupervision;
  final VoidCallback onManageSession;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('session-shell-page'),
      backgroundColor: ElectroSimColors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _F18SessionTopBar(
              onHome: onHome,
              onDashboard: () {},
              onManageSession: onManageSession,
            ),
            const Divider(height: 1),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final ElectroSimWindowClass windowClass =
                      ElectroSimBreakpoints.classify(constraints.maxWidth);
                  final double horizontalPadding =
                      windowClass == ElectroSimWindowClass.compact
                          ? ElectroSimSpacing.md
                          : ElectroSimSpacing.xl;
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      ElectroSimSpacing.xl,
                      horizontalPadding,
                      ElectroSimSpacing.xl,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const _F18SectionIntro(
                              eyebrow: 'SESSION PROFESSEUR',
                              title: 'Tableau de bord',
                              description:
                                  'Choisissez l’espace de travail à préparer pour cette session. Le simulateur ne démarre qu’après la préparation de l’activité.',
                            ),
                            if (sessionName != null &&
                                sessionName!.trim().isNotEmpty) ...<Widget>[
                              const SizedBox(height: ElectroSimSpacing.sm),
                              Text(
                                sessionName!,
                                key: const Key('session-dashboard-name'),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: ElectroSimColors.textSecondary,
                                    ),
                              ),
                            ],
                            const SizedBox(height: ElectroSimSpacing.xl),
                            _F18ActionGrid(
                              actions: <_F18CenterAction>[
                                _F18CenterAction(
                                  key: const Key('dashboard-wiring'),
                                  icon: Icons.account_tree_outlined,
                                  title: 'Câblage',
                                  description:
                                      'Préparer ou superviser une activité de construction de circuit.',
                                  actionLabel: 'Ouvrir',
                                  onTap: onWiring,
                                ),
                                _F18CenterAction(
                                  key: const Key('dashboard-troubleshooting'),
                                  icon: Icons.build_outlined,
                                  title: 'Recherche de dérangement',
                                  description:
                                      'Lancer une activité structurée de diagnostic et de réparation.',
                                  actionLabel: 'Ouvrir',
                                  onTap: onTroubleshooting,
                                ),
                                _F18CenterAction(
                                  key: const Key('dashboard-supervision'),
                                  icon: Icons.monitor_heart_outlined,
                                  title: 'Supervision',
                                  description:
                                      'Suivre l’avancement, les validations et les résultats des élèves.',
                                  actionLabel: 'Ouvrir',
                                  onTap: onSupervision,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class F18PlaceholderPage extends StatelessWidget {
  const F18PlaceholderPage({
    super.key,
    required this.pageKey,
    required this.title,
    required this.description,
  });

  final Key pageKey;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: pageKey,
      backgroundColor: ElectroSimColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(title),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: const EdgeInsets.all(ElectroSimSpacing.xl),
            child: _F18EmptySurface(
              title: title,
              description: description,
            ),
          ),
        ),
      ),
    );
  }
}

class _F18CenterScaffold extends StatelessWidget {
  const _F18CenterScaffold({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.onHome,
    required this.actions,
  });

  final String eyebrow;
  final String title;
  final String description;
  final VoidCallback onHome;
  final List<_F18CenterAction> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElectroSimColors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _F18CenterTopBar(onHome: onHome),
            const Divider(height: 1),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final ElectroSimWindowClass windowClass =
                      ElectroSimBreakpoints.classify(constraints.maxWidth);
                  final double horizontalPadding =
                      windowClass == ElectroSimWindowClass.compact
                          ? ElectroSimSpacing.md
                          : ElectroSimSpacing.xl;
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      ElectroSimSpacing.xl,
                      horizontalPadding,
                      ElectroSimSpacing.xl,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _F18SectionIntro(
                              eyebrow: eyebrow,
                              title: title,
                              description: description,
                            ),
                            const SizedBox(height: ElectroSimSpacing.xl),
                            _F18ActionGrid(actions: actions),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _F18CenterTopBar extends StatelessWidget {
  const _F18CenterTopBar({required this.onHome});

  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ElectroSimGeometry.desktopTopBarHeight,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact =
              constraints.maxWidth < ElectroSimBreakpoints.compactUpperBound;
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ElectroSimSpacing.md,
            ),
            child: Row(
              children: <Widget>[
                IconButton(
                  key: const Key('center-home-action'),
                  onPressed: onHome,
                  tooltip: 'Accueil',
                  icon: const Icon(Icons.home_outlined),
                ),
                const SizedBox(width: ElectroSimSpacing.sm),
                if (compact)
                  const Expanded(
                    child: Text(
                      'ElectroSim',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ElectroSimColors.textPrimary,
                      ),
                    ),
                  )
                else ...<Widget>[
                  const _F18Wordmark(),
                  const Spacer(),
                  const _F18ReadyBadge(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _F18SessionTopBar extends StatelessWidget {
  const _F18SessionTopBar({
    required this.onHome,
    required this.onDashboard,
    required this.onManageSession,
  });

  final VoidCallback onHome;
  final VoidCallback onDashboard;
  final VoidCallback onManageSession;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ElectroSimGeometry.desktopTopBarHeight,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool dense = constraints.maxWidth < 1200;
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ElectroSimSpacing.md,
            ),
            child: Row(
              children: <Widget>[
                const Flexible(child: _F18Wordmark()),
                SizedBox(
                  width: dense
                      ? ElectroSimSpacing.xs
                      : ElectroSimSpacing.lg,
                ),
                if (dense) ...<Widget>[
                  _F18CompactTopAction(
                    key: const Key('session-home-action'),
                    icon: Icons.home_outlined,
                    label: 'Accueil',
                    onPressed: onHome,
                  ),
                  _F18CompactTopAction(
                    key: const Key('session-dashboard-action'),
                    icon: Icons.dashboard_outlined,
                    label: 'Tableau de bord',
                    onPressed: onDashboard,
                  ),
                  _F18CompactTopAction(
                    key: const Key('session-manage-action'),
                    icon: Icons.settings_outlined,
                    label: 'Gérer la session',
                    onPressed: onManageSession,
                  ),
                ] else ...<Widget>[
                  _F18TopAction(
                    key: const Key('session-home-action'),
                    icon: Icons.home_outlined,
                    label: 'Accueil',
                    onPressed: onHome,
                  ),
                  _F18TopAction(
                    key: const Key('session-dashboard-action'),
                    icon: Icons.dashboard_outlined,
                    label: 'Tableau de bord',
                    onPressed: onDashboard,
                  ),
                  _F18TopAction(
                    key: const Key('session-manage-action'),
                    icon: Icons.settings_outlined,
                    label: 'Gérer la session',
                    onPressed: onManageSession,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ElectroSimSpacing.sm,
                      vertical: ElectroSimSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: ElectroSimColors.surfaceMuted,
                      borderRadius:
                          BorderRadius.circular(ElectroSimRadii.compact),
                    ),
                    child: const Text(
                      'SESSION · PRÊTE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: ElectroSimColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _F18CompactTopAction extends StatelessWidget {
  const _F18CompactTopAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: label,
      icon: Icon(icon, size: ElectroSimComponentTokens.iconMedium),
    );
  }
}

class _F18TopAction extends StatelessWidget {
  const _F18TopAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: ElectroSimComponentTokens.iconMedium),
      label: Text(label),
    );
  }
}

class _F18Wordmark extends StatelessWidget {
  const _F18Wordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: ElectroSimColors.primaryStrong,
            borderRadius: BorderRadius.circular(ElectroSimRadii.compact),
          ),
          child: const Icon(Icons.bolt, color: ElectroSimColors.onPrimary),
        ),
        const SizedBox(width: ElectroSimSpacing.xs),
        const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'ElectroSim',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: ElectroSimColors.textPrimary,
              ),
            ),
            Text(
              'F18',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: ElectroSimColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _F18ReadyBadge extends StatelessWidget {
  const _F18ReadyBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ElectroSimSpacing.sm,
        vertical: ElectroSimSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7EF),
        borderRadius: BorderRadius.circular(ElectroSimRadii.pill),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.check_circle_outline,
              size: 16, color: ElectroSimColors.success),
          SizedBox(width: ElectroSimSpacing.xxs),
          Text(
            'Système prêt',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: ElectroSimColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _F18SectionIntro extends StatelessWidget {
  const _F18SectionIntro({
    required this.eyebrow,
    required this.title,
    required this.description,
  });

  final String eyebrow;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            eyebrow,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: ElectroSimColors.info,
                  letterSpacing: 1.5,
                ),
          ),
          const SizedBox(height: ElectroSimSpacing.xs),
          Text(title, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: ElectroSimSpacing.sm),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: ElectroSimColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _F18ActionGrid extends StatelessWidget {
  const _F18ActionGrid({required this.actions});

  final List<_F18CenterAction> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final ElectroSimWindowClass windowClass =
            ElectroSimBreakpoints.classify(constraints.maxWidth);
        final int columns = switch (windowClass) {
          ElectroSimWindowClass.compact => 1,
          ElectroSimWindowClass.medium => 2,
          ElectroSimWindowClass.expanded => actions.length >= 3 ? 3 : 2,
        };
        final double gap = ElectroSimSpacing.md;
        final double cardWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: actions
              .map(
                (_F18CenterAction action) => SizedBox(
                  width: cardWidth,
                  child: _F18ActionCard(action: action),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _F18CenterAction {
  const _F18CenterAction({
    required this.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onTap,
  });

  final Key key;
  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onTap;
}

class _F18ActionCard extends StatelessWidget {
  const _F18ActionCard({required this.action});

  final _F18CenterAction action;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: action.key,
      color: ElectroSimColors.surfaceElevated,
      borderRadius: BorderRadius.circular(ElectroSimRadii.card),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(ElectroSimRadii.card),
        child: Container(
          constraints: const BoxConstraints(minHeight: 220),
          padding: const EdgeInsets.all(ElectroSimSpacing.lg),
          decoration: BoxDecoration(
            border:
                Border.all(color: ElectroSimColors.outline.withValues(alpha: .55)),
            borderRadius: BorderRadius.circular(ElectroSimRadii.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF4FB),
                  borderRadius:
                      BorderRadius.circular(ElectroSimRadii.panel),
                ),
                child: Icon(action.icon, color: ElectroSimColors.primary),
              ),
              const SizedBox(height: ElectroSimSpacing.lg),
              Text(action.title,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: ElectroSimSpacing.xs),
              Text(
                action.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: ElectroSimColors.textSecondary,
                    ),
              ),
              const SizedBox(height: ElectroSimSpacing.lg),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    action.actionLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: ElectroSimColors.primary,
                        ),
                  ),
                  const SizedBox(width: ElectroSimSpacing.xs),
                  const Icon(Icons.arrow_forward,
                      size: 18, color: ElectroSimColors.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _F18EmptySurface extends StatelessWidget {
  const _F18EmptySurface({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ElectroSimSpacing.xl),
      decoration: BoxDecoration(
        color: ElectroSimColors.surfaceElevated,
        borderRadius: BorderRadius.circular(ElectroSimRadii.card),
        border: Border.all(color: ElectroSimColors.outline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.construction_outlined,
              size: 42, color: ElectroSimColors.primary),
          const SizedBox(height: ElectroSimSpacing.md),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: ElectroSimSpacing.xs),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ElectroSimColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}
