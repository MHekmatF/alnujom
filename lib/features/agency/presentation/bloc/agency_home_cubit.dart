// lib/features/agency/presentation/bloc/agency_home_cubit.dart
//
// Phase 19 (spec/019-agencies) Sub-Phase H (T045).
// Resolves the agency-home state: none (no agency) / owner / member, by
// combining LoadMyAgency (owner-only) with LoadMyActiveAgencies (owner OR
// invited member). Mirrors the reports cubits' @injectable + sealed-state
// pattern. Zero Supabase imports (Constitution IX).
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/agency.dart';
import '../../domain/usecases/create_agency.dart';
import '../../domain/usecases/load_my_active_agencies.dart';
import '../../domain/usecases/load_my_agency.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

sealed class AgencyHomeState {
  const AgencyHomeState();
}

final class AgencyHomeLoading extends AgencyHomeState {
  const AgencyHomeLoading();
}

/// The user owns no agency (and is a member of none) — the create form shows.
final class AgencyHomeNone extends AgencyHomeState {
  const AgencyHomeNone();
}

/// The user owns an agency (the management surface shows, full controls).
final class AgencyHomeOwner extends AgencyHomeState {
  const AgencyHomeOwner(this.agency);

  final Agency agency;
}

/// The user is an active member of an agency they do NOT own (management
/// surface in member mode — no owner-only actions).
final class AgencyHomeMember extends AgencyHomeState {
  const AgencyHomeMember(this.agency);

  final Agency agency;
}

final class AgencyHomeError extends AgencyHomeState {
  const AgencyHomeError();
}

/// Transient state while the create-agency RPC is in flight (the create form
/// disables its submit button and shows a spinner).
final class AgencyHomeCreating extends AgencyHomeState {
  const AgencyHomeCreating();
}

/// The create-agency RPC failed; [messageKey] is the failure code (e.g.
/// `not_a_publisher`, `already_owns_agency`, `invalid_name`) the form maps to
/// a localized message.
final class AgencyHomeCreateFailure extends AgencyHomeState {
  const AgencyHomeCreateFailure(this.messageKey);

  final String messageKey;
}

// ---------------------------------------------------------------------------
// Cubit
// ---------------------------------------------------------------------------

@injectable
class AgencyHomeCubit extends Cubit<AgencyHomeState> {
  AgencyHomeCubit(
    this._loadMyAgency,
    this._loadMyActiveAgencies,
    this._createAgency,
  ) : super(const AgencyHomeLoading());

  final LoadMyAgency _loadMyAgency;
  final LoadMyActiveAgencies _loadMyActiveAgencies;
  final CreateAgency _createAgency;

  Future<void> load() async {
    emit(const AgencyHomeLoading());

    final ownedResult = await _loadMyAgency();
    if (ownedResult is Success<Agency?> && ownedResult.value != null) {
      emit(AgencyHomeOwner(ownedResult.value!));
      return;
    }
    if (ownedResult is FailureResult<Agency?>) {
      emit(const AgencyHomeError());
      return;
    }

    // No owned agency — check for a membership in someone else's agency.
    final memberResult = await _loadMyActiveAgencies();
    switch (memberResult) {
      case Success<List<Agency>>(:final value):
        if (value.isEmpty) {
          emit(const AgencyHomeNone());
        } else {
          emit(AgencyHomeMember(value.first));
        }
      case FailureResult<List<Agency>>():
        emit(const AgencyHomeError());
    }
  }

  /// Calls `create_agency`; on success reloads the home state so the create
  /// form is replaced by the owner management surface.
  Future<void> create({
    required String name,
    String? description,
    String? phone,
    String? whatsapp,
    String? address,
  }) async {
    emit(const AgencyHomeCreating());
    final result = await _createAgency(
      name: name,
      description: description,
      phone: phone,
      whatsapp: whatsapp,
      address: address,
    );
    switch (result) {
      case Success<String>():
        await load();
      case FailureResult<String>(:final failure):
        emit(AgencyHomeCreateFailure(_failureKey(failure)));
    }
  }

  String _failureKey(Failure failure) {
    if (failure is ValidationFailure) return failure.code;
    if (failure is PermissionDeniedFailure) return 'permission_denied';
    return 'unknown';
  }
}
