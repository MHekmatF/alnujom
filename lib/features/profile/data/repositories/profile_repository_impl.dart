import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart' show Locale;
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/errors/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../shared/domain/entities/profile.dart';
import '../../domain/entities/private_contact_methods.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/supabase_profile_datasource.dart';

@LazySingleton(as: ProfileRepository)
class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._ds, this._logger);

  static const _tag = 'ProfileRepositoryImpl';

  final SupabaseProfileDataSource _ds;
  final AppLogger _logger;

  final _profileController = StreamController<Profile>.broadcast();

  @override
  Stream<Profile> get currentProfileStream => _profileController.stream;

  @override
  Future<Result<Profile>> getCurrentProfile() async {
    try {
      final profile = await _ds.readCurrentProfile();
      if (profile == null) {
        return const FailureResult(NotAuthenticated());
      }
      _profileController.add(profile);
      return Success(profile);
    } on Object catch (error, stackTrace) {
      return FailureResult(_mapError(error, stackTrace));
    }
  }

  @override
  Future<Result<Profile>> refresh() => getCurrentProfile();

  @override
  Future<Result<Profile>> updateProfile({
    String? fullName,
    String? username,
    String? phone,
    String? email,
    String? avatarUrl,
  }) async {
    try {
      final profile = await _ds.updateProfile(
        fullName: fullName,
        username: username,
        phone: phone,
        email: email,
        avatarUrl: avatarUrl,
      );
      _profileController.add(profile);
      return Success(profile);
    } on PostgrestException catch (error, stackTrace) {
      // 23505 = unique_violation
      if (error.code == '23505') {
        final detail = error.message.toLowerCase();
        if (detail.contains('username')) {
          return FailureResult(
            UsernameTaken(cause: error, stackTrace: stackTrace),
          );
        }
        // Phone collisions surface here too — registration treats them as
        // AccountAlreadyExists at the auth-layer caller's discretion.
        return FailureResult(
          UnknownProfileError(
            'unique_violation:${error.message}',
            cause: error,
            stackTrace: stackTrace,
          ),
        );
      }
      return FailureResult(_mapError(error, stackTrace));
    } on Object catch (error, stackTrace) {
      return FailureResult(_mapError(error, stackTrace));
    }
  }

  @override
  Future<Result<void>> updateLocale(Locale locale) async {
    try {
      await _ds.updateLocale(locale.languageCode);
      return const Success(null);
    } on Object catch (error, stackTrace) {
      return FailureResult(_mapError(error, stackTrace));
    }
  }

  @override
  Future<Result<PiiBundle>> loadPii() async {
    try {
      final results = await Future.wait([
        _ds.readPiiField('legal_name'),
        _ds.readPiiField('national_id'),
        _ds.readPiiField('private_contact_methods'),
      ]);
      final legal = results[0];
      final nat = results[1];
      final methodsRaw = results[2];
      PrivateContactMethods? methods;
      if (methodsRaw != null) {
        try {
          final decoded = jsonDecode(methodsRaw) as Map<String, dynamic>;
          methods = PrivateContactMethods.fromJson(decoded);
        } on Object catch (error, stackTrace) {
          _logger.warning(
            'Failed to parse private_contact_methods JSON.',
            error: error,
            stackTrace: stackTrace,
            tag: _tag,
          );
        }
      }
      return Success(
        PiiBundle(
          legalName: legal,
          nationalId: nat,
          privateContactMethods: methods,
        ),
      );
    } on Object catch (error, stackTrace) {
      return FailureResult(_mapError(error, stackTrace));
    }
  }

  @override
  Future<Result<void>> updateLegalName(String legalName) async {
    try {
      await _ds.writePiiTextField(
        fieldName: 'legal_name',
        value: legalName,
      );
      return const Success(null);
    } on Object catch (error, stackTrace) {
      return FailureResult(_mapError(error, stackTrace));
    }
  }

  @override
  Future<Result<void>> updateNationalId(String nationalId) async {
    try {
      await _ds.writePiiTextField(
        fieldName: 'national_id',
        value: nationalId,
      );
      return const Success(null);
    } on Object catch (error, stackTrace) {
      return FailureResult(_mapError(error, stackTrace));
    }
  }

  @override
  Future<Result<void>> updatePrivateContactMethods(
    PrivateContactMethods methods,
  ) async {
    try {
      await _ds.writePrivateContactMethods(methods.toJson());
      return const Success(null);
    } on Object catch (error, stackTrace) {
      return FailureResult(_mapError(error, stackTrace));
    }
  }

  ProfileFailure _mapError(Object error, StackTrace stackTrace) {
    _logger.warning(
      'Profile data error.',
      error: error,
      stackTrace: stackTrace,
      tag: _tag,
    );
    if (error.toString().contains('not_authenticated')) {
      return NotAuthenticated(cause: error, stackTrace: stackTrace);
    }
    return UnknownProfileError(
      error.toString(),
      cause: error,
      stackTrace: stackTrace,
    );
  }

  @override
  @disposeMethod
  Future<void> dispose() async {
    await _profileController.close();
  }
}
