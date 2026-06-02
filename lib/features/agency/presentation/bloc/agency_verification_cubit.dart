// lib/features/agency/presentation/bloc/agency_verification_cubit.dart
//
// Phase 19 (spec/019-agencies) Sub-Phase H (T047).
// Loads the agency (for the status banner) + submits a verification request.
// Submit calls SubmitAgencyVerification; status is read from the loaded Agency.
// Zero Supabase imports (Constitution IX).
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/agency.dart';
import '../../domain/entities/agency_verification_request.dart';
import '../../domain/usecases/load_agency_by_id.dart';
import '../../domain/usecases/load_my_verification_request.dart';
import '../../domain/usecases/submit_agency_verification.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

sealed class AgencyVerificationState {
  const AgencyVerificationState();
}

final class AgencyVerificationLoading extends AgencyVerificationState {
  const AgencyVerificationLoading();
}

final class AgencyVerificationReady extends AgencyVerificationState {
  const AgencyVerificationReady({
    required this.agency,
    this.request,
    this.submitting = false,
    this.submitted = false,
    this.errorCode,
  });

  final Agency agency;

  /// Latest verification request (for the rejection reason when rejected); D-3.
  final AgencyVerificationRequest? request;
  final bool submitting;
  final bool submitted;

  /// Failure code of the last submit attempt; null when none.
  final String? errorCode;

  AgencyVerificationReady copyWith({
    Agency? agency,
    AgencyVerificationRequest? request,
    bool? submitting,
    bool? submitted,
    String? errorCode,
    bool clearError = false,
  }) {
    return AgencyVerificationReady(
      agency: agency ?? this.agency,
      request: request ?? this.request,
      submitting: submitting ?? this.submitting,
      submitted: submitted ?? this.submitted,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
    );
  }
}

final class AgencyVerificationError extends AgencyVerificationState {
  const AgencyVerificationError();
}

// ---------------------------------------------------------------------------
// Cubit
// ---------------------------------------------------------------------------

@injectable
class AgencyVerificationCubit extends Cubit<AgencyVerificationState> {
  AgencyVerificationCubit(
    this._loadAgencyById,
    this._submitVerification,
    this._loadRequest,
  ) : super(const AgencyVerificationLoading());

  final LoadAgencyById _loadAgencyById;
  final SubmitAgencyVerification _submitVerification;
  final LoadMyVerificationRequest _loadRequest;

  Future<void> load(String agencyId) async {
    emit(const AgencyVerificationLoading());
    final result = await _loadAgencyById(agencyId);
    if (isClosed) return;
    switch (result) {
      case Success<Agency?>(:final value):
        if (value == null) {
          emit(const AgencyVerificationError());
        } else {
          // Also load the latest verification request (best-effort) so a
          // rejected agency can surface its rejection reason (D-3).
          final reqResult = await _loadRequest(agencyId);
          if (isClosed) return;
          final request = reqResult is Success<AgencyVerificationRequest?>
              ? reqResult.value
              : null;
          emit(AgencyVerificationReady(agency: value, request: request));
        }
      case FailureResult<Agency?>():
        emit(const AgencyVerificationError());
    }
  }

  Future<void> submit({
    required String agencyId,
    required String idDocumentNumber,
    required String registrationNumber,
    List<String>? evidenceUrls,
  }) async {
    final current = state;
    if (current is! AgencyVerificationReady) return;
    emit(current.copyWith(submitting: true, clearError: true));

    final result = await _submitVerification(
      agencyId: agencyId,
      idDocumentNumber: idDocumentNumber,
      registrationNumber: registrationNumber,
      evidenceUrls: evidenceUrls,
    );
    if (isClosed) return;
    switch (result) {
      case Success<String>():
        emit(current.copyWith(submitting: false, submitted: true));
      case FailureResult<String>(:final failure):
        final code = failure is ValidationFailure
            ? failure.code
            : (failure is PermissionDeniedFailure
                ? 'permission_denied'
                : 'unknown');
        emit(current.copyWith(submitting: false, errorCode: code));
    }
  }
}
