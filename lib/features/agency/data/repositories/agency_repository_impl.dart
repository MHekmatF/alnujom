// Phase 19 (spec/019-agencies) — AgencyRepositoryImpl.
//
// Concrete [AgencyRepository] delegating to [SupabaseAgencyDatasource].
// Wraps exceptions in typed [Failure] values per the Phase 14–18 pattern
// (ReportsRepositoryImpl / FavoritesRepositoryImpl).
//
// Per Constitution IX this file MUST NOT import supabase_flutter directly
// beyond [PostgrestException] (typed error-code mapping only).
//
// RPC error-code → Failure mapping:
//   28000  auth_required          → PermissionDeniedFailure
//   42501  not_a_publisher        → ValidationFailure('not_a_publisher')
//   42501  permission_denied      → PermissionDeniedFailure
//   42501  cannot_modify_owner    → ValidationFailure('cannot_modify_owner')
//   42501  cannot_remove_owner    → ValidationFailure('cannot_remove_owner')
//   23505  already_owns_agency    → ValidationFailure('already_owns_agency')
//   23505  open request exists    → ValidationFailure('verification_already_open')
//   23503  user_not_found         → ValidationFailure('user_not_found')
//   22023  invalid_name           → ValidationFailure('invalid_name')
//   22023  invalid_role           → ValidationFailure('invalid_role')
//   P0002  no_pending_invitation  → ValidationFailure('no_pending_invitation')
//   Other PostgrestException      → UnknownFailure

import 'dart:async';
import 'dart:io' show SocketException;

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/agency.dart';
import '../../domain/entities/agency_member.dart';
import '../../domain/repositories/agency_repository.dart';
import '../datasources/supabase_agency_datasource.dart';

@LazySingleton(as: AgencyRepository)
class AgencyRepositoryImpl implements AgencyRepository {
  AgencyRepositoryImpl(this._datasource);

  final SupabaseAgencyDatasource _datasource;

  @override
  Future<Result<String>> createAgency({
    required String name,
    String? description,
    String? phone,
    String? whatsapp,
    String? address,
  }) async {
    try {
      final id = await _datasource.createAgency(
        name: name,
        description: description,
        phone: phone,
        whatsapp: whatsapp,
        address: address,
      );
      return Success(id);
    } on PostgrestException catch (e, st) {
      return FailureResult(_mapRpcError(e, st, 'createAgency'));
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(e.message ?? 'Request timed out', cause: e, stackTrace: st),
      );
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('createAgency failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<Agency?>> loadMyAgency() async {
    try {
      final dto = await _datasource.loadMyAgency();
      return Success(dto?.toEntity());
    } on PostgrestException catch (e, st) {
      return FailureResult(
        UnknownFailure('loadMyAgency failed: ${e.message}', cause: e, stackTrace: st),
      );
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(e.message ?? 'Request timed out', cause: e, stackTrace: st),
      );
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('loadMyAgency failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<Agency?>> loadAgencyById(String agencyId) async {
    try {
      final dto = await _datasource.loadAgencyById(agencyId);
      return Success(dto?.toEntity());
    } on PostgrestException catch (e, st) {
      return FailureResult(
        UnknownFailure('loadAgencyById failed: ${e.message}', cause: e, stackTrace: st),
      );
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(e.message ?? 'Request timed out', cause: e, stackTrace: st),
      );
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('loadAgencyById failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<List<Agency>>> loadMyActiveAgencies() async {
    try {
      final dtos = await _datasource.loadMyActiveAgencies();
      return Success(dtos.map((d) => d.toEntity()).toList());
    } on PostgrestException catch (e, st) {
      return FailureResult(
        UnknownFailure('loadMyActiveAgencies failed: ${e.message}', cause: e, stackTrace: st),
      );
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(e.message ?? 'Request timed out', cause: e, stackTrace: st),
      );
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('loadMyActiveAgencies failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<void>> updateProfile({
    required String agencyId,
    String? name,
    String? description,
    String? phone,
    String? whatsapp,
    String? address,
    String? logoPath,
    String? coverPath,
  }) async {
    try {
      await _datasource.updateProfile(
        agencyId: agencyId,
        name: name,
        description: description,
        phone: phone,
        whatsapp: whatsapp,
        address: address,
        logoPath: logoPath,
        coverPath: coverPath,
      );
      return const Success(null);
    } on PostgrestException catch (e, st) {
      return FailureResult(_mapRpcError(e, st, 'updateProfile'));
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(e.message ?? 'Request timed out', cause: e, stackTrace: st),
      );
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('updateProfile failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<String>> submitVerification({
    required String agencyId,
    required String idDocumentNumber,
    required String registrationNumber,
    List<String>? evidenceUrls,
  }) async {
    try {
      final id = await _datasource.submitVerification(
        agencyId: agencyId,
        idDocumentNumber: idDocumentNumber,
        registrationNumber: registrationNumber,
        evidenceUrls: evidenceUrls,
      );
      return Success(id);
    } on PostgrestException catch (e, st) {
      return FailureResult(_mapRpcError(e, st, 'submitVerification'));
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(e.message ?? 'Request timed out', cause: e, stackTrace: st),
      );
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('submitVerification failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<List<AgencyMember>>> loadMembers(String agencyId) async {
    try {
      final dtos = await _datasource.loadMembers(agencyId);
      return Success(dtos.map((d) => d.toEntity()).toList());
    } on PostgrestException catch (e, st) {
      return FailureResult(
        UnknownFailure('loadMembers failed: ${e.message}', cause: e, stackTrace: st),
      );
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(e.message ?? 'Request timed out', cause: e, stackTrace: st),
      );
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('loadMembers failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<String>> inviteMember({
    required String agencyId,
    required String phone,
    String role = 'agent',
  }) async {
    try {
      final userId = await _datasource.inviteMember(
        agencyId: agencyId,
        phone: phone,
        role: role,
      );
      return Success(userId);
    } on PostgrestException catch (e, st) {
      return FailureResult(_mapRpcError(e, st, 'inviteMember'));
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(e.message ?? 'Request timed out', cause: e, stackTrace: st),
      );
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('inviteMember failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<void>> respondInvitation({
    required String agencyId,
    required bool accept,
  }) async {
    try {
      await _datasource.respondInvitation(agencyId: agencyId, accept: accept);
      return const Success(null);
    } on PostgrestException catch (e, st) {
      return FailureResult(_mapRpcError(e, st, 'respondInvitation'));
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(e.message ?? 'Request timed out', cause: e, stackTrace: st),
      );
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('respondInvitation failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<void>> setMemberRole({
    required String agencyId,
    required String userId,
    required String role,
  }) async {
    try {
      await _datasource.setMemberRole(
        agencyId: agencyId,
        userId: userId,
        role: role,
      );
      return const Success(null);
    } on PostgrestException catch (e, st) {
      return FailureResult(_mapRpcError(e, st, 'setMemberRole'));
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(e.message ?? 'Request timed out', cause: e, stackTrace: st),
      );
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('setMemberRole failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<void>> removeMember({
    required String agencyId,
    required String userId,
  }) async {
    try {
      await _datasource.removeMember(agencyId: agencyId, userId: userId);
      return const Success(null);
    } on PostgrestException catch (e, st) {
      return FailureResult(_mapRpcError(e, st, 'removeMember'));
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(e.message ?? 'Request timed out', cause: e, stackTrace: st),
      );
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('removeMember failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<List<AgencyMember>>> loadMyInvitations() async {
    try {
      final dtos = await _datasource.loadMyInvitations();
      return Success(dtos.map((d) => d.toEntity()).toList());
    } on PostgrestException catch (e, st) {
      return FailureResult(
        UnknownFailure(
          'loadMyInvitations failed: ${e.message}',
          cause: e,
          stackTrace: st,
        ),
      );
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(e.message ?? 'Request timed out', cause: e, stackTrace: st),
      );
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('loadMyInvitations failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> loadAgencyListings({
    required String agencyId,
    String? cursor,
    int limit = 30,
  }) async {
    try {
      final rows = await _datasource.loadAgencyListings(
        agencyId: agencyId,
        cursor: cursor,
        limit: limit,
      );
      return Success(rows);
    } on PostgrestException catch (e, st) {
      return FailureResult(
        UnknownFailure(
          'loadAgencyListings failed: ${e.message}',
          cause: e,
          stackTrace: st,
        ),
      );
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(e.message ?? 'Request timed out', cause: e, stackTrace: st),
      );
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('loadAgencyListings failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<AgencyAnalytics>> loadAnalytics(String agencyId) async {
    try {
      final raw = await _datasource.loadAnalyticsRaw(agencyId);
      return Success(
        AgencyAnalytics(
          memberCount: raw.memberCount,
          listingsByStatus: raw.listingsByStatus,
        ),
      );
    } on PostgrestException catch (e, st) {
      return FailureResult(
        UnknownFailure(
          'loadAnalytics failed: ${e.message}',
          cause: e,
          stackTrace: st,
        ),
      );
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(e.message ?? 'Request timed out', cause: e, stackTrace: st),
      );
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('loadAnalytics failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Maps agency RPC error codes (embedded in [e.message] or [e.code]) to
  /// typed [Failure] subtypes. Falls through to [UnknownFailure] for
  /// unrecognised codes.
  Failure _mapRpcError(PostgrestException e, StackTrace st, String context) {
    final msg = e.message;
    final code = e.code ?? '';

    // Auth-required gate.
    if (msg.contains('auth_required') || code == '28000') {
      return const PermissionDeniedFailure();
    }

    // Generic permission / admin gates.
    if (msg.contains('permission_denied') ||
        msg.contains('not_a_publisher') ||
        msg.contains('cannot_modify_owner') ||
        msg.contains('cannot_remove_owner') ||
        code == '42501') {
      final extracted = _extractCode(msg);
      // not_a_publisher and the owner-protection codes map to ValidationFailure
      // so the UI can show a specific message; generic 42501 → PermissionDenied.
      if (extracted == 'permission_denied') {
        return const PermissionDeniedFailure();
      }
      return ValidationFailure(extracted);
    }

    // Uniqueness / conflict codes.
    if (msg.contains('already_owns_agency') || code == '23505') {
      final extracted = _extractCode(msg);
      return ValidationFailure(
        extracted.isEmpty || extracted == msg ? 'already_owns_agency' : extracted,
      );
    }

    // FK / not-found codes.
    if (msg.contains('user_not_found') || code == '23503') {
      return const ValidationFailure('user_not_found');
    }

    // Input-validation codes.
    if (msg.contains('invalid_name') ||
        msg.contains('invalid_role') ||
        code == '22023') {
      return ValidationFailure(_extractCode(msg));
    }

    // No-pending-invitation (SQLSTATE P0002).
    if (msg.contains('no_pending_invitation') || code == 'P0002') {
      return const ValidationFailure('no_pending_invitation');
    }

    return UnknownFailure(
      '$context failed: ${e.message}',
      cause: e,
      stackTrace: st,
    );
  }

  /// Extracts a short error code key from a [PostgrestException] message.
  String _extractCode(String message) {
    const knownCodes = [
      'not_a_publisher',
      'already_owns_agency',
      'permission_denied',
      'cannot_modify_owner',
      'cannot_remove_owner',
      'user_not_found',
      'invalid_name',
      'invalid_role',
      'no_pending_invitation',
      'verification_already_open',
    ];
    for (final c in knownCodes) {
      if (message.contains(c)) return c;
    }
    return message;
  }
}
