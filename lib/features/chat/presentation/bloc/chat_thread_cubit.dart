// lib/features/chat/presentation/bloc/chat_thread_cubit.dart
//
// In-app chat — ChatThreadCubit: drives one conversation thread.
//
// On [open] it subscribes to the live message stream ([WatchMessages]) and
// fires a one-shot [MarkConversationRead]. [send] inserts a message (the
// Realtime stream echoes it back, so we don't optimistically append). States:
// loading / messages (possibly empty) / error.

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/message.dart';
import '../../domain/usecases/mark_conversation_read.dart';
import '../../domain/usecases/send_message.dart';
import '../../domain/usecases/watch_messages.dart';

part 'chat_thread_state.dart';

@injectable
class ChatThreadCubit extends Cubit<ChatThreadState> {
  ChatThreadCubit(this._watchMessages, this._sendMessage, this._markRead)
    : super(const ChatThreadState.loading());

  final WatchMessages _watchMessages;
  final SendMessage _sendMessage;
  final MarkConversationRead _markRead;

  StreamSubscription<List<Message>>? _sub;
  String? _conversationId;

  /// Subscribes to the thread's live stream and marks the counterpart's
  /// messages read. Idempotent — safe to call once from the page's initState.
  void open(String conversationId) {
    if (_conversationId == conversationId) return;
    _conversationId = conversationId;
    _sub?.cancel();
    _sub = _watchMessages(conversationId).listen(
      (messages) {
        if (isClosed) return;
        emit(ChatThreadState.messages(messages));
      },
      onError: (Object _) {
        if (isClosed) return;
        emit(const ChatThreadState.error());
      },
    );
    // Fire-and-forget read receipt for already-delivered messages.
    unawaited(_markRead(conversationId));
  }

  /// Sends [body] (trimmed). No-op for blank input. The Realtime stream echoes
  /// the inserted row back, so we don't append optimistically.
  Future<void> send(String body) async {
    final id = _conversationId;
    final trimmed = body.trim();
    if (id == null || trimmed.isEmpty) return;
    await _sendMessage(conversationId: id, body: trimmed);
  }

  /// Re-marks the thread read (e.g. after new inbound messages arrive while the
  /// page is open).
  Future<void> markRead() async {
    final id = _conversationId;
    if (id == null) return;
    await _markRead(id);
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
