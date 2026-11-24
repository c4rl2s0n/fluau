#!/usr/bin/env dart
// Forward to packages/lua_plugin bootstrap.
import 'dart:io';

Future<void> main(List<String> args) async {
  final root = Directory.current.path;
  // Prefer running from example/ (config lives there) or repo root.
  final candidates = [
    '$root/packages/lua_plugin/bin/bootstrap.dart',
    '$root/../packages/lua_plugin/bin/bootstrap.dart',
  ];
  final script = candidates.map(File.new).firstWhere(
        (f) => f.existsSync(),
        orElse: () => File(candidates.first),
      );
  if (!script.existsSync()) {
    stderr.writeln('bootstrap.dart not found');
    exit(1);
  }
  final result = await Process.run(
    Platform.resolvedExecutable,
    [script.absolute.path, ...args],
    workingDirectory: root,
  );
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  exit(result.exitCode);
}
