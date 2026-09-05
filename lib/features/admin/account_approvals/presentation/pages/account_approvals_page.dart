import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/di/injection.dart';
import '../../../../../core/routing/app_router.dart';
import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/radii.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/typography.dart';
import '../../../../../core/widgets/_widget_support.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_dialog.dart';
import '../../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/error_state.dart';
import '../../../../../core/widgets/load_more_row.dart';
import '../../../../../core/widgets/loading_state.dart';
import '../../../../../core/widgets/staggered_list_item.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../domain/entities/account_approval_request.dart';
import '../cubit/account_approvals_cubit.dart';
import '../cubit/account_approvals_state.dart';

/// Admin queue page: lists pending approval requests; approve or reject each.
class AccountApprovalsPage extends StatelessWidget {
  const AccountApprovalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AccountApprovalsCubit>(
      create: (_) => getIt<AccountApprovalsCubit>()..loadPending(),
      child: const _AccountApprovalsView(),
    );
  }
}

class _AccountApprovalsView extends StatelessWidget {
  const _AccountApprovalsView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DcCrownScaffold(
      title: l10n.admin_queue_title,
      dense: true,
      leading: DcCrownIconButton(
        icon: Icons.arrow_forward,
        onTap: () =>
            context.canPop() ? context.pop() : context.go(AppRoutes.shellHome),
      ),
      body: BlocBuilder<AccountApprovalsCubit, AccountApprovalsState>(
        builder: (context, state) {
          return switch (state) {
            AccountApprovalsInitial() ||
            AccountApprovalsLoading() => const _QueueSkeleton(),

            // Batch-2: the ad-hoc red Text + AppButton column became the shared
            // ErrorState (glyph badge, title, tonal Retry). Same reload call.
            AccountApprovalsError(:final failure) => ErrorState(
              title: l10n.admin_queue_title,
              message: failure.message,
              onRetry: () =>
                  context.read<AccountApprovalsCubit>().loadPending(),
            ),

            AccountApprovalsLoaded(
              :final requests,
              :final hasMore,
              :final loadingMore,
            ) =>
              _buildList(
                context,
                l10n,
                requests,
                isMutating: false,
                hasMore: hasMore,
                loadingMore: loadingMore,
              ),
            AccountApprovalsMutating(:final requests) => _buildList(
              context,
              l10n,
              requests,
              isMutating: true,
              hasMore: false,
              loadingMore: false,
            ),
          };
        },
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    AppLocalizations l10n,
    List<AccountApprovalRequest> requests, {
    required bool isMutating,
    required bool hasMore,
    required bool loadingMore,
  }) {
    if (requests.isEmpty) {
      // Batch-2: bare centred Text -> shared EmptyState. A cleared moderation
      // queue is a good-news state, so it gets the verified/green glyph.
      return EmptyState(
        icon: LucideIcons.circle_check_big,
        headline: l10n.admin_queue_empty,
        body: l10n.admin_queue_pull_to_refresh,
      );
    }
    return RefreshIndicator(
      onRefresh: () => context.read<AccountApprovalsCubit>().loadPending(),
      child: AbsorbPointer(
        absorbing: isMutating,
        child: Opacity(
          opacity: isMutating ? 0.6 : 1.0,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            // Plan A36 — paged; the row at the end fetches the next page.
            itemCount: requests.length + (hasMore ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              if (index >= requests.length) {
                return LoadMoreRow(
                  loading: loadingMore,
                  onLoad: () =>
                      context.read<AccountApprovalsCubit>().loadMore(),
                );
              }
              return StaggeredListItem(
                index: index,
                child: _RequestCard(request: requests[index]),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});

  final AccountApprovalRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Pass the locale. Without it `intl` falls back to en_US and this one card
    // printed "Jun 5, 2026 02:03" in the middle of an otherwise Arabic screen —
    // seen on the device, 2026-09-03. Every other DateFormat call in the app
    // already passes it; this was the only one that did not.
    final dateStr = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).add_Hm().format(request.createdAt.toLocal());

    return AppSurface(
      radius: AppRadii.lg,
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (request.registrantFullName != null)
            _Row(l10n.admin_queue_full_name_label, request.registrantFullName!),
          if (request.registrantPhone != null)
            _Row(l10n.admin_queue_phone_label, request.registrantPhone!),
          if (request.registrantEmail != null)
            _Row(l10n.admin_queue_email_label, request.registrantEmail!),
          // UX-7: never render an identifier-less card — when the profile has no
          // name / phone / email yet, fall back to the user id so the admin can
          // tell whom they are approving.
          if (request.registrantFullName == null &&
              request.registrantPhone == null &&
              request.registrantEmail == null)
            _Row(l10n.admin_queue_user_id_label, request.userId),
          _Row(l10n.admin_queue_created_at_label, dateStr),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: l10n.admin_action_approve,
                  variant: AppButtonVariant.filledSuccess,
                  onPressed: () => context
                      .read<AccountApprovalsCubit>()
                      .approve(request.userId),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  label: l10n.admin_action_reject,
                  variant: AppButtonVariant.destructive,
                  onPressed: () => _onRejectTap(context, l10n).ignore(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onRejectTap(BuildContext context, AppLocalizations l10n) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final styles = AppTextStyles.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: l10n.admin_action_reject_reason_title,
        icon: LucideIcons.triangle_alert,
        variant: AppDialogVariant.destructive,
        actionLabel: l10n.admin_action_confirm,
        cancelLabel: l10n.admin_action_cancel,
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            style: styles.bodyLarge,
            decoration: InputDecoration(
              labelText: l10n.admin_action_reject_reason_label,
              labelStyle: styles.bodyMedium,
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? l10n.admin_action_reject_reason_required
                : null,
            maxLines: 3,
          ),
        ),
        onAction: () {
          if (formKey.currentState!.validate()) {
            Navigator.of(dialogContext).pop(true);
          }
        },
      ),
    );

    final reason = controller.text.trim();
    // Defer dispose by one frame — the dialog is still animating out when showDialog
    // returns, and calling dispose() immediately causes widget tree corruption.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());

    if (confirmed == true && context.mounted) {
      await context.read<AccountApprovalsCubit>().reject(
        request.userId,
        reason,
      );
    }
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: styles.bodyMedium.copyWith(color: colors.textMuted),
          ),
          Text(value, style: styles.bodyLarge),
        ],
      ),
    );
  }
}

/// Shimmer placeholder rows shown while the approvals queue loads.
class _QueueSkeleton extends StatelessWidget {
  const _QueueSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, __) => const LoadingState.card(),
    );
  }
}
