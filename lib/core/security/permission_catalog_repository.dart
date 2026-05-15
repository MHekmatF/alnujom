import 'package:equatable/equatable.dart';

/// Abstract domain interface for loading a user's effective permission set.
/// No Supabase import — Constitution IX.
abstract class PermissionCatalogRepository {
  Future<Set<String>> loadEffectivePermissions();
}

/// Sealed hierarchy for typed error propagation from the repository.
sealed class PermissionLoadFailure extends Equatable {
  const PermissionLoadFailure();

  @override
  List<Object?> get props => [];
}

class NetworkErrorPermission extends PermissionLoadFailure {
  const NetworkErrorPermission([this.message]);
  final String? message;

  @override
  List<Object?> get props => [message];
}

class NotAuthenticatedPermission extends PermissionLoadFailure {
  const NotAuthenticatedPermission();
}

class UnknownPermissionError extends PermissionLoadFailure {
  const UnknownPermissionError([this.cause]);
  final Object? cause;

  @override
  List<Object?> get props => [cause];
}
