import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../../core/di/injection.dart';
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.admin_queue_title)),
      body: BlocBuilder<AccountApprovalsCubit, AccountApprovalsState>(
        builder: (context, state) {
          return switch (state) {
            AccountApprovalsInitial() ||
            AccountApprovalsLoading() =>
              const Center(child: CircularProgressIndicator()),

            AccountApprovalsError(:final failure) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    failure.message,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () =>
                        context.read<AccountApprovalsCubit>().loadPending(),
                    child: Text(l10n.admin_queue_pull_to_refresh),
                  ),
                ],
              ),
            ),

            AccountApprovalsLoaded(:final requests) ||
            AccountApprovalsMutating(:final requests) => _buildList(
              context,
              l10n,
              requests,
              isMutating: state is AccountApprovalsMutating,
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
  }) {
    if (requests.isEmpty) {
      return Center(child: Text(l10n.admin_queue_empty));
    }
    return RefreshIndicator(
      onRefresh: () => context.read<AccountApprovalsCubit>().loadPending(),
      child: AbsorbPointer(
        absorbing: isMutating,
        child: Opacity(
          opacity: isMutating ? 0.6 : 1.0,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _RequestCard(request: requests[index]),
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
    final theme = Theme.of(context);
    final dateStr = DateFormat.yMMMd().add_Hm().format(request.createdAt.toLocal());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (request.registrantFullName != null)
              _Row(l10n.admin_queue_full_name_label, request.registrantFullName!),
            if (request.registrantPhone != null)
              _Row(l10n.admin_queue_phone_label, request.registrantPhone!),
            if (request.registrantEmail != null)
              _Row(l10n.admin_queue_email_label, request.registrantEmail!),
            _Row(l10n.admin_queue_created_at_label, dateStr),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => context
                        .read<AccountApprovalsCubit>()
                        .approve(request.userId),
                    child: Text(l10n.admin_action_approve),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        _onRejectTap(context, l10n).ignore(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    child: Text(l10n.admin_action_reject),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onRejectTap(BuildContext context, AppLocalizations l10n) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.admin_action_reject_reason_title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.admin_action_reject_reason_label,
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty)
                    ? l10n.admin_action_reject_reason_required
                    : null,
            maxLines: 3,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.admin_action_cancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            child: Text(l10n.admin_action_confirm),
          ),
        ],
      ),
    );

    final reason = controller.text.trim();
    // Defer dispose by one frame — the dialog is still animating out when showDialog
    // returns, and calling dispose() immediately causes widget tree corruption.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());

    if (confirmed == true && context.mounted) {
      await context
          .read<AccountApprovalsCubit>()
          .reject(request.userId, reason);
    }
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
