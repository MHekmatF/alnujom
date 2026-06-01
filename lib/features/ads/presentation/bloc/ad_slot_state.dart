// lib/features/ads/presentation/bloc/ad_slot_state.dart
//
// Part of [AdSlotCubit].

part of 'ad_slot_cubit.dart';

sealed class AdSlotState extends Equatable {
  const AdSlotState();
}

/// Not yet loaded.
final class AdSlotInitial extends AdSlotState {
  const AdSlotInitial();
  @override
  List<Object?> get props => [];
}

/// 0 eligible ads — [AdSlot] renders [SizedBox.shrink()] (FR-012).
final class AdSlotEmpty extends AdSlotState {
  const AdSlotEmpty();
  @override
  List<Object?> get props => [];
}

/// Exactly 1 eligible ad — static banner (no timer, no page indicator).
final class AdSlotSingle extends AdSlotState {
  const AdSlotSingle({required this.ad});

  final ServingAd ad;

  @override
  List<Object?> get props => [ad];
}

/// ≥2 eligible ads — priority-ordered carousel with auto-advance timer.
final class AdSlotCarousel extends AdSlotState {
  const AdSlotCarousel({required this.ads});

  /// Already ordered priority DESC by the datasource (R-173).
  final List<ServingAd> ads;

  @override
  List<Object?> get props => [ads];
}

/// Load failed — [AdSlot] renders [SizedBox.shrink()] (FR-012).
final class AdSlotError extends AdSlotState {
  const AdSlotError();
  @override
  List<Object?> get props => [];
}
