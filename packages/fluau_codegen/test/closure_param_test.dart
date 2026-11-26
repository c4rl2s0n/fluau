import 'package:fluau_codegen/parsers/annotation_parser.dart';
import 'package:test/test.dart';

void main() {
  group('AnnotationParser.validateCallbackParam', () {
    test('rejects VoidCallback display type', () {
      expect(
        () => AnnotationParser.validateCallbackParam(
          className: 'LuaButtonWidget',
          paramName: 'onPressed',
          dartType: 'VoidCallback?',
          isFunctionType: false,
          isTypedefToFunction: true,
          isEventPayloadMap: false,
        ),
        throwsA(
          isA<LuaWidgetCodegenException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('onPressed'),
              contains('LuaButtonWidget'),
              contains('cannot be a Dart function/closure'),
              contains('Map<String, dynamic>?'),
              contains('PluginEventScope.dispatch'),
            ),
          ),
        ),
      );
    });

    test('rejects void Function() type', () {
      expect(
        () => AnnotationParser.validateCallbackParam(
          className: 'LuaButtonWidget',
          paramName: 'onPressed',
          dartType: 'void Function()?',
          isFunctionType: true,
          isTypedefToFunction: false,
          isEventPayloadMap: false,
        ),
        throwsA(isA<LuaWidgetCodegenException>()),
      );
    });

    test('rejects @LuaCallback on non-map type', () {
      expect(
        () => AnnotationParser.validateCallbackParam(
          className: 'LuaButtonWidget',
          paramName: 'onPressed',
          dartType: 'String?',
          isFunctionType: false,
          isTypedefToFunction: false,
          annotationKind: 'LuaCallback',
          isEventPayloadMap: false,
        ),
        throwsA(
          isA<LuaWidgetCodegenException>().having(
            (e) => e.message,
            'message',
            contains('LuaEventPayload'),
          ),
        ),
      );
    });

    test('allows Map event payload', () {
      expect(
        () => AnnotationParser.validateCallbackParam(
          className: 'LuaButtonWidget',
          paramName: 'onPressed',
          dartType: 'Map<String, dynamic>?',
          isFunctionType: false,
          isTypedefToFunction: false,
          isEventPayloadMap: true,
        ),
        returnsNormally,
      );
    });

    test('allows @LuaCallback on map type', () {
      expect(
        () => AnnotationParser.validateCallbackParam(
          className: 'LuaButtonWidget',
          paramName: 'onPressed',
          dartType: 'Map<String, dynamic>?',
          isFunctionType: false,
          isTypedefToFunction: false,
          annotationKind: 'LuaCallback',
          isEventPayloadMap: true,
        ),
        returnsNormally,
      );
    });
  });

  group('AnnotationParser.isUnsupportedClosureType', () {
    test('detects ValueChanged and Function display forms', () {
      expect(
        AnnotationParser.isUnsupportedClosureType(
          dartType: 'ValueChanged<String>',
          isFunctionType: false,
          isTypedefToFunction: false,
        ),
        isTrue,
      );
      expect(
        AnnotationParser.isUnsupportedClosureType(
          dartType: 'void Function(int)',
          isFunctionType: false,
          isTypedefToFunction: false,
        ),
        isTrue,
      );
      expect(
        AnnotationParser.isUnsupportedClosureType(
          dartType: 'Map<String, dynamic>?',
          isFunctionType: false,
          isTypedefToFunction: false,
        ),
        isFalse,
      );
    });
  });

  group('AnnotationParser.isEventPayloadMapDisplay', () {
    test('accepts Map and LuaEventPayload display names', () {
      expect(
        AnnotationParser.isEventPayloadMapDisplay('Map<String, dynamic>?'),
        isTrue,
      );
      expect(
        AnnotationParser.isEventPayloadMapDisplay('Map<String, Object>'),
        isTrue,
      );
      expect(
        AnnotationParser.isEventPayloadMapDisplay('LuaEventPayload?'),
        isTrue,
      );
      expect(
        AnnotationParser.isEventPayloadMapDisplay('LuaEventPayload'),
        isTrue,
      );
      expect(
        AnnotationParser.isEventPayloadMapDisplay('String?'),
        isFalse,
      );
    });

    test('allows LuaEventPayload via validation when flagged as payload', () {
      expect(
        () => AnnotationParser.validateCallbackParam(
          className: 'LuaButtonWidget',
          paramName: 'onPressed',
          dartType: 'LuaEventPayload?',
          isFunctionType: false,
          isTypedefToFunction: false,
          isEventPayloadMap: true,
        ),
        returnsNormally,
      );
    });
  });
}
