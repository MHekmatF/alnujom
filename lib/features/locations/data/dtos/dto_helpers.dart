Map<String, String> parseLocalizedMap(Object? raw) {
  if (raw is! Map) return const <String, String>{};
  return raw.map(
    (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
  );
}

int parseNestedCount(Object? raw) {
  final rows = raw is List ? raw : const [];
  if (rows.isEmpty || rows.first is! Map) return 0;
  final count = (rows.first as Map)['count'];
  return count is int ? count : int.tryParse(count.toString()) ?? 0;
}
