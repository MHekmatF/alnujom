import '../errors/result.dart';
import 'types/auth_state.dart';
import 'types/realtime_channel.dart';

abstract interface class SupabaseClientWrapper {
  bool get isInitialized;

  Future<Result<void>> initialize({
    required String url,
    required String anonKey,
  });

  Future<void> dispose();

  Stream<AuthState> authStateChanges();

  Future<Result<List<Map<String, dynamic>>>> selectRows({
    required String table,
    Map<String, dynamic>? filters,
    int? limit,
  });

  Future<Result<dynamic>> rpc(String fn, {Map<String, dynamic>? params});

  Future<Result<String>> uploadObject({
    required String bucket,
    required String path,
    required List<int> bytes,
  });

  RealtimeChannel realtimeChannel(String topic);
}
