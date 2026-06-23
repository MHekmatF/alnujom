// lib/features/reports/presentation/pages/my_reports_page.dart
//
// Phase 18 (spec/018-reports-moderation) Sub-Phase H (T046).
// Replaces the Phase-1 stub: paginated list of the reporter's own reports.
// AppBar(l10n.reports_my_title) + RefreshIndicator + ListView of cards
// (listing image/title + reason + ReportStatusChip) + empty-state.
// Tap → listing details page (FR-022 / SC-007). Phase 2 tokens only.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/elevation.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/deep_link_aware_back_button.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/report.dart';
import '../../domain/entities/report_reason.dart';
import '../cubit/my_reports_bloc.dart';
import '../widgets/my_reports_empty_state.dart';
import '../widgets/report_status_chip.dart';

/// The authenticated My-Reports page: lists the user's submitted reports
/// newest-first, cursor-paginated. Tap navigates to Phase 13 listing details.
class MyReportsPage extends StatelessWidget {
  const MyReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MyReportsBloc>(
      create: (_) => getIt<MyReportsBloc>()..add(const MyReportsOpened()),
      child: const _MyReportsView(),
    );
  }
}

class _MyReportsView extends StatelessWidget {
  const _MyReportsView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        leading: const DeepLinkAwareBackButton(),
        title: Text(l10n.reports_my_title),
      ),
      body: BlocBuilder<MyReportsBloc, MyReportsState>(
        builder: (context, state) {
          return switch (state) {
            MyReportsLoading() => const AppSpinner.page(),
            MyReportsError(:final failure) => _ErrorBody(failure: failure),
            MyReportsLoaded(:final items, :final hasMore) =>
              items.isEmpty
                  ? const MyReportsEmptyState()
                  : _LoadedBody(items: items, hasMore: hasMore),
          };
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error body
// ---------------------------------------------------------------------------

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.failure});

  final Object failure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ErrorState(
      title: l10n.reports_my_title,
      onRetry: () =>
          context.read<MyReportsBloc>().add(const MyReportsRefreshRequested()),
    );
  }
}

// ---------------------------------------------------------------------------
// Loaded body (list + pagination)
// ---------------------------------------------------------------------------

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({required this.items, required this.hasMore});

  final List<Report> items;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<MyReportsBloc>().add(const MyReportsRefreshRequested());
      },
      child: ListView.builder(
        itemCount: items.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Trigger load-more near the end.
          if (index >= (items.length * 0.8).floor() && hasMore) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.read<MyReportsBloc>().add(const MyReportsMoreLoaded());
            });
          }

          // Loading spinner sentinel.
          if (index >= items.length) {
            return const Padding(
              padding: EdgeInsetsDirectional.all(AppSpacing.lg),
              child: AppSpinner(),
            );
          }

          return _ReportCard(item: items[index]);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual report card
// ---------------------------------------------------------------------------

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.item});

  final Report item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final elevation = AppElevation.of(context);

    return PressScale(
      child: Container(
        margin: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: appRadius(AppRadii.lg),
          border: Border.all(color: colors.outline),
          boxShadow: elevation.level1,
        ),
        child: ClipRRect(
          borderRadius: appRadius(AppRadii.lg),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () =>
                  context.push(AppRoutes.listingDetailsFor(item.listingId)),
              child: Padding(
                padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thumbnail
                    ClipRRect(
                      borderRadius: appRadius(AppRadii.md),
                      child: SizedBox(
                        width: AppSpacing.xxxl + AppSpacing.xl,
                        height: AppSpacing.xxxl + AppSpacing.xl,
                        child: item.mainImagePath != null
                            ? CachedNetworkImage(
                                imageUrl: item.mainImagePath!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    ColoredBox(color: colors.surfaceVariant),
                                errorWidget: (_, __, ___) => ColoredBox(
                                  color: colors.surfaceVariant,
                                  child: Icon(
                                    LucideIcons.image_off,
                                    color: colors.textMuted,
                                  ),
                                ),
                              )
                            : ColoredBox(
                                color: colors.surfaceVariant,
                                child: Icon(
                                  LucideIcons.image,
                                  color: colors.textMuted,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.listingTitle.isNotEmpty)
                            Text(
                              item.listingTitle,
                              style: styles.titleMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            _reasonLabel(l10n, item.reason),
                            style: styles.bodyMedium.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ReportStatusChip(item.status),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _reasonLabel(AppLocalizations l10n, ReportReason reason) {
    return switch (reason) {
      ReportReason.fakeListing => l10n.report_reason_fake_listing,
      ReportReason.wrongPrice => l10n.report_reason_wrong_price,
      ReportReason.alreadySoldOrRented =>
        l10n.report_reason_already_sold_or_rented,
      ReportReason.duplicate => l10n.report_reason_duplicate,
      ReportReason.spam => l10n.report_reason_spam,
      ReportReason.wrongLocation => l10n.report_reason_wrong_location,
      ReportReason.inappropriateContent =>
        l10n.report_reason_inappropriate_content,
      ReportReason.other => l10n.report_reason_other,
    };
  }
}
