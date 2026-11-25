import 'package:flutter_test/flutter_test.dart';
import 'package:fluau/fluau.dart';

void main() {
  group('CapabilityJson', () {
    test('asMap accepts Map and Map<String, dynamic>', () {
      expect(
        CapabilityJson.asMap({'a': 1}, context: 't')['a'],
        1,
      );
      expect(
        CapabilityJson.asMap(<dynamic, dynamic>{'a': 1}, context: 't')['a'],
        1,
      );
    });

    test('asMap rejects non-maps', () {
      expect(
        () => CapabilityJson.asMap('nope', context: 't'),
        throwsA(isA<CapabilityDecodeException>()),
      );
    });

    test('requireField and optionalField', () {
      final json = {'name': 'x', 'n': null};
      expect(
        CapabilityJson.requireField<String>(json, 'name', context: 't'),
        'x',
      );
      expect(CapabilityJson.optionalField<String>(json, 'missing'), isNull);
      expect(
        () => CapabilityJson.requireField<String>(json, 'n', context: 't'),
        throwsA(isA<CapabilityDecodeException>()),
      );
    });

    test('requireInt coerces num', () {
      expect(
        CapabilityJson.requireInt({'n': 3.0}, 'n', context: 't'),
        3,
      );
    });
  });
}
