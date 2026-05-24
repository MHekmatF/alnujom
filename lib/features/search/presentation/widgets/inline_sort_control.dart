// lib/features/search/presentation/widgets/inline_sort_control.dart
//
// Phase 14 Sub-Phase F (T026) — inline DropdownButton<SortOrder> per R-84,
// surfaces the active sort from [SearchBloc] and dispatches
// [SearchSortChanged] when the user picks a new order.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/sort_order.dart';
import '../bloc/search_bloc.dart';
import '../bloc/search_event.dart';
import '../bloc/search_state.dart';

class InlineSortControl extends StatelessWidget {
  const InlineSortControl({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<SearchBloc, SearchState>(
      buildWhen: (prev, curr) => prev.sort != curr.sort,
      builder: (context, state) {
        return DropdownButton<SortOrder>(
          value: state.sort,
          underline: const SizedBox.shrink(),
          items: [
            DropdownMenuItem<SortOrder>(
              value: SortOrder.newest,
              child: Text(l10n.search_sort_newest),
            ),
            DropdownMenuItem<SortOrder>(
              value: SortOrder.priceAsc,
              child: Text(l10n.search_sort_price_asc),
            ),
            DropdownMenuItem<SortOrder>(
              value: SortOrder.priceDesc,
              child: Text(l10n.search_sort_price_desc),
            ),
          ],
          onChanged: (v) {
            if (v != null) {
              context.read<SearchBloc>().add(SearchSortChanged(sort: v));
            }
          },
        );
      },
    );
  }
}
