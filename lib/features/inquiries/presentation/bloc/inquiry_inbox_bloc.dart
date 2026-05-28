// lib/features/inquiries/presentation/bloc/inquiry_inbox_bloc.dart
//
// Phase 16 Sub-Phase F (T064) — BLoC driving the InquiryInboxPage.
// Factory-scoped so the page gets a fresh BLoC on each route push.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/inquiry.dart';
import '../../domain/entities/inquiry_status.dart';
import '../../domain/usecases/load_inquiry_inbox.dart';

part 'inquiry_inbox_event.dart';
part 'inquiry_inbox_state.dart';

@injectable
class InquiryInboxBloc extends Bloc<InquiryInboxEvent, InquiryInboxState> {
  InquiryInboxBloc(this._loadInbox) : super(const InquiryInboxLoading()) {
    on<InquiryInboxOpened>(_onOpened);
    on<InquiryInboxRefreshRequested>(_onRefresh);
    on<InquiryInboxMoreLoaded>(_onMoreLoaded);
    on<InquiryInboxStatusFilterChanged>(_onStatusFilterChanged);
    on<InquiryInboxListingFilterChanged>(_onListingFilterChanged);
  }

  final LoadInquiryInbox _loadInbox;

  static const int _pageSize = 30;

  /// Set on [InquiryInboxOpened]; remembered for all subsequent re-fetches
  /// (refresh, filter, pagination). false = personal publisher inbox (own
  /// listings only); true = admin oversight (all publishers).
  bool _adminTier = false;

  Future<void> _onOpened(
    InquiryInboxOpened event,
    Emitter<InquiryInboxState> emit,
  ) async {
    _adminTier = event.adminTier;
    emit(const InquiryInboxLoading());
    await _fetch(emit, statusFilter: null, listingFilter: null);
  }

  Future<void> _onRefresh(
    InquiryInboxRefreshRequested event,
    Emitter<InquiryInboxState> emit,
  ) async {
    InquiryStatus? statusFilter;
    String? listingFilter;
    if (state is InquiryInboxLoaded) {
      final loaded = state as InquiryInboxLoaded;
      statusFilter = loaded.statusFilter;
      listingFilter = loaded.listingFilter;
    }
    emit(const InquiryInboxLoading());
    await _fetch(
      emit,
      statusFilter: statusFilter,
      listingFilter: listingFilter,
    );
  }

  Future<void> _onMoreLoaded(
    InquiryInboxMoreLoaded event,
    Emitter<InquiryInboxState> emit,
  ) async {
    if (state is! InquiryInboxLoaded) return;
    final loaded = state as InquiryInboxLoaded;
    if (!loaded.hasMore) return;

    final result = await _loadInbox(
      statusFilter: loaded.statusFilter,
      listingIdFilter: loaded.listingFilter,
      cursor: loaded.cursor,
      limit: _pageSize,
      adminTier: _adminTier,
    );

    switch (result) {
      case Success<List<Inquiry>>(:final value):
        emit(
          loaded.copyWith(
            inquiries: [...loaded.inquiries, ...value],
            hasMore: value.length == _pageSize,
            cursor: value.isNotEmpty ? value.last.id : null,
          ),
        );
      case FailureResult<List<Inquiry>>():
        // Pagination failure: keep existing results, just stop more-loads.
        emit(loaded.copyWith(hasMore: false));
    }
  }

  Future<void> _onStatusFilterChanged(
    InquiryInboxStatusFilterChanged event,
    Emitter<InquiryInboxState> emit,
  ) async {
    String? listingFilter;
    if (state is InquiryInboxLoaded) {
      listingFilter = (state as InquiryInboxLoaded).listingFilter;
    }
    emit(const InquiryInboxLoading());
    await _fetch(
      emit,
      statusFilter: event.status,
      listingFilter: listingFilter,
    );
  }

  Future<void> _onListingFilterChanged(
    InquiryInboxListingFilterChanged event,
    Emitter<InquiryInboxState> emit,
  ) async {
    InquiryStatus? statusFilter;
    if (state is InquiryInboxLoaded) {
      statusFilter = (state as InquiryInboxLoaded).statusFilter;
    }
    emit(const InquiryInboxLoading());
    await _fetch(
      emit,
      statusFilter: statusFilter,
      listingFilter: event.listingId,
    );
  }

  Future<void> _fetch(
    Emitter<InquiryInboxState> emit, {
    required InquiryStatus? statusFilter,
    required String? listingFilter,
  }) async {
    final result = await _loadInbox(
      statusFilter: statusFilter,
      listingIdFilter: listingFilter,
      limit: _pageSize,
      adminTier: _adminTier,
    );

    switch (result) {
      case Success<List<Inquiry>>(:final value):
        emit(
          InquiryInboxLoaded(
            inquiries: value,
            hasMore: value.length == _pageSize,
            cursor: value.isNotEmpty ? value.last.id : null,
            statusFilter: statusFilter,
            listingFilter: listingFilter,
          ),
        );
      case FailureResult<List<Inquiry>>(:final failure):
        emit(InquiryInboxError(failure));
    }
  }
}
