// lib/features/assistant/presentation/pages/assistant_page.dart
//
// Phase 28 (WS-6) — مساعد البحث الذكي / smart search assistant page.
//
// A chat-style surface over the swappable [AssistantBrain] (rule-based today,
// LLM-ready seam — see domain/assistant_brain.dart): the user describes what
// they want in natural Arabic or English, the assistant echoes back what it
// understood as tappable filter chips and a "Show results" CTA that routes to
// the existing search page pre-filtered. Stats questions ("متوسط أسعار حلب")
// are answered from the market_area_stats RPC.
//
// Mirrors the chat thread's bubble/composer idiom (reversed list, end-aligned
// user bubbles, surface composer with a filled send button) — token-only and
// RTL-correct via directional geometry throughout.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/chat_bubble.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/util/arabic_digits.dart';
import '../../domain/entities/assistant_message.dart';
import '../../domain/entities/parsed_query.dart';
import '../bloc/assistant_cubit.dart';

class AssistantPage extends StatelessWidget {
  const AssistantPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AssistantCubit>(
      create: (_) => getIt<AssistantCubit>(),
      child: const _AssistantView(),
    );
  }
}

class _AssistantView extends StatefulWidget {
  const _AssistantView();

  @override
  State<_AssistantView> createState() => _AssistantViewState();
}

class _AssistantViewState extends State<_AssistantView> {
  final TextEditingController _composer = TextEditingController();

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  void _onSend() {
    final text = _composer.text;
    if (text.trim().isEmpty) return;
    context.read<AssistantCubit>().send(text);
    _composer.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.sparkles, color: colors.primary),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                l10n.assistantTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<AssistantCubit, AssistantState>(
              builder: (context, state) {
                // Reversed list: newest at the visual bottom (index 0); the
                // typing bubble occupies index 0 while the brain replies.
                final reversed = state.messages.reversed.toList();
                final extra = state.thinking ? 1 : 0;
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  itemCount: reversed.length + extra,
                  itemBuilder: (context, i) {
                    if (state.thinking && i == 0) {
                      return const _TypingBubble();
                    }
                    final message = reversed[i - extra];
                    return _MessageTile(message: message);
                  },
                );
              },
            ),
          ),
          BlocBuilder<AssistantCubit, AssistantState>(
            builder: (context, state) => state.isFresh
                ? _QuickReplies(
                    onTap: (text) =>
                        context.read<AssistantCubit>().send(text),
                  )
                : const SizedBox.shrink(),
          ),
          const _PoweredByCaption(),
          _Composer(controller: _composer, onSend: _onSend),
        ],
      ),
    );
  }
}

// ─── transcript tiles ───

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message});

  final AssistantMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.role == AssistantRole.user) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
        child: ChatBubble(
          message: message.text,
          variant: ChatBubbleVariant.mine,
        ),
      );
    }
    return _AssistantBubble(child: _ReplyContent(reply: message.reply!));
  }
}

/// Assistant bubble chrome: tinted sparkles avatar + card surface, start-
/// aligned (mirrors automatically under RTL via directional geometry).
class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppSpacing.xxl,
            height: AppSpacing.xxl,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.sparkles,
              size: AppSpacing.lg,
              color: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              child: AppSurface(
                radius: AppRadii.lg,
                padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return const _AssistantBubble(
      child: SizedBox(
        width: AppSpacing.xxl,
        height: AppSpacing.lg,
        child: AppSpinner(size: AppSpacing.lg),
      ),
    );
  }
}

/// Renders one structured [AssistantReply] — the localized sentence is
/// composed HERE (never in the domain layer) so locale switches re-render
/// the whole transcript correctly.
class _ReplyContent extends StatelessWidget {
  const _ReplyContent({required this.reply});

  final AssistantReply reply;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final styles = AppTextStyles.of(context);
    final colors = AppColors.of(context);

    switch (reply.kind) {
      case AssistantReplyKind.greeting:
        return Text(l10n.assistantGreeting, style: styles.bodyLarge);
      case AssistantReplyKind.noMatch:
        return Text(l10n.assistantNoMatch, style: styles.bodyLarge);
      case AssistantReplyKind.parsed:
        final parsed = reply.parsed!;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.assistantParsedSummary,
              style: styles.labelLarge.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: AppSpacing.sm),
            _FragmentChips(fragments: parsed.fragments),
            const SizedBox(height: AppSpacing.md),
            _ShowResultsButton(parsed: parsed),
          ],
        );
      case AssistantReplyKind.stats:
        final parsed = reply.parsed!;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_statsSentence(context, reply), style: styles.bodyLarge),
            if (parsed.fragments.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              _FragmentChips(fragments: parsed.fragments),
            ],
            if (parsed.hasAnyFilter) ...[
              const SizedBox(height: AppSpacing.md),
              _ShowResultsButton(parsed: parsed),
            ],
          ],
        );
    }
  }

  /// "متوسط السعر في دمشق: ٤٥٠ مليون ل.س (١٢ إعلان)" — compact, locale-aware
  /// average with Arabic-Indic digits under ar (mirrors MoneyFormatter's
  /// digit policy without requiring a Currency entity).
  String _statsSentence(BuildContext context, AssistantReply reply) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final stats = reply.stats!;
    final area =
        reply.parsed?.governorate?.localizedName(locale) ?? '';
    var amount = NumberFormat.compact(
      locale: locale.toString(),
    ).format(stats.avgPrice.round());
    if (locale.languageCode == 'ar') {
      amount = toArabicIndicNumerals(amount);
    }
    final symbol = _currencySymbol(context, stats.currencyCode);
    return l10n.assistantStatsAnswer(
      area,
      '$amount $symbol',
      stats.listingCount,
    );
  }

  String _currencySymbol(BuildContext context, String code) {
    if (code == 'SYP') {
      // R-12 policy mirror: ل.س for Arabic readers, the code for English.
      return Localizations.localeOf(context).languageCode == 'ar'
          ? AppLocalizations.of(context)!.currencySypSymbol
          : code;
    }
    if (code == 'USD') return r'$';
    return code;
  }
}

class _ShowResultsButton extends StatelessWidget {
  const _ShowResultsButton({required this.parsed});

  final ParsedQuery parsed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppButton(
      label: l10n.assistantShowResults,
      icon: LucideIcons.search,
      size: AppButtonSize.dense,
      // Same extra contract the saved-searches re-apply flow uses: the
      // search route reads a FilterState from `state.extra`.
      onPressed: () => context.push(AppRoutes.search, extra: parsed.filters),
    );
  }
}

class _FragmentChips extends StatelessWidget {
  const _FragmentChips({required this.fragments});

  final List<MatchedFragment> fragments;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final fragment in fragments) _FragmentChip(fragment: fragment),
      ],
    );
  }
}

class _FragmentChip extends StatelessWidget {
  const _FragmentChip({required this.fragment});

  final MatchedFragment fragment;

  static IconData _iconFor(AssistantFragmentKind kind) => switch (kind) {
    AssistantFragmentKind.propertyType => LucideIcons.building_2,
    AssistantFragmentKind.purpose => LucideIcons.tag,
    AssistantFragmentKind.location => LucideIcons.map_pin,
    AssistantFragmentKind.city => LucideIcons.building,
    AssistantFragmentKind.area => LucideIcons.map,
    AssistantFragmentKind.areaSize => LucideIcons.ruler,
    AssistantFragmentKind.amenity => LucideIcons.sparkles,
    AssistantFragmentKind.price => LucideIcons.banknote,
    AssistantFragmentKind.rooms => LucideIcons.bed_double,
    AssistantFragmentKind.bathrooms => LucideIcons.bath,
    AssistantFragmentKind.currency => LucideIcons.coins,
  };

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return AppSurface(
      color: colors.surfaceVariant,
      borderColor: colors.outline,
      radius: AppRadii.pill,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _iconFor(fragment.kind),
            size: AppSpacing.md,
            color: colors.primary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(fragment.text, style: styles.labelMedium),
        ],
      ),
    );
  }
}

// ─── quick replies + footer ───

class _QuickReplies extends StatelessWidget {
  const _QuickReplies({required this.onTap});

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final styles = AppTextStyles.of(context);
    final colors = AppColors.of(context);
    final suggestions = [
      l10n.assistantQuickSale,
      l10n.assistantQuickRent,
      l10n.assistantQuickStats,
    ];
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final suggestion in suggestions)
              AppSurface(
                onTap: () => onTap(suggestion),
                color: colors.card,
                borderColor: colors.outlineStrong,
                radius: AppRadii.pill,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Text(
                  suggestion,
                  style: styles.labelLarge.copyWith(color: colors.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PoweredByCaption extends StatelessWidget {
  const _PoweredByCaption();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.lg,
        end: AppSpacing.lg,
        bottom: AppSpacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.zap, size: AppSpacing.md, color: colors.textMuted),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              l10n.assistantPoweredBy,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: styles.labelMedium.copyWith(color: colors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── composer (mirrors the chat thread's idiom) ───

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

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
                  maxLines: 3,
                  maxLength: 300,
                  // Suppress the built-in counter (token-clean).
                  buildCounter:
                      (
                        _, {
                        required int currentLength,
                        required bool isFocused,
                        int? maxLength,
                      }) => null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  style: styles.bodyLarge,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: l10n.assistantInputHint,
                    hintStyle: styles.bodyLarge.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              onPressed: onSend,
              icon: const Icon(LucideIcons.send),
              tooltip: l10n.chatComposerSend,
            ),
          ],
        ),
      ),
    );
  }
}
