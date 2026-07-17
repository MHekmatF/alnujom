// lib/features/chat/presentation/bloc/chat_thread_cubit.dart
//
// In-app chat — ChatThreadCubit: drives one conversation thread.
//
// On [open] it subscribes to the live message stream ([WatchMessages]) and
// fires a one-shot [MarkConversationRead]. [send] inserts a message AND shows it
// optimistically (FUNC-H3 — the Realtime echo for an own-insert is unreliable, so
// waiting on it would leave the thread on "no messages yet" right after sending);
// the optimistic bubble reconciles against the stream by body once the real row
// arrives. States: loading / messages (possibly empty) / error.

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

  // FUNC-H3 — optimistic outbox. Sent messages are shown immediately and kept
  // here until the stream surfaces the matching server row, so the sender never
  // sees "no messages yet" after a successful send even when the realtime echo
  // for their own INSERT never arrives.
  final List<Message> _pending = [];
  List<Message> _serverMessages = const [];
  int _pendingSeq = 0;

  /// Subscribes to the thread's live stream and marks the counterpart's
  /// messages read. Idempotent — safe to call once from the page's initState.
  void open(String conversationId) {
    if (_conversationId == conversationId) return;
    _conversationId = conversationId;
    _sub?.cancel();
    _sub = _watchMessages(conversationId).listen(
      (messages) {
        if (isClosed) return;
        _serverMessages = messages;
        _reconcilePending();
        emit(ChatThreadState.messages(_merged()));
      },
      onError: (Object _) {
        if (isClosed) return;
        emit(const ChatThreadState.error());
      },
    );
    // Fire-and-forget read receipt for already-delivered messages.
    unawaited(_markRead(conversationId));
  }

  /// Sends [body] (trimmed). No-op for blank input. Shows the message immediately
  /// (FUNC-H3) and reconciles it against the stream once the server row arrives;
  /// rolls the optimistic bubble back if the send fails.
  Future<void> send(String body) async {
    final id = _conversationId;
    final trimmed = body.trim();
    if (id == null || trimmed.isEmpty) return;

    final optimistic = Message(
      id: 'pending-${_pendingSeq++}',
      body: trimmed,
      isMine: true,
      createdAt: DateTime.now().toUtc(),
    );
    _pending.add(optimistic);
    if (!isClosed) emit(ChatThreadState.messages(_merged()));

    try {
      await _sendMessage(conversationId: id, body: trimmed);
    } catch (_) {
      _pending.remove(optimistic);
      if (!isClosed) emit(ChatThreadState.messages(_merged()));
      rethrow;
    }
  }

  /// The authoritative stream list plus any still-unconfirmed optimistic
  /// messages (appended last — they are the newest).
  List<Message> _merged() =>
      _pending.isEmpty ? _serverMessages : [..._serverMessages, ..._pending];

  /// Drops optimistic messages once the stream surfaces a matching own-message
  /// (same body, created no earlier than the optimistic one minus clock slop).
  void _reconcilePending() {
    if (_pending.isEmpty) return;
    final serverMine = _serverMessages.where((m) => m.isMine).toList();
    _pending.removeWhere(
      (p) => serverMine.any(
        (s) =>
            s.body == p.body &&
            !s.createdAt.isBefore(
              p.createdAt.subtract(const Duration(minutes: 5)),
            ),
      ),
    );
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
