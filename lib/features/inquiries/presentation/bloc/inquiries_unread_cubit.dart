// lib/features/inquiries/presentation/bloc/inquiries_unread_cubit.dart
//
// Phase 16 Sub-Phase F (T072) — Singleton Cubit tracking the count of unread
// (status='new') inquiries. Shared between the home AppBar action widget and
// the InquiryDetailBloc (which calls decrement() on new→seen auto-transition).
//
// canShowEntry gate (FR-019 / Q6=B): the inbox entry is visible to any user
// who owns ≥ 1 APPROVED listing — independent of unread count. The unread
// badge (count) is a separate signal layered on top. An earlier build gated
// visibility on `count > 0`, which incorrectly hid the entry whenever a
// publisher had zero new inquiries; that deviated from Q6=B and is corrected
// here via the publisher_owns_approved_listing RPC.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../domain/usecases/check_owns_approved_listing.dart';
import '../../domain/usecases/load_inbox_unread_count.dart';

part 'inquiries_unread_state.dart';

@lazySingleton
class InquiriesUnreadCubit extends Cubit<InquiriesUnreadState> {
  InquiriesUnreadCubit(this._loadUnreadCount, this._checkOwnsApprovedListing)
    : super(const InquiriesUnreadState(count: 0, canShowEntry: false));

  final LoadInboxUnreadCount _loadUnreadCount;
  final CheckOwnsApprovedListing _checkOwnsApprovedListing;

  /// Re-fetches the inbox-entry visibility (owns ≥1 approved listing) and the
  /// unread count. Both run on every refresh (cold launch + foreground-resume).
  Future<void> refresh() async {
    final ownsResult = await _checkOwnsApprovedListing();
    final countResult = await _loadUnreadCount();
    if (isClosed) return;

    final canShowEntry = ownsResult is Success<bool>
        ? ownsResult.value
        : state.canShowEntry;
    final count = countResult is Success<int> ? countResult.value : state.count;

    emit(InquiriesUnreadState(count: count, canShowEntry: canShowEntry));
  }

  /// Optimistically decrements the unread count by 1.
  /// Called by [InquiryDetailBloc] after the auto new→seen transition.
  /// [canShowEntry] is preserved — the entry stays visible at zero unread.
  void decrement() {
    final newCount = (state.count - 1).clamp(0, double.maxFinite.toInt());
    emit(
      InquiriesUnreadState(count: newCount, canShowEntry: state.canShowEntry),
    );
  }
}
