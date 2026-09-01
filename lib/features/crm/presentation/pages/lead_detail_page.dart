// lib/features/crm/presentation/pages/lead_detail_page.dart
//
// Phase 029 (F1) — the lead detail page. Header (name + stage), stage as
// choice-chips (optimistic, persisted), quick actions (in-app Chat / Call /
// WhatsApp), a merged activity timeline (server events + notes), a notes
// composer, and a reminders subsection (add via date/time sheet; toggle
// complete; delete). AppToast for feedback, AppDialog for destructive actions.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radii.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/_widget_support.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_spinner.dart';
import '../../../../core/widgets/dc_crown_scaffold.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../chat/presentation/bloc/chat_thread_cubit.dart';
import '../../../chat/presentation/pages/chat_thread_page.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/crm_lead.dart';
import '../../domain/entities/crm_reminder.dart';
import '../../domain/entities/crm_stage.dart';
import '../../domain/entities/crm_timeline_event.dart';
import '../bloc/lead_detail_cubit.dart';
import '../widgets/crm_stage_styles.dart';

class LeadDetailPage extends StatefulWidget {
  const LeadDetailPage({super.key, required this.lead});

  final CrmLead lead;

  @override
  State<LeadDetailPage> createState() => _LeadDetailPageState();
}

class _LeadDetailPageState extends State<LeadDetailPage> {
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DcCrownScaffold(
      title: l10n.crmLeadDetailTitle,
      dense: true,
      titleWidget: _LeadCrownIdentity(name: widget.lead.displayName),
      leading: DcCrownIconButton(
        icon: Icons.arrow_forward,
        onTap: () => Navigator.of(context).maybePop(),
      ),
      body: BlocBuilder<LeadDetailCubit, LeadDetailState>(
        builder: (context, state) {
          switch (state.status) {
            case LeadDetailStatus.loading:
              return const AppSpinner.page();
            case LeadDetailStatus.error:
              return ErrorState(
                title: l10n.crmLoadErrorTitle,
                onRetry: () => context.read<LeadDetailCubit>().retry(),
              );
            case LeadDetailStatus.ready:
              return _Body(state: state, noteController: _noteController);
          }
        },
      ),
    );
  }
}

/// The lead-detail crown identity: an avatar initial + the lead's name in white.
class _LeadCrownIdentity extends StatelessWidget {
  const _LeadCrownIdentity({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final onHeader = colors.onBrandHeader;
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '؟' : trimmed.substring(0, 1);

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: onHeader.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: Text(
            initial,
            style: styles.titleMedium.copyWith(color: onHeader),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            trimmed.isEmpty ? name : trimmed,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: styles.titleMedium.copyWith(
              color: onHeader,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.noteController});

  final LeadDetailState state;
  final TextEditingController noteController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final styles = AppTextStyles.of(context);

    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      children: [
        // Stage choice-chips.
        Text(l10n.crmStageSectionTitle, style: styles.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        const _StageChips(),
        const SizedBox(height: AppSpacing.xl),

        // Quick actions.
        _QuickActions(state: state),
        const SizedBox(height: AppSpacing.xl),

        // Notes composer.
        Text(l10n.crmNotesSectionTitle, style: styles.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        _NoteComposer(controller: noteController),
        const SizedBox(height: AppSpacing.xl),

        // Reminders.
        _RemindersSection(reminders: state.reminders),
        const SizedBox(height: AppSpacing.xl),

        // Activity timeline (events + notes).
        Text(l10n.crmTimelineSectionTitle, style: styles.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        if (state.activity.isEmpty)
          EmptyState(
            icon: LucideIcons.history,
            headline: l10n.crmTimelineEmptyTitle,
          )
        else
          for (final row in state.activity) _ActivityTile(row: row),
      ],
    );
  }
}

class _StageChips extends StatelessWidget {
  const _StageChips();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);

    return BlocSelector<LeadDetailCubit, LeadDetailState, CrmStage>(
      selector: (s) => s.lead.stage,
      builder: (context, current) {
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final stage in CrmStage.ordered)
              ChoiceChip(
                label: Text(crmStageLabel(stage, l10n)),
                selected: stage == current,
                selectedColor: crmStageColor(
                  stage,
                  colors,
                ).withValues(alpha: 0.18),
                onSelected: (_) =>
                    context.read<LeadDetailCubit>().changeStage(stage),
              ),
          ],
        );
      },
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.state});

  final LeadDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final phone = state.contactPhone;
    final hasChat = state.lead.hasContact && state.lead.listingId != null;

    final actions = <Widget>[
      if (hasChat)
        AppButton(
          label: l10n.crmActionChat,
          variant: AppButtonVariant.tonal,
          icon: LucideIcons.message_circle,
          onPressed: () => _openChat(context),
        ),
      if (phone != null) ...[
        AppButton(
          label: l10n.crmActionCall,
          variant: AppButtonVariant.outlined,
          icon: LucideIcons.phone,
          onPressed: () => _launch(context, 'tel:$phone'),
        ),
        AppButton(
          label: l10n.crmActionWhatsapp,
          variant: AppButtonVariant.whatsapp,
          icon: LucideIcons.message_circle,
          onPressed: () =>
              _launch(context, 'https://wa.me/${_waNumber(phone)}'),
        ),
      ],
    ];

    if (actions.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: actions,
    );
  }

  Future<void> _openChat(BuildContext context) async {
    final cubit = context.read<LeadDetailCubit>();
    final l10n = AppLocalizations.of(context)!;
    final convId = await cubit.resolveConversationId();
    if (!context.mounted) return;
    if (convId == null) {
      AppToast.error(context, l10n.crmChatUnavailable);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider<ChatThreadCubit>(
          create: (_) => getIt<ChatThreadCubit>(),
          child: ChatThreadPage(conversationId: convId),
        ),
      ),
    );
  }

  Future<void> _launch(BuildContext context, String uri) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await launchUrl(
      Uri.parse(uri),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      AppToast.error(context, l10n.crmActionLaunchFailed);
    }
  }

  /// Strips non-digits for the wa.me deep link.
  String _waNumber(String phone) => phone.replaceAll(RegExp(r'[^0-9]'), '');
}

class _NoteComposer extends StatelessWidget {
  const _NoteComposer({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AppTextField(
            controller: controller,
            label: l10n.crmNoteComposerHint,
            maxLines: 3,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        AppButton.iconButton(
          icon: LucideIcons.send,
          label: l10n.crmNoteSendAction,
          onPressed: () async {
            final cubit = context.read<LeadDetailCubit>();
            final ok = await cubit.addNote(controller.text);
            if (!context.mounted) return;
            if (ok) {
              controller.clear();
              AppToast.success(context, l10n.crmNoteAddedSuccess);
            } else {
              AppToast.error(context, l10n.crmNoteAddError);
            }
          },
        ),
      ],
    );
  }
}

class _RemindersSection extends StatelessWidget {
  const _RemindersSection({required this.reminders});

  final List<CrmReminder> reminders;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final styles = AppTextStyles.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.crmRemindersSectionTitle,
                style: styles.labelLarge,
              ),
            ),
            AppButton(
              label: l10n.crmReminderAddAction,
              variant: AppButtonVariant.text,
              icon: LucideIcons.plus,
              size: AppButtonSize.dense,
              onPressed: () => _showAddReminderSheet(context),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (reminders.isEmpty)
          Text(
            l10n.crmRemindersEmpty,
            style: styles.bodyMedium.copyWith(
              color: AppColors.of(context).textMuted,
            ),
          )
        else
          for (final r in reminders) _ReminderTile(reminder: r),
      ],
    );
  }

  Future<void> _showAddReminderSheet(BuildContext context) async {
    final cubit = context.read<LeadDetailCubit>();
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();

    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsetsDirectional.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: _AddReminderSheet(controller: controller, cubit: cubit),
      ),
    );
    controller.dispose();
    if (added == true && context.mounted) {
      AppToast.success(context, l10n.crmReminderAddedSuccess);
    }
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.reminder});

  final CrmReminder reminder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final locale = Localizations.localeOf(context).toString();
    final cubit = context.read<LeadDetailCubit>();

    final when = DateFormat.yMMMd(locale).add_jm().format(reminder.dueAt);
    final done = reminder.isCompleted;

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: AppSurface(
        radius: AppRadii.md,
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                done ? LucideIcons.circle_check : LucideIcons.circle,
                color: done ? colors.success : colors.textMuted,
              ),
              tooltip: l10n.crmReminderToggleTooltip,
              onPressed: () => cubit.toggleReminderCompleted(reminder),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.title,
                    style: styles.bodyLarge.copyWith(
                      color: done ? colors.textMuted : colors.onSurface,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  Text(
                    when,
                    style: styles.labelMedium.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(LucideIcons.trash_2, color: colors.error),
              tooltip: l10n.crmDeleteAction,
              onPressed: () => _confirmDelete(context, cubit, reminder),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    LeadDetailCubit cubit,
    CrmReminder reminder,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: l10n.crmReminderDeleteTitle,
        message: l10n.crmReminderDeleteMessage,
        icon: LucideIcons.trash_2,
        variant: AppDialogVariant.destructive,
        actionLabel: l10n.crmDeleteAction,
        onAction: () {
          Navigator.of(dialogContext).pop();
          cubit.deleteReminder(reminder);
        },
      ),
    );
  }
}

class _AddReminderSheet extends StatefulWidget {
  const _AddReminderSheet({required this.controller, required this.cubit});

  final TextEditingController controller;
  final LeadDetailCubit cubit;

  @override
  State<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends State<_AddReminderSheet> {
  DateTime _due = DateTime.now().add(const Duration(hours: 1));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final locale = Localizations.localeOf(context).toString();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.crmReminderAddTitle, style: styles.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: widget.controller,
              label: l10n.crmReminderTitleLabel,
            ),
            const SizedBox(height: AppSpacing.lg),
            InkWell(
              borderRadius: appRadius(AppRadii.md),
              onTap: _pickDateTime,
              child: Padding(
                padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(LucideIcons.calendar, color: colors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        DateFormat.yMMMd(locale).add_jm().format(_due),
                        style: styles.bodyLarge,
                      ),
                    ),
                    Text(
                      l10n.crmReminderPickTime,
                      style: styles.labelMedium.copyWith(color: colors.primary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton.filledPrimary(
              label: l10n.crmReminderAddAction,
              expanded: true,
              onPressed: () async {
                final ok = await widget.cubit.addReminder(
                  title: widget.controller.text,
                  dueAt: _due,
                );
                if (context.mounted) Navigator.of(context).pop(ok);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_due),
    );
    if (time == null || !mounted) return;
    setState(() {
      _due = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.row});

  final LeadActivityRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final locale = Localizations.localeOf(context).toString();

    final when = DateFormat.MMMd(locale).add_jm().format(row.occurredAt);
    final (icon, title, body) = _content(context, l10n);
    final cubit = context.read<LeadDetailCubit>();

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppSpacing.lg, color: colors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: styles.bodyMedium.copyWith(color: colors.onSurface),
                ),
                if (body != null && body.trim().isNotEmpty)
                  Text(
                    body,
                    style: styles.bodyMedium.copyWith(color: colors.textMuted),
                  ),
                Text(
                  when,
                  style: styles.labelMedium.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
          if (row.isNote)
            IconButton(
              icon: Icon(
                LucideIcons.trash_2,
                color: colors.error,
                size: AppSpacing.lg,
              ),
              tooltip: l10n.crmDeleteAction,
              onPressed: () => _confirmDeleteNote(context, cubit),
            ),
        ],
      ),
    );
  }

  (IconData, String, String?) _content(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    if (row.isNote) {
      return (LucideIcons.sticky_note, l10n.crmTimelineNote, row.note!.body);
    }
    final e = row.event!;
    final title = switch (e.kind) {
      CrmTimelineKind.inquiry => l10n.crmTimelineInquiry,
      CrmTimelineKind.message => l10n.crmTimelineMessage,
      CrmTimelineKind.viewingRequested => l10n.crmTimelineViewingRequested,
      CrmTimelineKind.viewingConfirmed => l10n.crmTimelineViewingConfirmed,
      CrmTimelineKind.viewingDeclined => l10n.crmTimelineViewingDeclined,
      CrmTimelineKind.viewingCancelled => l10n.crmTimelineViewingCancelled,
      CrmTimelineKind.note => l10n.crmTimelineNote,
    };
    final icon = switch (e.kind) {
      CrmTimelineKind.inquiry => LucideIcons.inbox,
      CrmTimelineKind.message => LucideIcons.message_circle,
      _ => LucideIcons.calendar,
    };
    return (icon, title, e.snippet);
  }

  Future<void> _confirmDeleteNote(
    BuildContext context,
    LeadDetailCubit cubit,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: l10n.crmNoteDeleteTitle,
        message: l10n.crmNoteDeleteMessage,
        icon: LucideIcons.trash_2,
        variant: AppDialogVariant.destructive,
        actionLabel: l10n.crmDeleteAction,
        onAction: () {
          Navigator.of(dialogContext).pop();
          cubit.deleteNote(row.note!.id);
        },
      ),
    );
  }
}
