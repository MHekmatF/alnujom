abstract interface class AppLogger {
  void debug(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  });

  void info(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  });

  void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  });

  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  });
}
