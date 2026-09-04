import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../listing_form/domain/entities/listing.dart';
import '../../domain/usecases/set_own_listing_status.dart';
import '../bloc/my_listings_bloc.dart';
import '../bloc/my_listings_event.dart';
import '../bloc/my_listings_state.dart';

/// The lifecycle actions a publisher can take on their own listing (plan A15):
/// mark it sold or rented, pause it, put it back, or delete it.
///
/// Which actions appear comes from [SetOwnListingStatus.availableFrom], which
/// mirrors the RPC's transition table. That mirroring is a convenience for
/// drawing the menu, never the gate — the server refuses anything it does not
/// allow, so a card left stale on screen simply gets an error toast.
Future<void> showListingActionsSheet({
  required BuildContext context,
  required String listingId,
  required ListingStatus status,
  required MyListingsBloc bloc,
}) {
  final actions = SetOwnListingStatus.availableFrom(status);
  if (actions.isEmpty) return Future<void>.value();

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: BlocProvider<MyListingsBloc>.value(
        value: bloc,
        child: _ActionsList(listingId: listingId, actions: actions),
      ),
    ),
  );
}

class _ActionsList extends StatelessWidget {
  const _ActionsList({required this.listingId, required this.actions});

  final String listingId;
  final List<ListingStatus> actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final styles = AppTextStyles.of(context);
    final colors = AppColors.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Text(l10n.myListingsActionsTitle, style: styles.titleMedium),
        ),
        for (final action in actions)
          _ActionTile(
            listingId: listingId,
            action: action,
            destructive: SetOwnListingStatus.isDestructive(action),
            colors: colors,
          ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.listingId,
    required this.action,
    required this.destructive,
    required this.colors,
  });

  final String listingId;
  final ListingStatus action;
  final bool destructive;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final styles = AppTextStyles.of(context);
    final (label, subtitle, icon) = _describe(l10n);
    final tint = destructive ? colors.error : colors.onSurface;

    return ListTile(
      leading: Icon(icon, color: tint),
      title: Text(label, style: styles.bodyLarge.copyWith(color: tint)),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: styles.labelMedium.copyWith(color: colors.textMuted),
            ),
      onTap: () => _onTap(context),
    );
  }

  (String, String?, IconData) _describe(AppLocalizations l10n) {
    return switch (action) {
      ListingStatus.sold => (
        l10n.myListingsActionMarkSold,
        l10n.myListingsActionMarkSoldSubtitle,
        Icons.sell_outlined,
      ),
      ListingStatus.rented => (
        l10n.myListingsActionMarkRented,
        l10n.myListingsActionMarkSoldSubtitle,
        Icons.vpn_key_outlined,
      ),
      ListingStatus.paused => (
        l10n.myListingsActionPause,
        l10n.myListingsActionPauseSubtitle,
        Icons.pause_circle_outline,
      ),
      ListingStatus.approved => (
        l10n.myListingsActionRepublish,
        l10n.myListingsActionRepublishSubtitle,
        Icons.play_circle_outline,
      ),
      ListingStatus.deleted => (
        l10n.myListingsActionDelete,
        l10n.myListingsActionDeleteSubtitle,
        Icons.delete_outline,
      ),
      // availableFrom() never offers these; the switch stays exhaustive so a
      // new status cannot be added without deciding what it looks like here.
      ListingStatus.draft ||
      ListingStatus.pendingReview ||
      ListingStatus.rejected ||
      ListingStatus.expired => (
        l10n.myListingsActionsTitle,
        null,
        Icons.help_outline,
      ),
    };
  }

  void _onTap(BuildContext context) {
    final bloc = context.read<MyListingsBloc>();
    final l10n = AppLocalizations.of(context)!;
    Navigator.of(context).pop();

    void dispatch() =>
        bloc.add(MyListingsStatusChangeRequested(listingId, action));

    if (!destructive) {
      dispatch();
      return;
    }

    // Deleting is the one move a publisher cannot undo from inside the app.
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialog(
        icon: Icons.delete_outline,
        variant: AppDialogVariant.destructive,
        title: l10n.myListingsDeleteConfirmTitle,
        message: l10n.myListingsDeleteConfirmMessage,
        actionLabel: l10n.myListingsActionDelete,
        onAction: () {
          Navigator.of(dialogContext).pop();
          dispatch();
        },
      ),
    );
  }
}

/// The overflow button that opens the sheet. Renders nothing for a status with
/// no available moves (a submission under review, or an already-deleted row).
class ListingActionsButton extends StatelessWidget {
  const ListingActionsButton({
    super.key,
    required this.listingId,
    required this.status,
  });

  final String listingId;
  final ListingStatus status;

  @override
  Widget build(BuildContext context) {
    if (SetOwnListingStatus.availableFrom(status).isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final bloc = context.read<MyListingsBloc>();

    return BlocSelector<MyListingsBloc, MyListingsState, bool>(
      selector: (state) => state.statusChangingId == listingId,
      builder: (context, busy) => IconButton(
        icon: busy
            ? const SizedBox(
                width: AppSpacing.lg,
                height: AppSpacing.lg,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.more_vert),
        tooltip: l10n.myListingsActionsTitle,
        visualDensity: VisualDensity.compact,
        onPressed: busy
            ? null
            : () => showListingActionsSheet(
                context: context,
                listingId: listingId,
                status: status,
                bloc: bloc,
              ),
      ),
    );
  }
}
