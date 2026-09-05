// Phase 18 (spec/018-reports-moderation) — T059
// ReportDetailPage: shows a single report with listing context + admin actions.
// - Loads the report via LoadReportsQueue filtered to a single id (using
//   the admin repository's loadQueue under the hood).
// - "Start review" triggers the `start_report_review` soft-claim (Q4=B).
//   If `reviewing_by` is set by another admin, the label is shown (FR-036)
//   but the action is still allowed (overridable lock).
// - The four moderation actions are presented via ResolveActionDialog.
// Constitution IX: zero Supabase imports.
// Constitution VI: design tokens only; no inline hex/font/padding.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/di/injection.dart';
import '../../../../../core/errors/result.dart';
import '../../../../../core/routing/app_router.dart';
import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/typography.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_spinner.dart';
import '../../../../../core/widgets/app_toast.dart';
import '../../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../../core/widgets/error_state.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../reports/domain/entities/report_reason.dart';
import '../../../../reports/domain/entities/report_status.dart';
import '../../../../reports/presentation/widgets/report_status_chip.dart';
import '../../domain/entities/report_queue_item.dart';
import '../../domain/usecases/load_reports_queue.dart';
import '../bloc/report_resolve_cubit.dart';
import '../widgets/resolve_action_dialog.dart';

class ReportDetailPage extends StatefulWidget {
  const ReportDetailPage({super.key, required this.reportId});

  final String reportId;

  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  ReportQueueItem? _item;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final useCase = getIt<LoadReportsQueue>();
    // Load a single page filtering by the specific ID via the cursor
    // mechanism; since the repository sorts by `created_at DESC` we load
    // a page and find the item. In practice the admin navigated here from
    // the queue card, so the item data is already available — future
    // optimisation: pass the item directly via constructor.
    final result = await useCase(limit: 50);
    switch (result) {
      case Success(:final value):
        final found = value.cast<ReportQueueItem?>().firstWhere(
          (i) => i?.id == widget.reportId,
          orElse: () => null,
        );
        if (mounted) {
          setState(() {
            _item = found;
            _loading = false;
          });
        }
      case FailureResult(:final failure):
        if (mounted) {
          setState(() {
            _error = failure.message;
            _loading = false;
          });
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ReportResolveCubit>(
      create: (_) => getIt<ReportResolveCubit>(),
      child: BlocListener<ReportResolveCubit, ReportResolveState>(
        listener: _onResolveStateChanged,
        child: Builder(
          builder: (ctx) {
            final l10n = AppLocalizations.of(ctx)!;
            if (_loading) {
              return DcCrownScaffold(
                title: l10n.reports_queue_title,
                dense: true,
                leading: DcCrownIconButton(
                  icon: Icons.arrow_forward,
                  onTap: () =>
                      ctx.canPop() ? ctx.pop() : ctx.go(AppRoutes.shellHome),
                ),
                body: const AppSpinner.page(),
              );
            }
            if (_error != null || _item == null) {
              return DcCrownScaffold(
                title: l10n.reports_queue_title,
                dense: true,
                leading: DcCrownIconButton(
                  icon: Icons.arrow_forward,
                  onTap: () =>
                      ctx.canPop() ? ctx.pop() : ctx.go(AppRoutes.shellHome),
                ),
                // Batch-2: the ad-hoc Text + AppButton column became the shared
                // ErrorState (glyph badge, title, tonal Retry). Same reload.
                body: ErrorState(
                  title: l10n.errorGeneric,
                  message: _error,
                  onRetry: _loadReport,
                ),
              );
            }
            return _ReportDetailView(item: _item!, onReload: _loadReport);
          },
        ),
      ),
    );
  }

  void _onResolveStateChanged(BuildContext context, ReportResolveState state) {
    final l10n = AppLocalizations.of(context)!;
    if (state is ReportResolveSuccess) {
      AppToast.success(context, l10n.report_resolved_success);
      // Reload so the page reflects the updated status.
      _loadReport();
      // Reset cubit so future actions are not blocked.
      context.read<ReportResolveCubit>().reset();
    } else if (state is ReportResolveFailure) {
      AppToast.error(context, state.failure.message);
      context.read<ReportResolveCubit>().reset();
    }
  }
}

class _ReportDetailView extends StatelessWidget {
  const _ReportDetailView({required this.item, required this.onReload});

  final ReportQueueItem item;
  final VoidCallback onReload;

  String _reasonLabel(AppLocalizations l10n, ReportReason r) {
    switch (r) {
      case ReportReason.fakeListing:
        return l10n.report_reason_fake_listing;
      case ReportReason.wrongPrice:
        return l10n.report_reason_wrong_price;
      case ReportReason.alreadySoldOrRented:
        return l10n.report_reason_already_sold_or_rented;
      case ReportReason.duplicate:
        return l10n.report_reason_duplicate;
      case ReportReason.spam:
        return l10n.report_reason_spam;
      case ReportReason.wrongLocation:
        return l10n.report_reason_wrong_location;
      case ReportReason.inappropriateContent:
        return l10n.report_reason_inappropriate_content;
      case ReportReason.other:
        return l10n.report_reason_other;
      case ReportReason.harassment:
        return l10n.report_reason_harassment;
      case ReportReason.scam:
        return l10n.report_reason_scam;
      case ReportReason.impersonation:
        return l10n.report_reason_impersonation;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final cubit = context.read<ReportResolveCubit>();

    final isOpen = item.status.isOpen;

    return DcCrownScaffold(
      title: l10n.reports_queue_title,
      dense: true,
      leading: DcCrownIconButton(
        icon: Icons.arrow_forward,
        onTap: () =>
            context.canPop() ? context.pop() : context.go(AppRoutes.shellHome),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Listing info ─────────────────────────────────────────────
            Text(
              item.displayTitle.isEmpty ? '—' : item.displayTitle,
              style: styles.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            // Plan A29 — a report about a person has no listing status; say
            // who it is about instead.
            if (item.isUserReport)
              _InfoRow(
                label: l10n.admin_report_about_user_label,
                value: item.targetUserName ?? item.targetUserId ?? '—',
              )
            else
              _InfoRow(
                label: l10n.admin_report_listing_status_label,
                value: item.listingStatus,
              ),
            const SizedBox(height: AppSpacing.md),

            // ── Report info ──────────────────────────────────────────────
            _InfoRow(
              label: l10n.report_reason_field_label,
              value: _reasonLabel(l10n, item.reason),
            ),
            if (item.note != null && item.note!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(item.note!, style: styles.bodyMedium),
            ],
            const SizedBox(height: AppSpacing.sm),
            _InfoRow(label: 'Reporter', value: item.reporterUserId),
            const SizedBox(height: AppSpacing.sm),

            // ── Status chip + reviewer soft-lock notice ───────────────────
            ReportStatusChip(item.status),
            if (item.reviewingBy != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.report_being_reviewed_by(item.reviewingBy!),
                style: styles.bodyMedium.copyWith(color: colors.primary),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),

            // ── Actions ──────────────────────────────────────────────────
            if (isOpen) ...[
              // Start review button (soft-claim)
              if (item.status == ReportStatus.newReport)
                AppButton(
                  label: l10n.report_start_review_button,
                  variant: AppButtonVariant.outlined,
                  icon: LucideIcons.eye,
                  onPressed: () {
                    cubit.startReview(item.id);
                  },
                ),
              const SizedBox(height: AppSpacing.md),
              // Resolve button
              BlocBuilder<ReportResolveCubit, ReportResolveState>(
                builder: (ctx, state) {
                  final isLoading = state is ReportResolveLoading;
                  return AppButton(
                    label: l10n.report_resolve_button,
                    icon: LucideIcons.gavel,
                    loading: isLoading,
                    onPressed: isLoading
                        ? null
                        : () async {
                            final result = await ResolveActionDialog.show(
                              context,
                              isUserReport: item.isUserReport,
                            );
                            if (result != null && ctx.mounted) {
                              await ctx.read<ReportResolveCubit>().resolve(
                                item.id,
                                result.action,
                                note: result.note,
                              );
                            }
                          },
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Small info row ───────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.label_colon_prefix(label),
          style: styles.labelMedium.copyWith(color: colors.textMuted),
        ),
        Expanded(child: Text(value, style: styles.bodyMedium)),
      ],
    );
  }
}
