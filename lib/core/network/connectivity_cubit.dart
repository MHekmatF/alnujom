// Plan A30 — is the phone on a network at all?
//
// `true` = some interface (wifi, mobile, ethernet, vpn) is up; `false` = none.
// This is reachability of a *link*, not of Supabase: a captive portal or a
// dead SIM still reads as online, and the request deadline in
// `TimeoutHttpClient` is what catches those. Starts optimistic so a fresh app
// never flashes the offline strip before the first reading arrives.
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class ConnectivityCubit extends Cubit<bool> {
  ConnectivityCubit() : super(true) {
    final connectivity = Connectivity();
    _sub = connectivity.onConnectivityChanged.listen(_onChanged);
    unawaited(
      connectivity.checkConnectivity().then(_onChanged).catchError((Object _) {
        // No plugin answer (e.g. a test host): stay optimistic.
      }),
    );
  }

  StreamSubscription<List<ConnectivityResult>>? _sub;

  void _onChanged(List<ConnectivityResult> results) {
    if (isClosed) return;
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online != state) emit(online);
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
