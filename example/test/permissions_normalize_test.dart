import 'package:flutter_test/flutter_test.dart';
import 'package:fluau/fluau.dart';

void main() {
  group('normalizeHostList', () {
    test('legacy string list + httpAllowlist', () {
      final host = PluginRegistryLoader.normalizeHostList(
        ['http.request', 'db', 'log'],
        ['fake.proton'],
      );
      expect(host.map((h) => h.id).toList(), ['http', 'db', 'log']);
      final http = host.firstWhere((h) => h.id == 'http');
      expect(http.isRequired, isTrue);
      expect(http.constraints['domains'], ['fake.proton']);
    });

    test('list with optional and domains', () {
      final host = PluginRegistryLoader.normalizeHostList([
        {
          'http': {
            'domains': ['a.com'],
          },
        },
        'db',
        {
          'log': {'optional': true},
        },
      ], const []);
      expect(host.length, 3);
      expect(host.firstWhere((h) => h.id == 'log').isRequired, isFalse);
      expect(host.firstWhere((h) => h.id == 'db').isRequired, isTrue);
      final http = host.firstWhere((h) => h.id == 'http');
      expect(http.constraints['domains'], ['a.com']);
    });

    test('duplicate ids keep first', () {
      final host = PluginRegistryLoader.normalizeHostList([
        'db',
        'db',
      ], const []);
      expect(host.length, 1);
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
          const HostApiPermissionDto(id: 'log', isRequired: false),
        ],
      ),
    );

    test('covers when required granted and fingerprints match', () {
      final stored = StoredPluginGrants.fromManifestSelection(
        manifest: manifest,
        selectedHostApis: {'http', 'db'},
      );
      expect(stored.covers(manifest), isTrue);
    });

    test('fails when required missing', () {
      final stored = StoredPluginGrants(
        pluginId: 'p',
        pluginVersion: '1.0.0',
        hostApis: ['http'],
        libraries: const [],
        constraintFingerprints: {'http': '{"domains":["a.com"]}'},
      );
      expect(stored.covers(manifest), isFalse);
    });

    test('fails when fingerprint drifts', () {
      final stored = StoredPluginGrants(
        pluginId: 'p',
        pluginVersion: '1.0.0',
        hostApis: ['http', 'db'],
        libraries: const [],
        constraintFingerprints: {
          'http': '{"domains":["evil.com"]}',
          'db': '{}',
        },
      );
      expect(stored.covers(manifest), isFalse);
    });
  });
}
