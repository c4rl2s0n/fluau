import 'package:flutter_test/flutter_test.dart';
import 'package:fluau/fluau.dart';

void main() {
  group('PluginRegistryLoader.normalizeHostList', () {
    test('legacy string list + httpAllowlist', () {
      final host = PluginRegistryLoader.normalizeHostList(
        ['http.request', 'db', 'log'],
        ['api.example.com'],
      );
      expect(host.map((h) => h.id).toList(), ['http', 'db', 'log']);
      final http = host.firstWhere((h) => h.id == 'http');
      expect(http.isRequired, isTrue);
      expect(http.constraints['domains'], ['api.example.com']);
    });

    test('optional map entries', () {
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
      expect(host.firstWhere((h) => h.id == 'log').isRequired, isFalse);
      expect(host.firstWhere((h) => h.id == 'db').isRequired, isTrue);
    });
  });
}
