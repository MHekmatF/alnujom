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
//
// Plan A19 — the stream is a WINDOW, not the thread. It carries the newest
// [kChatPageSize] messages; [loadOlder] pages back from there. Everything is
// held newest-first, which is the order the reversed ListView wants and the
// order the stream actually returns.

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../domain/entities/message.dart';
import '../../../user_blocks/domain/usecases/block_user.dart';
import '../../../user_blocks/domain/usecases/is_user_blocked.dart';
import '../../../user_blocks/domain/usecases/unblock_user.dart';
import '../../domain/usecases/load_conversation_counterpart.dart';
import '../../domain/usecases/load_older_messages.dart';
import '../../domain/usecases/mark_conversation_read.dart';
import '../../domain/usecases/send_message.dart';
import '../../domain/usecases/watch_messages.dart';

part 'chat_thread_state.dart';

@injectable
class ChatThreadCubit extends Cubit<ChatThreadState> {
  ChatThreadCubit(
    this._watchMessages,
    this._sendMessage,
    this._markRead,
    this._loadOlderMessages,
    this._loadCounterpart,
    this._isUserBlocked,
    this._blockUser,
    this._unblockUser,
  ) : super(const ChatThreadState.loading());

  final WatchMessages _watchMessages;
  final SendMessage _sendMessage;
  final MarkConversationRead _markRead;
  final LoadOlderMessages _loadOlderMessages;
  final LoadConversationCounterpart _loadCounterpart;
  final IsUserBlocked _isUserBlocked;
  final BlockUser _blockUser;
  final UnblockUser _unblockUser;

  // Plan A29 — who the other person is, and whether we have blocked them.
  String? _otherUserId;
  bool _counterpartBlocked = false;

  StreamSubscription<List<Message>>? _sub;
  String? _conversationId;

  // FUNC-H3 — optimistic outbox. Sent messages are shown immediately and kept
  // here until the stream surfaces the matching server row, so the sender never
  // sees "no messages yet" after a successful send even when the realtime echo
  // for their own INSERT never arrives. Held in send order; newest last.
  final List<Message> _pending = [];
  int _pendingSeq = 0;

  // Every server message the thread has shown, by id — the live window plus
  // whatever [loadOlder] has fetched. A map because the two sources overlap at
  // the seam, and because a message that scrolls out of the fixed-size window
  // as newer ones arrive must stay on screen rather than leaving a hole.
  //
  // The window WRITES OVER what is here (its rows carry the current `read_at`);
  // a fetched older page only fills gaps, so a stale history row can never
  // clobber a live one.
  final Map<String, Message> _known = {};

  bool _atStart = false;
  bool _loadingOlder = false;
  bool _olderFailed = false;
  bool _pagedBack = false;

  /// Subscribes to the thread's live stream and marks the counterpart's
  /// messages read. Idempotent — safe to call once from the page's initState.
  void open(String conversationId) {
    if (_conversationId == conversationId) return;
    _conversationId = conversationId;
    _sub?.cancel();
    _sub = _watchMessages(conversationId).listen(
      (window) {
        if (isClosed) return;
        for (final m in window) {
          _known[m.id] = m;
        }
        // A window shorter than a full page means the whole thread fits in it.
        // Once we have paged back the window says nothing about the tail, so
        // stop reading it that way.
        if (!_pagedBack && window.length < kChatPageSize) _atStart = true;
        _reconcilePending();
        _emitMessages();
      },
      onError: (Object _) {
        if (isClosed) return;
        emit(const ChatThreadState.error());
      },
    );
    // Fire-and-forget read receipt for already-delivered messages.
    unawaited(_markRead(conversationId));
    // Plan A29 — learn who the other person is, behind the rendered thread.
    unawaited(_resolveCounterpart(conversationId));
  }

  Future<void> _resolveCounterpart(String conversationId) async {
    final who = await _loadCounterpart(conversationId);
    if (isClosed || who is! Success<String?>) return;
    final other = who.value;
    if (other == null) return;
    _otherUserId = other;
    final blocked = await _isUserBlocked(other);
    if (isClosed) return;
    if (blocked is Success<bool>) _counterpartBlocked = blocked.value;
    if (state.status == ChatThreadStatus.messages) _emitMessages();
  }

  /// Plan A29 — block the other person. Returns whether it took effect.
  Future<bool> blockCounterpart() async {
    final other = _otherUserId;
    if (other == null) return false;
    final result = await _blockUser(other);
    if (isClosed) return false;
    if (result is! Success<void>) return false;
    _counterpartBlocked = true;
    if (state.status == ChatThreadStatus.messages) _emitMessages();
    return true;
  }

  /// Plan A29 — lift the block. Returns whether it took effect.
  Future<bool> unblockCounterpart() async {
    final other = _otherUserId;
    if (other == null) return false;
    final result = await _unblockUser(other);
    if (isClosed) return false;
    if (result is! Success<void>) return false;
    _counterpartBlocked = false;
    if (state.status == ChatThreadStatus.messages) _emitMessages();
    return true;
  }

  /// Fetches the page of history before the oldest message on screen. No-op
  /// while one is in flight, or once the thread has been read to its start.
  Future<void> loadOlder() async {
    final id = _conversationId;
    if (id == null || _atStart || _loadingOlder) return;

    final known = _sorted();
    if (known.isEmpty) return;
    final oldest = known.last;

    _loadingOlder = true;
    _olderFailed = false;
    _emitMessages();

    final result = await _loadOlderMessages(
      conversationId: id,
      before: oldest.createdAt,
    );
    if (isClosed) return;

    _loadingOlder = false;
    switch (result) {
      case Success(value: final page):
        _pagedBack = true;
        for (final m in page) {
          _known.putIfAbsent(m.id, () => m);
        }
        if (page.length < kChatPageSize) _atStart = true;
      case FailureResult():
        // Keep the sentinel on screen so the user can ask again; the page
        // itself swaps its spinner for a retry affordance.
        _olderFailed = true;
    }
    _emitMessages();
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
    if (!isClosed) _emitMessages();

    try {
      await _sendMessage(conversationId: id, body: trimmed);
    } catch (_) {
      _pending.remove(optimistic);
      if (!isClosed) _emitMessages();
      rethrow;
    }
  }

  void _emitMessages() {
    emit(
      ChatThreadState.messages(
        _merged(),
        // Nothing to page back through until the thread has something in it.
        hasMore: !_atStart && _known.isNotEmpty,
        loadingOlder: _loadingOlder,
        olderFailed: _olderFailed,
        otherUserId: _otherUserId,
        counterpartBlocked: _counterpartBlocked,
      ),
    );
  }

  /// Newest-first: unconfirmed optimistic messages (the newest thing there is)
  /// ahead of every server message we know about.
  List<Message> _merged() {
    final known = _sorted();
    if (_pending.isEmpty) return known;
    return [..._pending.reversed, ...known];
  }

  /// Every known server message, newest-first. Ties are broken on id so the
  /// list order is stable across rebuilds when two rows share a timestamp.
  List<Message> _sorted() {
    final list = _known.values.toList()
      ..sort((a, b) {
        final byTime = b.createdAt.compareTo(a.createdAt);
        return byTime != 0 ? byTime : b.id.compareTo(a.id);
      });
    return list;
  }

  /// Drops optimistic messages once the stream surfaces a matching own-message
  /// (same body, created no earlier than the optimistic one minus clock slop).
  void _reconcilePending() {
    if (_pending.isEmpty) return;
    final serverMine = _known.values.where((m) => m.isMine).toList();
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
