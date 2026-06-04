// lib/features/agency/presentation/widgets/agency_badge.dart
//
// Phase 19 (spec/019-agencies) Sub-Phase H (T052).
// Verified-agency badge: logo (CachedNetworkImage) + name + a verified icon.
// Tapping pushes the public agency profile (/agency/:id). Rendered ONLY for
// approved agencies by the caller (FR-022). Phase 2 tokens only.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';

class AgencyBadge extends StatelessWidget {
  const AgencyBadge({
    super.key,
    required this.agencyId,
    required this.agencyName,
    this.logoUrl,
    this.compact = false,
  });

  final String agencyId;
  final String agencyName;

  /// Already-resolved public logo URL (or null → fallback business icon).
  final String? logoUrl;

  /// When true, renders the tighter card-overlay variant (logo + verified
  /// icon only, no name text).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    final logo = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: SizedBox(
        width: AppSpacing.xl,
        height: AppSpacing.xl,
        child: logoUrl != null && logoUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: logoUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    ColoredBox(color: colors.surfaceVariant),
                errorWidget: (_, __, ___) => _fallbackLogo(colors),
              )
            : _fallbackLogo(colors),
      ),
    );

    // Phase 25 (Claude Design) — the verified-agency badge carries the trust
    // signal: a soft green container with a green check; the agency name stays
    // high-contrast (onSurface) for readability.
    return Material(
      color: colors.verifiedContainer,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: () => context.push('/agency/$agencyId'),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              logo,
              if (!compact) ...[
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    agencyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.verified,
                size: AppSpacing.lg,
                color: colors.verified,
                semanticLabel: l10n.agency_verified_badge,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackLogo(AppColors colors) {
    return ColoredBox(
      color: colors.surfaceVariant,
      child: Icon(
        Icons.business_outlined,
        size: AppSpacing.lg,
        color: colors.onSurfaceVariant,
      ),
    );
  }
}
