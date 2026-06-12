// lib/features/chat/presentation/pages/chat_thread_page.dart
//
// In-app chat — one conversation thread. App bar titled with the listing, a
// reversed list of message bubbles (own = primary-tinted + end-aligned; other
// = surface + start-aligned, each with a time), and a bottom composer
// (multiline field + send icon). Marks read on open; auto-scrolls to newest.
//
// Token-only + RTL-correct (own bubbles align to the END, others to the START
// — which mirrors automatically under RTL because we use AlignmentDirectional /
// CrossAxisAlignment.start|end inside a directional column).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/message.dart';
import '../bloc/chat_thread_cubit.dart';

class ChatThreadPage extends StatefulWidget {
  const ChatThreadPage({
    super.key,
    required this.conversationId,
    this.listingTitle,
  });

  final String conversationId;
  final String? listingTitle;

  @override
  State<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends State<ChatThreadPage> {
  final TextEditingController _composer = TextEditingController();
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    context.read<ChatThreadCubit>().open(widget.conversationId);
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  void _onSend() {
    final text = _composer.text;
    if (text.trim().isEmpty) return;
    context.read<ChatThreadCubit>().send(text);
    _composer.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.listingTitle ?? l10n.chatThreadTitleFallback,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocConsumer<ChatThreadCubit, ChatThreadState>(
              // Re-mark read whenever new inbound messages land while open.
              listener: (context, state) {
                if (state.status == ChatThreadStatus.messages &&
                    state.messages.length != _lastCount) {
                  _lastCount = state.messages.length;
                  context.read<ChatThreadCubit>().markRead();
                }
              },
              builder: (context, state) {
                switch (state.status) {
                  case ChatThreadStatus.loading:
                    return const AppSpinner.page();
                  case ChatThreadStatus.error:
                    return ErrorState(
                      title: l10n.chatThreadErrorTitle,
                      onRetry: () => context.read<ChatThreadCubit>().open(
                        widget.conversationId,
                      ),
                    );
                  case ChatThreadStatus.messages:
                    if (state.messages.isEmpty) {
                      return EmptyState(
                        icon: Icons.chat_bubble_outline,
                        headline: l10n.chatThreadEmptyTitle,
                        body: l10n.chatThreadEmptyBody,
                      );
                    }
                    // Reversed list: newest at the (visual) bottom, oldest on
                    // top. We feed it reversed so index 0 is the newest.
                    final reversed = state.messages.reversed.toList();
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      itemCount: reversed.length,
                      itemBuilder: (context, i) =>
                          _MessageBubble(message: reversed[i]),
                    );
                }
              },
            ),
          ),
          _Composer(
            controller: _composer,
            onSend: _onSend,
            hintColor: colors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final locale = Localizations.localeOf(context).toString();

    final mine = message.isMine;
    final bubbleColor = mine ? colors.primaryContainer : colors.surfaceVariant;
    final textColor = mine ? colors.onPrimaryContainer : colors.onSurface;
    final time = DateFormat.jm(locale).format(message.createdAt.toLocal());

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            child: Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: appRadius(AppRadii.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.body,
                    style: styles.bodyLarge.copyWith(color: textColor),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    time,
                    style: styles.labelMedium.copyWith(
                      color: textColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.hintColor,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final Color hintColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          border: BorderDirectional(top: BorderSide(color: colors.divider)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  borderRadius: appRadius(AppRadii.lg),
                ),
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 2000,
                  // Suppress the built-in maxLength counter (token-clean: no
                  // empty-string literal in the decoration).
                  buildCounter:
                      (
                        _, {
                        required int currentLength,
                        required bool isFocused,
                        int? maxLength,
                      }) => null,
                  textInputAction: TextInputAction.newline,
                  keyboardType: TextInputType.multiline,
                  style: styles.bodyLarge,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: l10n.chatComposerHint,
                    hintStyle: styles.bodyLarge.copyWith(color: hintColor),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              onPressed: onSend,
              icon: const Icon(Icons.send),
              tooltip: l10n.chatComposerSend,
            ),
          ],
        ),
      ),
    );
  }
}
