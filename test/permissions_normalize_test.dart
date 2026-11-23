import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:luatest/lua/grant_store.dart';
import 'package:luatest/lua/plugin_registry.dart';
import 'package:luatest/src/rust/api/plugin.dart';

void main() {
  group('normalizeHostList', () {
    test('legacy string list + httpAllowlist', () {
      final host = PluginRegistryLoader.normalizeHostList(
        ['http.request', 'db', 'log'],
        ['fake.proton'],
      );
      expect(host.map((h) => h.id).toList(), ['http', 'db', 'log']);
      final http = host.firstWhere((h) => h.id == 'http');
      expect(http.required_, isTrue);
      final domains = jsonDecode(http.constraintsJson)['domains'] as List;
      expect(domains, ['fake.proton']);
    });

    test('list with optional and domains', () {
      final host = PluginRegistryLoader.normalizeHostList(
        [
          {
            'http': {
              'domains': ['a.com'],
            },
          },
          'db',
          {
            'log': {'optional': true},
          },
        ],
        const [],
      );
      expect(host.length, 3);
      expect(host.firstWhere((h) => h.id == 'log').required_, isFalse);
      expect(host.firstWhere((h) => h.id == 'db').required_, isTrue);
      final http = host.firstWhere((h) => h.id == 'http');
      expect(jsonDecode(http.constraintsJson)['domains'], ['a.com']);
    });

    test('duplicates keep first', () {
      final host = PluginRegistryLoader.normalizeHostList(
        ['db', 'db'],
        const [],
      );
      expect(host.length, 1);
    });
  });

  group('StoredPluginGrants.covers', () {
    PluginManifest manifest({
      required List<HostApiPermission> host,
      String version = '0.1.0',
    }) {
      return PluginManifest(
        id: 'p',
        name: 'P',
        version: version,
        script: 'main.lua',
        main: 'main.lua',
        capabilities: const [],
        permissions: PluginPermissions(host: host, libraries: const []),
      );
    }

    test('requires required APIs and matching fingerprints', () {
      final m = manifest(
        host: [
          const HostApiPermission(
            id: 'db',
            required_: true,
            constraintsJson: '{}',
          ),
          const HostApiPermission(
            id: 'log',
            required_: false,
            constraintsJson: '{}',
          ),
        ],
      );
      final stored = StoredPluginGrants.fromManifestSelection(
        manifest: m,
        selectedHostApis: {'db'},
      );
      expect(stored.covers(m), isTrue);

      final missingRequired = StoredPluginGrants(
        pluginId: 'p',
        pluginVersion: '0.1.0',
        hostApis: const ['log'],
        libraries: const [],
        constraintFingerprints: const {'log': '{}'},
      );
      expect(missingRequired.covers(m), isFalse);
    });

    test('version bump invalidates', () {
      final m = manifest(
        host: const [
          HostApiPermission(
            id: 'db',
            required_: true,
            constraintsJson: '{}',
          ),
        ],
        version: '0.2.0',
      );
      final stored = StoredPluginGrants(
        pluginId: 'p',
        pluginVersion: '0.1.0',
        hostApis: const ['db'],
        libraries: const [],
        constraintFingerprints: const {'db': '{}'},
      );
      expect(stored.covers(m), isFalse);
    });
  });

  group('MemoryPluginGrantStore', () {
    test('round trip', () async {
      final store = MemoryPluginGrantStore();
      final grants = StoredPluginGrants(
        pluginId: 'x',
        pluginVersion: '1',
        hostApis: const ['db'],
        libraries: const [],
        constraintFingerprints: const {'db': '{}'},
      );
      await store.write(grants);
      final read = await store.read('x');
      expect(read?.hostApis, ['db']);
      await store.clear('x');
      expect(await store.read('x'), isNull);
    });
  });
}
