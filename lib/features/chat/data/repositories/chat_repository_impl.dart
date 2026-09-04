// lib/features/chat/data/repositories/chat_repository_impl.dart
//
// In-app chat — concrete [ChatRepository] delegating to
// [SupabaseChatDatasource].
//
// Principle IX: MUST NOT import supabase_flutter directly (the datasource is
// the sole importer). DTO→entity mapping needs the current user id to compute
// `isMine` / `otherIsPublisher`; the datasource exposes it.

import 'dart:async';
import 'dart:io' show SocketException;

import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/supabase_chat_datasource.dart';

@LazySingleton(as: ChatRepository)
class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._datasource);

  final SupabaseChatDatasource _datasource;

  @override
  String? get currentUserId => _datasource.currentUserId;

  @override
  Future<Result<List<Conversation>>> listConversations() async {
    try {
      final uid = _datasource.currentUserId ?? '';
      final dtos = await _datasource.listConversations();
      return Success(dtos.map((d) => d.toEntity(uid)).toList());
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(
          e.message ?? 'Request timed out',
          cause: e,
          stackTrace: st,
        ),
      );
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('listConversations failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Stream<List<Message>> watchMessages(String conversationId) {
    final uid = _datasource.currentUserId ?? '';
    return _datasource
        .watchMessages(conversationId)
        .map((dtos) => dtos.map((d) => d.toEntity(uid)).toList());
  }

  @override
  Future<Result<List<Message>>> loadOlderMessages({
    required String conversationId,
    required DateTime before,
  }) async {
    try {
      final uid = _datasource.currentUserId ?? '';
      final dtos = await _datasource.loadOlderMessages(
        conversationId: conversationId,
        before: before,
      );
      return Success(dtos.map((d) => d.toEntity(uid)).toList());
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(
          e.message ?? 'Request timed out',
          cause: e,
          stackTrace: st,
        ),
      );
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('loadOlderMessages failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<void>> sendMessage({
    required String conversationId,
    required String body,
  }) async {
    try {
      await _datasource.sendMessage(conversationId: conversationId, body: body);
      return const Success(null);
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(
          e.message ?? 'Request timed out',
          cause: e,
          stackTrace: st,
        ),
      );
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('sendMessage failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<String>> getOrCreateConversation(String listingId) async {
    try {
      final id = await _datasource.getOrCreateConversation(listingId);
      return Success(id);
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(
          e.message ?? 'Request timed out',
          cause: e,
          stackTrace: st,
        ),
      );
    } catch (e, st) {
      return FailureResult(
        UnknownFailure(
          'getOrCreateConversation failed: $e',
          cause: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<void>> markRead(String conversationId) async {
    try {
      await _datasource.markRead(conversationId);
      return const Success(null);
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(
          e.message ?? 'Request timed out',
          cause: e,
          stackTrace: st,
        ),
      );
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('markRead failed: $e', cause: e, stackTrace: st),
      );
    }
  }
}
