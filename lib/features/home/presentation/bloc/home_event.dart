import 'dart:ui' show Locale;

import 'package:equatable/equatable.dart';

/// Phase 13 — events for [HomeBloc] per FR-014.
///
/// All three carry a `locale` so the datasource can resolve localized
/// governorate/city names at DTO→entity mapping per data-model.md §2.2.
sealed class HomeEvent extends Equatable {
  const HomeEvent({required this.locale});

  final Locale locale;

  @override
  List<Object?> get props => [locale];
}

/// Initial load (first page). Triggered when HomePage first builds.
class HomeFeedLoadRequested extends HomeEvent {
  const HomeFeedLoadRequested({required super.locale});
}

/// Infinite-scroll next-page request. Triggered by the ScrollController
/// listener when the user nears the bottom of the feed.
class HomeFeedNextPageRequested extends HomeEvent {
  const HomeFeedNextPageRequested({required super.locale});
}

/// Pull-to-refresh. Discards the cursor and re-loads the first page.
class HomeFeedRefreshRequested extends HomeEvent {
  const HomeFeedRefreshRequested({required super.locale});
}
