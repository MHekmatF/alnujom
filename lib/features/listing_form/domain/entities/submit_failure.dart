import 'package:equatable/equatable.dart';

class SubmitFailure extends Equatable {
  const SubmitFailure({
    this.missingFields = const <String>[],
    this.rawSqlState,
    this.userFacingMessage,
  });

  final List<String> missingFields;
  final String? rawSqlState;
  final String? userFacingMessage;

  bool get hasMissingFields => missingFields.isNotEmpty;

  @override
  List<Object?> get props => [missingFields, rawSqlState, userFacingMessage];
}

class SubmitListingFailureException implements Exception {
  SubmitListingFailureException({
    this.missingFields = const <String>[],
    this.sqlState,
    this.message,
  });

  final List<String> missingFields;
  final String? sqlState;
  final String? message;

  @override
  String toString() =>
      'SubmitListingFailureException(sqlState: $sqlState, missingFields: $missingFields, message: $message)';
}
