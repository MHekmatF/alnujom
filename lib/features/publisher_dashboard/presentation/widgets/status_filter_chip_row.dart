import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../listing_form/domain/entities/listing.dart';
import '../bloc/my_listings_bloc.dart';
import '../bloc/my_listings_event.dart';
import '../bloc/my_listings_state.dart';
import 'status_badge.dart';

class StatusFilterChipRow extends StatelessWidget {
  const StatusFilterChipRow({super.key});

  static const List<ListingStatus?> _filters = [
    null, // "All"
    ListingStatus.draft,
    ListingStatus.pendingReview,
    ListingStatus.approved,
    ListingStatus.rejected,
    ListingStatus.paused,
    ListingStatus.sold,
    ListingStatus.rented,
    ListingStatus.expired,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    return BlocBuilder<MyListingsBloc, MyListingsState>(
      buildWhen: (a, b) => a.statusFilter != b.statusFilter,
      builder: (context, state) {
        return DecoratedBox(
          decoration: BoxDecoration(
            border: BorderDirectional(
              bottom: BorderSide(color: colors.outline),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                for (final f in _filters) ...[
                  ChoiceChip(
                    label: Text(_labelFor(f, l10n)),
                    selected: state.statusFilter == f,
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      context.read<MyListingsBloc>().add(
                        ChangeStatusFilter(f),
                      );
                    },
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  static String _labelFor(ListingStatus? status, AppLocalizations l10n) {
    if (status == null) return l10n.filterChipAll;
    return StatusBadge.labelFor(status, l10n);
  }
}
