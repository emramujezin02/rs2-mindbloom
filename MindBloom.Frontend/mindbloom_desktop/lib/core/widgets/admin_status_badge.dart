import 'package:flutter/material.dart';

enum AdminStatusTone { neutral, success, warning, danger, info }

class AdminStatusBadge extends StatelessWidget {
  final String label;
  final AdminStatusTone tone;
  final IconData? icon;

  const AdminStatusBadge({
    super.key,
    required this.label,
    this.tone = AdminStatusTone.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final palette = _palette(colors);

    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: palette.foreground),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: palette.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _BadgePalette _palette(ColorScheme colors) {
    switch (tone) {
      case AdminStatusTone.success:
        return _BadgePalette(
          background: colors.primaryContainer,
          foreground: colors.onPrimaryContainer,
          border: colors.primary.withValues(alpha: 0.24),
        );
      case AdminStatusTone.warning:
        return _BadgePalette(
          background: colors.tertiaryContainer,
          foreground: colors.onTertiaryContainer,
          border: colors.tertiary.withValues(alpha: 0.28),
        );
      case AdminStatusTone.danger:
        return _BadgePalette(
          background: colors.errorContainer,
          foreground: colors.onErrorContainer,
          border: colors.error.withValues(alpha: 0.24),
        );
      case AdminStatusTone.info:
        return _BadgePalette(
          background: colors.secondaryContainer,
          foreground: colors.onSecondaryContainer,
          border: colors.secondary.withValues(alpha: 0.24),
        );
      case AdminStatusTone.neutral:
        return _BadgePalette(
          background: colors.surfaceContainerHighest.withValues(alpha: 0.55),
          foreground: colors.onSurfaceVariant,
          border: colors.outlineVariant,
        );
    }
  }
}

class _BadgePalette {
  final Color background;
  final Color foreground;
  final Color border;

  const _BadgePalette({
    required this.background,
    required this.foreground,
    required this.border,
  });
}
