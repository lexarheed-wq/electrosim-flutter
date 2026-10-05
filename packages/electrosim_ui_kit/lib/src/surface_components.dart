import 'package:flutter/material.dart';

import 'design_tokens.dart';

class ElectroSimPanel extends StatelessWidget {
  const ElectroSimPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(ElectroSimSpacing.md),
    this.backgroundColor = ElectroSimColors.surfaceElevated,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ElectroSimRadii.panel),
        side: const BorderSide(color: ElectroSimColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

class ElectroSimStatusChip extends StatelessWidget {
  const ElectroSimStatusChip({
    super.key,
    required this.label,
    this.icon,
    this.emphasized = false,
  });

  final String label;
  final IconData? icon;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final Color foreground = emphasized
        ? ElectroSimColors.primary
        : ElectroSimColors.textSecondary;
    final Color background = emphasized
        ? const Color(0xFFEFF4FF)
        : ElectroSimColors.surfaceMuted;
    return Semantics(
      label: label,
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(
          horizontal: ElectroSimSpacing.sm,
          vertical: ElectroSimSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: const Border.fromBorderSide(
            BorderSide(color: ElectroSimColors.outline),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: ElectroSimSpacing.xs),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ElectroSimSectionTitle extends StatelessWidget {
  const ElectroSimSectionTitle({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: ElectroSimSpacing.xxs),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: ElectroSimColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
