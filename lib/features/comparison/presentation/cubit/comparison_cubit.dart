// lib/features/comparison/presentation/cubit/comparison_cubit.dart
//
// Session-scoped selection cubit for the property-comparison feature. Holds an
// ordered set of up to 3 selected listing snapshots (ComparisonItem), built
// from the FavoritesPage summaries — it never re-fetches.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/comparison_item.dart';

part 'comparison_state.dart';

/// Tracks the listings the user has marked for side-by-side comparison.
///
/// Lifecycle: constructed once via GetIt (@lazySingleton) so the selection
/// survives while the user scrolls Favorites and opens/closes the comparison
/// view. [toggle] adds/removes by id (capped at [maxItems], duplicates ignored);
/// [clear] resets it.
@lazySingleton
class ComparisonCubit extends Cubit<ComparisonState> {
  ComparisonCubit() : super(const ComparisonState());

  /// Hard cap on how many listings can be compared at once.
  static const int maxItems = 3;

  /// Minimum selection at which a comparison becomes meaningful.
  static const int minToCompare = 2;

  /// True when another listing can still be added (under the [maxItems] cap).
  bool get canAdd => state.items.length < maxItems;

  /// True when [id] is currently selected.
  bool isSelected(String id) => state.contains(id);

  /// Adds [item] to the selection if absent (and under the cap), or removes it
  /// if already selected. No-op when trying to add past [maxItems].
  void toggle(ComparisonItem item) {
    final existingIndex = state.items.indexWhere((it) => it.id == item.id);
    if (existingIndex >= 0) {
      final next = List<ComparisonItem>.from(state.items)
        ..removeAt(existingIndex);
      emit(state.copyWith(items: next));
      return;
    }
    if (!canAdd) return;
    emit(state.copyWith(items: [...state.items, item]));
  }

  /// Removes [id] from the selection if present (used by per-column remove).
  void removeById(String id) {
    if (!state.contains(id)) return;
    final next = state.items.where((it) => it.id != id).toList();
    emit(state.copyWith(items: next));
  }

  /// Clears the entire selection.
  void clear() {
    if (state.items.isEmpty) return;
    emit(const ComparisonState());
  }
}
