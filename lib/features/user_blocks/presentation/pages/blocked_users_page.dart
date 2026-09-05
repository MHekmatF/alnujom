// Plan A29 — Settings → Blocked users. Everyone the signed-in user has blocked
// from chat, with a way to lift each block. Token-only, RTL-correct.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/blocked_user.dart';
import '../cubit/blocked_users_cubit.dart';

class BlockedUsersPage extends StatelessWidget {
  const BlockedUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BlockedUsersCubit>(
      create: (_) => getIt<BlockedUsersCubit>()..load(),
      child: const _BlockedUsersView(),
    );
  }
}

class _BlockedUsersView extends StatelessWidget {
  const _BlockedUsersView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DcCrownScaffold(
      title: l10n.blockedUsersTitle,
      dense: true,
      leading: DcCrownIconButton(
        icon: Icons.arrow_forward,
        onTap: () => Navigator.of(context).maybePop(),
      ),
      body: BlocConsumer<BlockedUsersCubit, BlockedUsersState>(
        listenWhen: (prev, curr) =>
            curr.unblockFailedToken != prev.unblockFailedToken,
        listener: (context, _) =>
            AppToast.error(context, l10n.chatBlockFailedToast),
        builder: (context, state) {
          switch (state.status) {
            case BlockedUsersStatus.loading:
              return const Center(child: AppSpinner());
            case BlockedUsersStatus.error:
              return ErrorState(
                title: l10n.blockedUsersErrorTitle,
                onRetry: () => context.read<BlockedUsersCubit>().load(),
              );
            case BlockedUsersStatus.loaded:
              if (state.users.isEmpty) {
                return EmptyState(
                  headline: l10n.blockedUsersEmptyTitle,
                  body: l10n.blockedUsersEmptyBody,
                );
              }
              return ListView.separated(
                padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                itemCount: state.users.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) => _BlockedRow(
                  user: state.users[i],
                  unblocking: state.unblockingId == state.users[i].userId,
                ),
              );
          }
        },
      ),
    );
  }
}

class _BlockedRow extends StatelessWidget {
  const _BlockedRow({required this.user, required this.unblocking});

  final BlockedUser user;
  final bool unblocking;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final name = user.fullName?.trim();
    return Row(
      children: [
        Icon(Icons.block_outlined, color: colors.textMuted),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            name == null || name.isEmpty ? l10n.blockedUsersUnknownName : name,
            style: styles.bodyLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        AppButton(
          label: l10n.blockedUsersUnblockButton,
          variant: AppButtonVariant.outlined,
          size: AppButtonSize.dense,
          loading: unblocking,
          onPressed: unblocking
              ? null
              : () => context.read<BlockedUsersCubit>().unblock(user.userId),
        ),
      ],
    );
  }
}
