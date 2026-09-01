// Verifies that every dependency the generated injector RESOLVES is also
// REGISTERED somewhere.
//
// Why this exists: injectable does not check this. If a class asks for a
// collaborator that was never annotated `@injectable`, the generator happily
// emits `gh<ThatType>()` and the build stays green — the failure only appears at
// runtime, when get_it throws while the screen is being built. In a release
// build that surfaces as a blank screen and nothing else, because the crash
// reporter is inert without a DSN. That is exactly how an unregistered
// RequestPasswordReset shipped and blanked the password-reset screen.
//
// Exit codes: 0 clean · 1 violations found · 2 script failure.
import 'dart:io';

const _configPath = 'lib/core/di/injection.config.dart';
const _mainPath = 'lib/main.dart';

void main() {
  final config = File(_configPath);
  if (!config.existsSync()) {
    stderr.writeln('lint_di_graph: $_configPath not found — run build_runner.');
    exit(2);
  }
  final src = config.readAsStringSync();

  // gh.factory<_i12.Foo>(...) / gh.singleton<...> / gh.factoryParam<_i12.Foo, X, Y>
  final registered = RegExp(
    r'gh\.[A-Za-z]+<\s*_i\d+\.([A-Za-z0-9_]+)\s*[,>]',
  ).allMatches(src).map((m) => m.group(1)!).toSet();

  // gh<_i12.Foo>() — a dependency being resolved.
  final resolved = RegExp(
    r'\bgh<\s*_i\d+\.([A-Za-z0-9_]+)\s*>',
  ).allMatches(src).map((m) => m.group(1)!).toSet();

  // Anything registered by hand before configureDependencies() runs.
  final manual = <String>{};
  final main = File(_mainPath);
  if (main.existsSync()) {
    manual.addAll(
      RegExp(
        r'getIt\.register[A-Za-z]+<\s*([A-Za-z0-9_]+)\s*>',
      ).allMatches(main.readAsStringSync()).map((m) => m.group(1)!),
    );
  }

  final missing = (resolved.difference(registered).difference(manual)).toList()
    ..sort();

  if (missing.isEmpty) {
    stdout.writeln(
      'DI graph check passed '
      '(${registered.length} registered, ${resolved.length} resolved).',
    );
    exit(0);
  }

  stderr.writeln('DI graph check FAILED — resolved but never registered:');
  for (final type in missing) {
    stderr.writeln(
      '  $type — add @injectable to its class, or register it in $_mainPath.',
    );
  }
  stderr.writeln(
    '\nThese throw at runtime the moment something asks for them, and in a '
    'release build the screen just goes blank.',
  );
  exit(1);
}
