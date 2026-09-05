// Plan A30 — every HTTP request the Supabase client makes gets a deadline.
//
// Review 2026-09-05 §4 G6: `Supabase.initialize` set no timeout and only five
// of thirty-seven repositories called `.timeout()`, so on a poor connection a
// call could spin forever behind a spinner with nothing to say. One client,
// handed to `Supabase.initialize(httpClient:)`, covers PostgREST, Auth,
// Storage and Functions in a single place; Realtime is a websocket and has
// its own heartbeat.
//
// The deadline is on reaching the response, not on reading its body, so a
// large download is not cut off mid-stream. Uploads to Storage get a longer
// allowance: a 10 MB photo over a slow link is the one legitimate reason a
// request takes minutes.
import 'dart:async';

import 'package:http/http.dart' as http;

class TimeoutHttpClient extends http.BaseClient {
  TimeoutHttpClient({
    http.Client? inner,
    this.requestTimeout = const Duration(seconds: 20),
    this.uploadTimeout = const Duration(minutes: 3),
  }) : _inner = inner ?? http.Client();

  final http.Client _inner;

  /// Deadline for ordinary calls (REST, RPC, auth, functions).
  final Duration requestTimeout;

  /// Deadline for Storage calls, which carry file bodies.
  final Duration uploadTimeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final isStorage = request.url.path.contains('/storage/v1/');
    final limit = isStorage ? uploadTimeout : requestTimeout;
    return _inner.send(request).timeout(
      limit,
      onTimeout: () => throw TimeoutException(
        '${request.method} ${request.url.path} exceeded ${limit.inSeconds}s',
        limit,
      ),
    );
  }

  @override
  void close() => _inner.close();
}
