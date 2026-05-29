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

import '../../../../../core/di/injection.dart';
import '../../../../../core/errors/result.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../reports/domain/entities/report_reason.dart';
import '../../../../reports/domain/entities/report_status.dart';
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
              return Scaffold(
                appBar: AppBar(title: Text(l10n.reports_queue_title)),
                body: const Center(child: CircularProgressIndicator()),
              );
            }
            if (_error != null || _item == null) {
              return Scaffold(
                appBar: AppBar(title: Text(l10n.reports_queue_title)),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error ?? l10n.errorGeneric,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton(
                          onPressed: _loadReport,
                          child: Text(l10n.actionReload),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            return _ReportDetailView(
              item: _item!,
              onReload: _loadReport,
            );
          },
        ),
      ),
    );
  }

  void _onResolveStateChanged(BuildContext context, ReportResolveState state) {
    final l10n = AppLocalizations.of(context)!;
    if (state is ReportResolveSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.report_resolved_success)),
      );
      // Reload so the page reflects the updated status.
      _loadReport();
      // Reset cubit so future actions are not blocked.
      context.read<ReportResolveCubit>().reset();
    } else if (state is ReportResolveFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.failure.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cubit = context.read<ReportResolveCubit>();

    final isOpen = item.status.isOpen;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reports_queue_title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Listing info ─────────────────────────────────────────────
            Text(
              item.listingTitle.isEmpty ? '—' : item.listingTitle,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            _InfoRow(
              label: 'Listing status',
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
              Text(
                item.note!,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            _InfoRow(label: 'Reporter', value: item.reporterUserId),
            const SizedBox(height: AppSpacing.sm),

            // ── Status chip + reviewer soft-lock notice ───────────────────
            _ReportStatusChipRow(status: item.status),
            if (item.reviewingBy != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.report_being_reviewed_by(item.reviewingBy!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),

            // ── Actions ──────────────────────────────────────────────────
            if (isOpen) ...[
              // Start review button (soft-claim)
              if (item.status == ReportStatus.newReport)
                OutlinedButton.icon(
                  icon: const Icon(Icons.rate_review_outlined),
                  label: Text(l10n.report_start_review_button),
                  onPressed: () {
                    cubit.startReview(item.id);
                  },
                ),
              const SizedBox(height: AppSpacing.md),
              // Resolve button
              BlocBuilder<ReportResolveCubit, ReportResolveState>(
                builder: (ctx, state) {
                  final isLoading = state is ReportResolveLoading;
                  return FilledButton.icon(
                    icon: isLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.gavel_outlined),
                    label: Text(l10n.resolve_action_dismiss),
                    onPressed: isLoading
                        ? null
                        : () async {
                            final result =
                                await ResolveActionDialog.show(context);
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

// ─── Status chip row (uses the local pill from report_queue_card.dart) ────────

// Re-export the private `_ReportStatusChip` concept via a named row widget
// since the private class is in another file. We inline a minimal version here.
class _ReportStatusChipRow extends StatelessWidget {
  const _ReportStatusChipRow({required this.status});
  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final (label, bg, fg) = switch (status) {
      ReportStatus.newReport => (
          l10n.report_status_new,
          theme.colorScheme.primaryContainer,
          theme.colorScheme.onPrimaryContainer,
        ),
      ReportStatus.reviewing => (
          l10n.report_status_reviewing,
          theme.colorScheme.secondaryContainer,
          theme.colorScheme.onSecondaryContainer,
        ),
      ReportStatus.resolved => (
          l10n.report_status_resolved,
          theme.colorScheme.tertiaryContainer,
          theme.colorScheme.onTertiaryContainer,
        ),
      ReportStatus.dismissed => (
          l10n.report_status_dismissed,
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurfaceVariant,
        ),
    };

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(color: fg),
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
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
