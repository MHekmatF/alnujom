# Contract: SupabaseClientWrapper

**Layer**: `lib/core/network/`
**Constitution**: Principle IX (Future Backend Portability)
**Spec requirement**: FR-009 (no `package:supabase_flutter` import outside this wrapper)
**Phase 1 status**: interface ships, minimal impl ships, behavior beyond construction + null-safety is exercised only by Phase 4+ features.

## Purpose

A project-defined boundary around the Supabase SDK. All `lib/` code that needs the backend MUST go through this interface; only `supabase_client_wrapper_impl.dart` is allowed to import `package:supabase_flutter`. A v2 backend swap edits this one file's body, not 24 phases of features.

## Phase 1 surface area

The interface ships with **only the methods Phase 1 itself exercises**, plus stubs for the surface later phases need. This avoids a dead-on-arrival API and avoids "we need more methods than we knew" surprises in Phase 4. Stubs may throw `UnimplementedError` until the phase that needs them lands.

### Required (used in Phase 1)

```dart
abstract interface class SupabaseClientWrapper {
  /// Returns true iff [initialize] has completed successfully.
  bool get isInitialized;

  /// Initializes the underlying Supabase client. MUST tolerate missing/invalid
  /// configuration: returns FailureResult(ConfigFailure) instead of throwing.
  /// (FR-013, edge case "Backend configuration missing or invalid at launch".)
  Future<Result<void>> initialize({
    required String url,
    required String anonKey,
  });

  /// Disposes resources. Safe to call even if [initialize] never succeeded.
  Future<void> dispose();
}
```

### Stubs (declared but throw `UnimplementedError` until later phases)

```dart
abstract interface class SupabaseClientWrapper {
  // ... above ...

  /// Auth state stream — wired up in Phase 5.
  Stream<AuthState> authStateChanges();

  /// Read a row set from a table — wired up in Phase 4 onward.
  Future<Result<List<Map<String, dynamic>>>> selectRows({
    required String table,
    Map<String, dynamic>? filters,
    int? limit,
  });

  /// RPC call — wired up in Phase 5 onward (auth Edge Functions).
  Future<Result<dynamic>> rpc(String fn, {Map<String, dynamic>? params});

  /// Storage upload via signed URL — wired up in Phase 11.
  Future<Result<String>> uploadObject({
    required String bucket,
    required String path,
    required List<int> bytes,
  });

  /// Realtime channel factory — wired up in Phase 22.
  RealtimeChannel realtimeChannel(String topic);
}
```

`AuthState`, `RealtimeChannel` are project-defined types in `lib/core/network/types/`, NOT re-exports of `supabase_flutter` types (otherwise they leak across the boundary).

## Implementation rules

- The single concrete implementation lives in `supabase_client_wrapper_impl.dart`.
- That file is the **only** file in the entire `lib/` tree allowed to `import 'package:supabase_flutter/...';`.
- A CI grep guard (`research.md` Decision 14, step 8) fails the pipeline if any other file imports the SDK.
- The implementation MUST translate `supabase_flutter`-thrown exceptions into `Result<T>` `FailureResult` returns. Domain code never sees a Supabase exception.

## Wire-up

- `injection.dart` registers `SupabaseClientWrapper` as a singleton bound to `SupabaseClientWrapperImpl`.
- `main.dart` resolves `SupabaseClientWrapper` from DI, calls `initialize(url, anonKey)` with values from `EnvConfig`, and logs a warning via `AppLogger.warning` if initialization returns a `FailureResult`.

## Phase 1 verification

- Compile-time: no file other than `supabase_client_wrapper_impl.dart` imports `package:supabase_flutter` (CI step 8).
- Runtime: with empty `SUPABASE_URL` / `SUPABASE_ANON_KEY` (CI dummy values), `initialize` returns `FailureResult(ConfigFailure)`, the wrapper's `isInitialized` stays `false`, and the shell still reaches an interactive state (FR-013).
