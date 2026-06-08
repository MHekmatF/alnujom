part of 'comparison_cubit.dart';

/// Immutable selection state for the property-comparison feature.
///
/// Holds an *ordered* list of the selected listing snapshots (insertion order,
/// capped at [ComparisonCubit.maxItems]). The list doubles as the "set" — the
/// cubit guards against duplicates by listing id.
class ComparisonState extends Equatable {
  const ComparisonState({this.items = const []});

  /// Selected listings, in the order the user added them (max 3).
  final List<ComparisonItem> items;

  /// How many listings are currently selected.
  int get count => items.length;

  /// True once at least two listings are selected (the threshold at which the
  /// "Compare" bar appears and the comparison view is meaningful).
  bool get canCompare => items.length >= ComparisonCubit.minToCompare;

  /// True when [id] is in the current selection.
  bool contains(String id) => items.any((it) => it.id == id);

  ComparisonState copyWith({List<ComparisonItem>? items}) =>
      ComparisonState(items: items ?? this.items);

  @override
  List<Object?> get props => [items];
}
