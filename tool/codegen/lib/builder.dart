/// build_runner entrypoints for lua_plugin_codegen.
library;

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/capability_generator.dart';

/// SharedPartBuilder → `*.g.dart` via `source_gen|combining_builder`.
Builder luaCapabilityBuilder(BuilderOptions options) => SharedPartBuilder(
      [CapabilityGenerator()],
      'lua_capability',
    );
