// lib/features/chat/data/datasources/supabase_chat_datasource.dart
//
// In-app chat — Supabase I/O for the chat feature.
//
// Principle IX: sole importer of `package:supabase_flutter` under
// `lib/features/chat/`. All table/RPC names are string-keyed so the project
// compiles without the DB applied.
//
// Operations:
//   - `from('conversations')` select joined w/ listing title + main image
//   - `from('messages').stream(...)` live thread (Realtime)
//   - `from('messages').insert(...)` send (sender_user_id DB-defaulted)
//   - `rpc('get_or_create_conversation')` open/create from a listing
//   - `from('messages').update(read_at=now())` mark counterpart's msgs read

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../dtos/conversation_dto.dart';
import '../dtos/message_dto.dart';

@injectable
class SupabaseChatDatasource {
  SupabaseChatDatasource(this._client);

  final supabase.SupabaseClient _client;

  /// The id of the signed-in user, or `null` when signed out. Used by the
  /// mapping layer to compute `isMine` / `otherIsPublisher`.
  String? get currentUserId => _client.auth.currentUser?.id;

  /// Embedded-selects projection: the conversation columns plus the listing
  /// title and its main image storage path (LEFT JOIN narrowed to is_main +
  /// kind='image' so we surface at most one thumbnail row).
  static const String _conversationSelect =
      'id, listing_id, buyer_user_id, publisher_user_id, '
      'created_at, last_message_at, '
      'listing:listings(title, listing_media(storage_path, thumbnail_path, is_main, kind))';

  /// Loads every conversation the caller participates in (RLS scopes it to
  /// rows where auth.uid() is the buyer or publisher), newest-activity-first.
  Future<List<ConversationDto>> listConversations() async {
    final rows = await _client
        .from('conversations')
        .select(_conversationSelect)
        .order('last_message_at', ascending: false);

    return (rows as List<dynamic>)
        .map((r) => _mapConversationRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Resolves the listing main-image public URL from the embedded
  /// `listing.listing_media` rows (first is_main image), mirroring the home
  /// feed's storage idiom.
  ConversationDto _mapConversationRow(Map<String, dynamic> row) {
    final dto = ConversationDto.fromJson(row);
    final listing = row['listing'];
    if (listing is! Map) return dto;
    final media = listing['listing_media'];
    if (media is! List) return dto;

    Map? mainRow;
    for (final m in media) {
      if (m is Map && m['is_main'] == true && m['kind'] == 'image') {
        mainRow = m;
        break;
      }
    }
    // Plan A18 — prefer the card-sized copy, fall back to the full file.
    final thumb = mainRow?['thumbnail_path'];
    final path = (thumb is String && thumb.isNotEmpty)
        ? thumb
        : mainRow?['storage_path'];
    if (path is! String || path.isEmpty) return dto;
    final url = _client.storage.from('listing-images').getPublicUrl(path);
    return dto.copyWithListingImageUrl(url);
  }

  /// A live stream of the thread's messages (oldest-first). Backed by
  /// Realtime — INSERTs/UPDATEs (read receipts) push new lists automatically.
  Stream<List<MessageDto>> watchMessages(String conversationId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map(
          (rows) => rows
              .map((r) => MessageDto.fromJson(Map<String, dynamic>.from(r)))
              .toList(),
        );
  }

  /// Sends a message. NEVER set `sender_user_id` — the DB defaults it to
  /// auth.uid() (per the messaging contract).
  Future<void> sendMessage({
    required String conversationId,
    required String body,
  }) async {
    await _client.from('messages').insert({
      'conversation_id': conversationId,
      'body': body,
    });
  }

  /// Opens (or creates) the conversation between the caller and the listing's
  /// publisher; returns the conversation id. Errors server-side if the caller
  /// is messaging their own listing.
  Future<String> getOrCreateConversation(String listingId) async {
    final result = await _client.rpc(
      'get_or_create_conversation',
      params: {'p_listing_id': listingId},
    );
    return result as String;
  }

  /// Marks the COUNTERPART's unread messages in this conversation as read
  /// (read_at = now()). Own messages and already-read rows are untouched.
  Future<void> markRead(String conversationId) async {
    final uid = currentUserId;
    if (uid == null) return;
    await _client
        .from('messages')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('conversation_id', conversationId)
        .neq('sender_user_id', uid)
        .isFilter('read_at', null);
  }
}
