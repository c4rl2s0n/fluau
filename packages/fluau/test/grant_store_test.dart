import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluau/fluau.dart';

void main() {
  group('MemoryPluginGrantStore', () {
    test('round-trips grants', () async {
      final store = MemoryPluginGrantStore();
      final grants = StoredPluginGrants(
        pluginId: 'demo',
        pluginVersion: '1.0.0',
        hostApis: const ['http', 'db'],
        libraries: const [],
        constraintFingerprints: const {'http': '{"domains":["a.com"]}'},
      );
      await store.write(grants);
      final read = await store.read('demo');
      expect(read, isNotNull);
      expect(read!.hostApis, ['http', 'db']);
      await store.clear('demo');
      expect(await store.read('demo'), isNull);
    });
  });

  group('JsonFilePluginGrantStore', () {
    test('persists to a temp file', () async {
      final file = File(
        '${Directory.systemTemp.path}/fluau_grant_test_${DateTime.now().microsecondsSinceEpoch}.json',
      );
      addTearDown(() async {
        if (await file.exists()) await file.delete();
      });

      final store = JsonFilePluginGrantStore(file.path);
      final grants = StoredPluginGrants(
        pluginId: 'p',
        pluginVersion: '0.1.0',
        hostApis: const ['log'],
        libraries: const [],
        constraintFingerprints: const {},
      );
      await store.write(grants);

      final again = JsonFilePluginGrantStore(file.path);
      final read = await again.read('p');
      expect(read?.pluginVersion, '0.1.0');
      expect(read?.hostApis, ['log']);
    });
  });

  group('StoredPluginGrants.covers', () {
    final manifest = PluginManifestDto(
      id: 'p',
      name: 'P',
      version: '1.0.0',
      permissions: PluginPermissionsDto(
        host: [
          HostApiPermissionDto(
            id: 'http',
            constraints: {
              'domains': ['a.com'],
            },
          ),
          const HostApiPermissionDto(id: 'db'),
        ],
      ),
    );

    test('true when required APIs granted', () {
      final stored = StoredPluginGrants.fromManifestSelection(
        manifest: manifest,
        selectedHostApis: {'http', 'db'},
      );
      expect(stored.covers(manifest), isTrue);
    });

    test('false when required missing', () {
      final stored = StoredPluginGrants(
        pluginId: 'p',
        pluginVersion: '1.0.0',
        hostApis: const ['http'],
        libraries: const [],
        constraintFingerprints: const {'http': '{"domains":["a.com"]}'},
      );
      expect(stored.covers(manifest), isFalse);
    });
  });
}
