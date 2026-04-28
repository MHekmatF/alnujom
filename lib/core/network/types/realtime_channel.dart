abstract interface class RealtimeChannel {
  String get topic;

  Future<void> subscribe();

  Future<void> unsubscribe();
}
