import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';

class F18HomeSurface extends StatelessWidget {
  const F18HomeSurface({
    super.key,
    required this.onCreateSession,
    required this.onMaintenance,
    required this.onDesign,
    required this.onJoinSession,
    this.activeSession = false,
  });

  final bool activeSession;
  final VoidCallback onCreateSession;
  final VoidCallback onMaintenance;
  final VoidCallback onDesign;
  final VoidCallback onJoinSession;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElectroSimColors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const _HomeHeader(),
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
                      windowClass == ElectroSimWindowClass.compact
                          ? ElectroSimSpacing.lg
                          : 44,
                      horizontalPadding,
                      ElectroSimSpacing.lg,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _Hero(windowClass: windowClass),
                            const SizedBox(height: 40),
                            _HomeActionGrid(
                              windowClass: windowClass,
                              actions: <_HomeAction>[
                                _HomeAction(
                                  key: const Key('home-create-session'),
                                  eyebrow: 'SESSION',
                                  title: activeSession
                                      ? 'Reprendre la session active'
                                      : 'Créer une nouvelle session',
                                  description: activeSession
                                      ? 'Une session est en cours. Reprenez-la ou terminez-la avant d’en créer une autre.'
                                      : 'Préparez un environnement de travail, invitez les participants et lancez une activité encadrée.',
                                  icon: Icons.add,
                                  actionLabel: 'Créer une session',
                                  emphasized: true,
                                  onTap: onCreateSession,
                                ),
                                _HomeAction(
                                  key: const Key('home-maintenance'),
                                  eyebrow: 'MAINTENANCE',
                                  title: 'Centre de maintenance',
                                  description:
                                      'Accédez aux scénarios de panne, aux activités de recherche de dérangement et au diagnostic.',
                                  icon: Icons.build_outlined,
                                  actionLabel: 'Ouvrir le centre',
                                  onTap: onMaintenance,
                                ),
                                _HomeAction(
                                  key: const Key('home-design'),
                                  eyebrow: 'CONCEPTION',
                                  title: 'Centre de conception',
                                  description:
                                      'Construisez, câblez et validez des circuits électriques dans un espace de conception professionnel.',
                                  icon: Icons.account_tree_outlined,
                                  actionLabel: 'Ouvrir le centre',
                                  onTap: onDesign,
                                ),
                              ],
                            ),
                            const SizedBox(height: ElectroSimSpacing.md),
                            const _StudentAccessInfoPanel(),
                            const SizedBox(height: ElectroSimSpacing.lg),
                            const _HomeFooter(),
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

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact =
              constraints.maxWidth < ElectroSimBreakpoints.compactUpperBound;
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? ElectroSimSpacing.md : ElectroSimSpacing.xl,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1312),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: ElectroSimColors.primaryStrong,
                        borderRadius: BorderRadius.circular(
                          ElectroSimRadii.panel,
                        ),
                        boxShadow: ElectroSimComponentTokens.cardElevation,
                      ),
                      child: const Icon(
                        Icons.bolt,
                        color: ElectroSimColors.onPrimary,
                      ),
                    ),
                    const SizedBox(width: ElectroSimSpacing.sm),
                    const Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'ElectroSim',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: ElectroSimColors.textPrimary,
                            ),
                          ),
                          Text(
                            'PLATEFORME D’ÉLECTROTECHNIQUE',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              letterSpacing: .8,
                              color: ElectroSimColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!compact) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: ElectroSimSpacing.sm,
                          vertical: ElectroSimSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: ElectroSimColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(
                            ElectroSimRadii.pill,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.check_circle,
                              size: 14,
                              color: ElectroSimColors.success,
                            ),
                            SizedBox(width: ElectroSimSpacing.xxs),
                            Text(
                              'Système prêt',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: ElectroSimColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.windowClass});

  final ElectroSimWindowClass windowClass;

  @override
  Widget build(BuildContext context) {
    final bool compact = windowClass == ElectroSimWindowClass.compact;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(width: 28, height: 1, color: ElectroSimColors.info),
              const SizedBox(width: ElectroSimSpacing.xs),
              Text(
                'ENVIRONNEMENT DE TRAVAIL',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: ElectroSimColors.info,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: ElectroSimSpacing.md),
          Text(
            'Concevoir, diagnostiquer et comprendre les systèmes électriques.',
            style:
                (compact
                        ? Theme.of(context).textTheme.headlineMedium
                        : Theme.of(context).textTheme.displayLarge)
                    ?.copyWith(
                      color: ElectroSimColors.textPrimary,
                      letterSpacing: -1,
                    ),
          ),
          const SizedBox(height: ElectroSimSpacing.md),
          Text(
            'Un espace professionnel pour l’apprentissage, la simulation et la supervision des activités d’électrotechnique.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: ElectroSimColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeActionGrid extends StatelessWidget {
  const _HomeActionGrid({required this.windowClass, required this.actions});

  final ElectroSimWindowClass windowClass;
  final List<_HomeAction> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = switch (windowClass) {
          ElectroSimWindowClass.compact => 1,
          ElectroSimWindowClass.medium => 2,
          ElectroSimWindowClass.expanded => 3,
        };
        final double gap = ElectroSimSpacing.md;
        final double width =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: actions
              .map(
                (_HomeAction action) => SizedBox(
                  width: width,
                  child: _HomeActionCard(action: action),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _HomeAction {
  const _HomeAction({
    required this.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
    required this.actionLabel,
    required this.onTap,
    this.emphasized = false,
  });

  final Key key;
  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onTap;
  final bool emphasized;
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({required this.action});

  final _HomeAction action;

  @override
  Widget build(BuildContext context) {
    final Color foreground = action.emphasized
        ? ElectroSimColors.onPrimary
        : ElectroSimColors.textPrimary;
    final Color secondary = action.emphasized
        ? const Color(0xFFD7E6F5)
        : ElectroSimColors.textSecondary;
    return Semantics(
      button: true,
      label: action.title,
      child: Material(
        key: action.key,
        color: action.emphasized
            ? ElectroSimColors.primary
            : ElectroSimColors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        elevation: 0,
        child: InkWell(
          onTap: action.onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            constraints: const BoxConstraints(minHeight: 286),
            padding: const EdgeInsets.all(ElectroSimSpacing.lg),
            decoration: BoxDecoration(
              border: Border.all(
                color: action.emphasized
                    ? ElectroSimColors.primary
                    : ElectroSimColors.outline.withValues(alpha: .5),
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: action.emphasized
                  ? ElectroSimComponentTokens.floatingElevation
                  : ElectroSimComponentTokens.cardElevation,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: action.emphasized
                        ? Colors.white.withValues(alpha: .10)
                        : const Color(0xFFF3F7FB),
                    borderRadius: BorderRadius.circular(ElectroSimRadii.panel),
                    border: Border.all(
                      color: action.emphasized
                          ? Colors.white.withValues(alpha: .20)
                          : ElectroSimColors.outline.withValues(alpha: .4),
                    ),
                  ),
                  child: Icon(action.icon, color: foreground),
                ),
                const SizedBox(height: ElectroSimSpacing.lg),
                Text(
                  action.eyebrow,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: secondary,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: ElectroSimSpacing.xs),
                Text(
                  action.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: foreground),
                ),
                const SizedBox(height: ElectroSimSpacing.sm),
                Text(
                  action.description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: secondary),
                ),
                const SizedBox(height: ElectroSimSpacing.xl),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        action.actionLabel,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.labelMedium?.copyWith(color: foreground),
                      ),
                    ),
                    const SizedBox(width: ElectroSimSpacing.xs),
                    Icon(Icons.arrow_forward, size: 18, color: foreground),
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

class _StudentAccessInfoPanel extends StatelessWidget {
  const _StudentAccessInfoPanel();

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('home-join-panel'),
      color: ElectroSimColors.surfaceElevated,
      borderRadius: BorderRadius.circular(ElectroSimRadii.card),
      child: Padding(
        padding: const EdgeInsets.all(ElectroSimSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F7FB),
                borderRadius: BorderRadius.circular(ElectroSimRadii.compact),
              ),
              child: const Icon(
                Icons.qr_code_2_outlined,
                color: ElectroSimColors.primary,
              ),
            ),
            const SizedBox(width: ElectroSimSpacing.sm),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Accès élèves sans installation',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: ElectroSimColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: ElectroSimSpacing.xxs),
                  Text(
                    'Après création de la session, les élèves scannent le QR code de la salle d’attente et utilisent Safari, Chrome ou un autre navigateur sur le même réseau local. Internet n’est pas nécessaire.',
                    style: TextStyle(
                      fontSize: 11,
                      color: ElectroSimColors.textSecondary,
                    ),
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

class _HomeFooter extends StatelessWidget {
  const _HomeFooter();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: <Widget>[
        Expanded(
          child: Text(
            'ElectroSim F18 · Environnement de simulation électrotechnique',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: ElectroSimColors.textSecondary,
            ),
          ),
        ),
        SizedBox(width: ElectroSimSpacing.md),
        Text(
          'Mode local disponible',
          style: TextStyle(fontSize: 10, color: ElectroSimColors.textSecondary),
        ),
      ],
    );
  }
}
