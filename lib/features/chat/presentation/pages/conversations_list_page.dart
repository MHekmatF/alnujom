// lib/features/chat/presentation/pages/conversations_list_page.dart
//
// In-app chat — the conversation list. Each tile shows the listing thumbnail +
// title + last-activity time; tapping opens the thread. Empty/loading/error
// use the shared state widgets. Token-only + RTL-correct.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/di/injection.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/conversation.dart';
import '../bloc/chat_thread_cubit.dart';
import '../bloc/conversations_cubit.dart';
import 'chat_thread_page.dart';

class ConversationsListPage extends StatefulWidget {
  const ConversationsListPage({super.key});

  @override
  State<ConversationsListPage> createState() => _ConversationsListPageState();
}

class _ConversationsListPageState extends State<ConversationsListPage> {
  @override
  void initState() {
    super.initState();
    context.read<ConversationsCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.chatConversationsTitle)),
      body: BlocBuilder<ConversationsCubit, ConversationsState>(
        builder: (context, state) {
          switch (state.status) {
            case ConversationsStatus.initial:
            case ConversationsStatus.loading:
              return const AppSpinner.page();
            case ConversationsStatus.error:
              return ErrorState(
                title: l10n.chatConversationsErrorTitle,
                onRetry: () => context.read<ConversationsCubit>().load(),
              );
            case ConversationsStatus.list:
              if (state.conversations.isEmpty) {
                return EmptyState(
                  icon: Icons.forum_outlined,
                  headline: l10n.chatConversationsEmptyTitle,
                  body: l10n.chatConversationsEmptyBody,
                );
              }
              return ListView.separated(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                itemCount: state.conversations.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) =>
                    _ConversationTile(conversation: state.conversations[i]),
              );
          }
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final locale = Localizations.localeOf(context).toString();

    final title = conversation.listingTitle ?? l10n.chatListingUnavailable;
    final subtitle = conversation.otherIsPublisher
        ? l10n.chatRolePublisher
        : l10n.chatRoleBuyer;

    return PressScale(
      child: AppSurface(
        radius: AppRadii.lg,
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => BlocProvider<ChatThreadCubit>(
                create: (_) => getIt<ChatThreadCubit>(),
                child: ChatThreadPage(
                  conversationId: conversation.id,
                  listingTitle: conversation.listingTitle,
                ),
              ),
            ),
          );
        },
        child: Row(
          children: [
            ClipRRect(
              borderRadius: appRadius(AppRadii.md),
              child: SizedBox(
                width: AppSpacing.xxxl,
                height: AppSpacing.xxxl,
                child: AppNetworkImage(
                  url: conversation.listingImageUrl,
                  semanticLabel: title,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: styles.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: styles.bodyMedium.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              DateFormat.MMMd(
                locale,
              ).add_jm().format(conversation.lastMessageAt.toLocal()),
              style: styles.labelMedium.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
