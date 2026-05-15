import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../shared/domain/entities/profile.dart';
import '../../../../shared/domain/value_objects/account_status.dart';
import '../../../../shared/domain/value_objects/publisher_status.dart';

/// Wraps Supabase Postgrest queries against `profiles` + `user_preferences`
/// + the Vault PII RPCs. Constitution IX boundary.
@LazySingleton()
class SupabaseProfileDataSource {
  SupabaseProfileDataSource();

  supabase.SupabaseClient get _client => supabase.Supabase.instance.client;

  Future<Profile?> readCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final row = await _client
        .from('profiles')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
    if (row == null) return null;
    return _profileFromRow(row);
  }

  Future<Profile> updateProfile({
    String? fullName,
    String? username,
    String? phone,
    String? email,
    String? avatarUrl,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('not_authenticated');
    }
    final patch = <String, dynamic>{};
    if (fullName != null) patch['full_name'] = fullName;
    if (username != null) patch['username'] = username;
    if (phone != null) patch['phone'] = phone;
    if (email != null) patch['email'] = email;
    if (avatarUrl != null) patch['avatar_url'] = avatarUrl;
    if (patch.isEmpty) {
      // No-op update — read and return.
      final row = await _client
          .from('profiles')
          .select()
          .eq('user_id', user.id)
          .single();
      return _profileFromRow(row);
    }
    final row = await _client
        .from('profiles')
        .update(patch)
        .eq('user_id', user.id)
        .select()
        .single();
    return _profileFromRow(row);
  }

  Future<void> updateLocale(String localeCode) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('not_authenticated');
    await _client
        .from('user_preferences')
        .update({'locale': localeCode})
        .eq('user_id', user.id);
  }

  // ─── Vault PII RPCs ───
  Future<String?> readPiiField(String fieldName) async {
    final result = await _client.rpc(
      'app_vault_secret_for_self',
      params: {'field_name': fieldName},
    );
    return result as String?;
  }

  Future<void> writePiiTextField({
    required String fieldName,
    required String value,
  }) async {
    await _client.rpc(
      'app_vault_set_secret_for_self',
      params: {'field_name': fieldName, 'p_value': value},
    );
  }

  Future<void> writePrivateContactMethods(Map<String, dynamic> methods) async {
    await _client.rpc(
      'app_vault_set_private_contact_methods_for_self',
      params: {'p_methods': methods},
    );
  }

  Profile _profileFromRow(Map<String, dynamic> row) {
    return Profile(
      userId: row['user_id'] as String,
      fullName: row['full_name'] as String?,
      username: row['username'] as String?,
      phone: row['phone'] as String?,
      email: row['email'] as String?,
      avatarUrl: row['avatar_url'] as String?,
      accountStatus: _parseAccountStatus(row['account_status'] as String?),
      publisherStatus: _parsePublisherStatus(
        row['publisher_status'] as String?,
      ),
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  AccountStatus _parseAccountStatus(String? raw) {
    return switch (raw) {
      'pending' => AccountStatus.pending,
      'approved' => AccountStatus.approved,
      'rejected' => AccountStatus.rejected,
      'suspended' => AccountStatus.suspended,
      'deleted' => AccountStatus.deleted,
      _ => AccountStatus.pending,
    };
  }

  PublisherStatus _parsePublisherStatus(String? raw) {
    return switch (raw) {
      'pending' => PublisherStatus.pending,
      'approved' => PublisherStatus.approved,
      'rejected' => PublisherStatus.rejected,
      'suspended' => PublisherStatus.suspended,
      'deleted' => PublisherStatus.deleted,
      _ => PublisherStatus.pending,
    };
  }
}
