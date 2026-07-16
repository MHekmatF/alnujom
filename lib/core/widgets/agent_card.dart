import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../theme/colors.dart';
import '../theme/elevation.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '_widget_support.dart';

/// Phase 25 uplift — agent / agency contact card for the listing-detail page.
///
/// A rounded surface (card colour, outline, radius `lg`, `level1` depth)
/// carrying a leading circular avatar (the agency logo via
/// [CachedNetworkImage], or initials on `primaryContainer` when no logo is
/// available), the agent/agency [name] with an optional green verified check,
/// an optional [subtitle], and a bottom [actions] row supplied by the caller
/// (e.g. call / message / WhatsApp buttons).
///
/// Purely presentational — the caller owns all display strings and the
/// behaviour behind each action. RTL-safe.
class AgentCard extends StatelessWidget {
  const AgentCard({
    required this.name,
    this.logoUrl,
    this.verified = false,
    this.subtitle,
    this.actions = const [],
    super.key,
  });

  /// Agent or agency display name (already localized by the caller).
  final String name;

  /// Resolved public logo URL. When null/empty, initials are shown instead.
  final String? logoUrl;

  /// Renders a small green verified check beside the [name] when true.
  final bool verified;

  /// Optional secondary line under the name (e.g. role, agency, location).
  final String? subtitle;

  /// Caller-provided action buttons rendered in a row at the bottom of the
  /// card. Empty by default (no action region).
  final List<Widget> actions;

  static const double _avatarSize = AppSpacing.xxxl;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final elevation = AppElevation.of(context);

    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Avatar(name: name, logoUrl: logoUrl),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: styles.titleMedium.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  if (verified) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      LucideIcons.badge_check,
                      size: AppSpacing.lg,
                      color: colors.verified,
                    ),
                  ],
                ],
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: styles.bodyMedium.copyWith(color: colors.textMuted),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: appRadius(AppRadii.lg),
        border: Border.all(color: colors.outline),
        boxShadow: elevation.level1,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            header,
            if (actions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Row(children: _spacedActions(actions)),
            ],
          ],
        ),
      ),
    );
  }

  static List<Widget> _spacedActions(List<Widget> actions) {
    final spaced = <Widget>[];
    for (var i = 0; i < actions.length; i++) {
      if (i > 0) spaced.add(const SizedBox(width: AppSpacing.sm));
      spaced.add(actions[i]);
    }
    return spaced;
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.logoUrl});

  final String name;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final content = (logoUrl != null && logoUrl!.isNotEmpty)
        ? CachedNetworkImage(
            imageUrl: logoUrl!,
            fit: BoxFit.cover,
            placeholder: (_, __) => ColoredBox(color: colors.surfaceVariant),
            errorWidget: (_, __, ___) => _initials(context),
          )
        : _initials(context);

    return ClipRRect(
      borderRadius: appRadius(AppRadii.pill),
      child: SizedBox(
        width: AgentCard._avatarSize,
        height: AgentCard._avatarSize,
        child: content,
      ),
    );
  }

  Widget _initials(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return ColoredBox(
      color: colors.primaryContainer,
      child: Center(
        child: Text(
          _deriveInitials(name),
          maxLines: 1,
          style: styles.titleMedium.copyWith(color: colors.onPrimaryContainer),
        ),
      ),
    );
  }

  static String _deriveInitials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) {
      return parts.first.characters.take(1).toString().toUpperCase();
    }
    final first = parts.first.characters.take(1).toString();
    final last = parts.last.characters.take(1).toString();
    return '$first$last'.toUpperCase();
  }
}
