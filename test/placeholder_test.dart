import 'package:jetleaf_lang/lang.dart';
import 'package:jetleaf_logging/logging.dart';
import 'package:jetleaf_utils/src/exceptions.dart';
import 'package:jetleaf_utils/src/placeholder/placeholder_parser.dart';
import 'package:jetleaf_utils/src/placeholder/property_placeholder_helper.dart';
import 'package:test/test.dart';

void main() {
  group('PlaceholderParser', () {
    late PlaceholderParser parser;
    late Map<String, String> properties;

    setUp(() {
      parser = PlaceholderParser('#{', '}', ':', null, false);
      properties = {
        'name': 'Alice',
        'greeting': 'Hello',
        'app.title': 'MyApp',
        'user.name': 'Bob',
        'nested': '#{name}',
        'recursive': '#{greeting} #{name}',
        'env': 'production',
        'production.host': 'prod.example.com',
        'development.host': 'dev.example.com',
        'default.title': 'DefaultApp',
        'empty': '',
        'space': ' ',
        'special.chars': 'value with spaces & symbols!',
      };
    });

    group('Basic Placeholder Resolution', () {
      test('should resolve simple placeholder', () {
        final result = parser.replacePlaceholders('Hello #{name}!', (key) => properties[key]);
        expect(result, equals('Hello Alice!'));
      });

      test('should resolve multiple placeholders', () {
        final result = parser.replacePlaceholders('#{greeting} #{name}!', (key) => properties[key]);
        expect(result, equals('Hello Alice!'));
      });

      test('should handle text without placeholders', () {
        final result = parser.replacePlaceholders('Just plain text', (key) => properties[key]);
        expect(result, equals('Just plain text'));
      });

      test('should handle empty string', () {
        final result = parser.replacePlaceholders('', (key) => properties[key]);
        expect(result, equals(''));
      });

      test('should resolve placeholder with dots in key', () {
        final result = parser.replacePlaceholders('Welcome to #{app.title}', (key) => properties[key]);
        expect(result, equals('Welcome to MyApp'));
      });

      test('should handle placeholder at start of string', () {
        final result = parser.replacePlaceholders('#{greeting} world', (key) => properties[key]);
        expect(result, equals('Hello world'));
      });

      test('should handle placeholder at end of string', () {
        final result = parser.replacePlaceholders('Hello #{name}', (key) => properties[key]);
        expect(result, equals('Hello Alice'));
      });

      test('should handle only placeholder', () {
        final result = parser.replacePlaceholders('#{name}', (key) => properties[key]);
        expect(result, equals('Alice'));
      });
    });

    group('Fallback Values', () {
      test('should use fallback when placeholder not found', () {
        final result = parser.replacePlaceholders('Hello #{unknown:Guest}!', (key) => properties[key]);
        expect(result, equals('Hello Guest!'));
      });

      test('should prefer resolved value over fallback', () {
        final result = parser.replacePlaceholders('Hello #{name:Guest}!', (key) => properties[key]);
        expect(result, equals('Hello Alice!'));
      });

      test('should handle empty fallback', () {
        final result = parser.replacePlaceholders('Hello #{unknown:}!', (key) => properties[key]);
        expect(result, equals('Hello !'));
      });

      test('should handle fallback with spaces', () {
        final result = parser.replacePlaceholders('Hello #{unknown:Default User}!', (key) => properties[key]);
        expect(result, equals('Hello Default User!'));
      });

      test('should handle multiple colons in fallback', () {
        final result = parser.replacePlaceholders('URL: #{url:http://localhost:8080}', (key) => properties[key]);
        expect(result, equals('URL: http://localhost:8080'));
      });
    });

    group('Nested Placeholders', () {
      test('should resolve nested placeholder', () {
        final result = parser.replacePlaceholders('Value: #{nested}', (key) => properties[key]);
        expect(result, equals('Value: Alice'));
      });

      test('should resolve recursive placeholders', () {
        final result = parser.replacePlaceholders('Message: #{recursive}', (key) => properties[key]);
        expect(result, equals('Message: Hello Alice'));
      });

      test('should resolve dynamic key placeholder', () {
        final result = parser.replacePlaceholders('Host: #{#{env}.host}', (key) => properties[key]);
        expect(result, equals('Host: prod.example.com'));
      });

      test('should handle nested placeholder with fallback', () {
        final result = parser.replacePlaceholders('Title: #{#{app.type:default}.title}', (key) => properties[key]);
        expect(result, equals('Title: DefaultApp'));
      });
    });

    group('Error Handling', () {
      test('should throw exception for unresolvable placeholder when not ignoring', () {
        expect(
          () => parser.replacePlaceholders('Hello #{unknown}!', (key) => properties[key]),
          throwsA(isA<PlaceholderResolutionException>()),
        );
      });

      test('should detect circular references', () {
        final circularProps = {
          'a': '#{b}',
          'b': '#{c}',
          'c': '#{a}',
        };
        expect(
          () => parser.replacePlaceholders('#{a}', (key) => circularProps[key]),
          throwsA(isA<PlaceholderResolutionException>()),
        );
      });

      test('should detect self-referencing placeholder', () {
        final selfRef = {'self': '#{self}'};
        expect(
          () => parser.replacePlaceholders('#{self}', (key) => selfRef[key]),
          throwsA(isA<PlaceholderResolutionException>()),
        );
      });
    });

    group('Ignoring Unresolvable Placeholders', () {
      late PlaceholderParser ignoringParser;

      setUp(() {
        ignoringParser = PlaceholderParser('#{', '}', ':', null, true);
      });

      test('should leave unresolvable placeholder as-is when ignoring', () {
        final result = ignoringParser.replacePlaceholders('Hello #{unknown}!', (key) => properties[key]);
        expect(result, equals('Hello #{unknown}!'));
      });

      test('should resolve available placeholders and ignore others', () {
        final result = ignoringParser.replacePlaceholders('#{greeting} #{unknown} #{name}!', (key) => properties[key]);
        expect(result, equals('Hello #{unknown} Alice!'));
      });
    });

    group('Escaped Placeholders', () {
      late PlaceholderParser escapingParser;

      setUp(() {
        escapingParser = PlaceholderParser('#{', '}', ':', Character('\\'), false);
      });

      test('should handle escaped placeholder', () {
        final result = escapingParser.replacePlaceholders('Hello \\#{name}!', (key) => properties[key]);
        expect(result, equals('Hello #{name}!'));
      });

      test('should resolve unescaped and escape escaped placeholders', () {
        final result = escapingParser.replacePlaceholders('#{greeting} \\#{name}!', (key) => properties[key]);
        expect(result, equals('Hello #{name}!'));
      });

      test('should handle escaped separator in fallback', () {
        final result = escapingParser.replacePlaceholders('#{unknown\\:key:default}', (key) => properties[key]);
        expect(result, equals('default'));
      });
    });

    group('Custom Delimiters', () {
      test('should work with different prefix and suffix', () {
        final customParser = PlaceholderParser('[[', ']]', '|', null, false);
        final result = customParser.replacePlaceholders('Hello [[name|Guest]]!', (key) => properties[key]);
        expect(result, equals('Hello Alice!'));
      });

      test('should work with single character delimiters', () {
        final customParser = PlaceholderParser('{', '}', ':', null, false);
        final result = customParser.replacePlaceholders('Hello {name:Guest}!', (key) => properties[key]);
        expect(result, equals('Hello Alice!'));
      });
    });

    group('Edge Cases', () {
      test('should handle empty placeholder key', () {
        expect(
          () => parser.replacePlaceholders('Hello #{}!', (key) => properties[key]),
          throwsA(isA<PlaceholderResolutionException>()),
        );
      });

      test('should handle placeholder with only separator', () {
        final result = parser.replacePlaceholders('Hello #{:default}!', (key) => properties[key]);
        expect(result, equals('Hello default!'));
      });

      test('should handle malformed placeholder (no closing)', () {
        final result = parser.replacePlaceholders('Hello #{name', (key) => properties[key]);
        expect(result, equals('Hello #{name'));
      });

      test('should handle nested braces without placeholder prefix', () {
        final result = parser.replacePlaceholders('Hello {name}!', (key) => properties[key]);
        expect(result, equals('Hello {name}!'));
      });

      test('should resolve empty value', () {
        final result = parser.replacePlaceholders('Value: "#{empty}"', (key) => properties[key]);
        expect(result, equals('Value: ""'));
      });

      test('should resolve value with spaces', () {
        final result = parser.replacePlaceholders('Space: "#{space}"', (key) => properties[key]);
        expect(result, equals('Space: " "'));
      });

      test('should handle special characters in resolved value', () {
        final result = parser.replacePlaceholders('Value: #{special.chars}', (key) => properties[key]);
        expect(result, equals('Value: value with spaces & symbols!'));
      });
    });

    group('Complex Scenarios', () {
      test('should handle multiple nested levels', () {
        final complexProps = {
          'level1': '#{level2}',
          'level2': '#{level3}',
          'level3': 'final value',
        };
        final result = parser.replacePlaceholders('Result: #{level1}', (key) => complexProps[key]);
        expect(result, equals('Result: final value'));
      });

      test('should handle mixed content with multiple placeholders and text', () {
        final result = parser.replacePlaceholders(
          'Welcome #{name} to #{app.title}! Your greeting is: #{greeting}.',
          (key) => properties[key],
        );
        expect(result, equals('Welcome Alice to MyApp! Your greeting is: Hello.'));
      });

      test('should handle placeholder in fallback value', () {
        final result = parser.replacePlaceholders('#{unknown:#{greeting} Guest}', (key) => properties[key]);
        expect(result, equals('Hello Guest'));
      });
    });
  });

  group('PlaceholderPart Implementations', () {
    late PlaceholderPartResolutionContext context;
    late Map<String, String> properties;

    setUp(() {
      properties = {
        'name': 'Alice',
        'greeting': 'Hello',
        'nested': '#{name}',
      };
      
      final parser = PlaceholderParser('#{', '}', ':', null, false);
      context = PlaceholderPartResolutionContext(
        (key) => properties[key],
        '#{',
        '}',
        false,
        (text) => parser.parse(text).parts,
        LogFactory.getLog(PlaceholderPartResolutionContext),
      );
    });

    group('PlaceholderTextPart', () {
      test('should return original text', () {
        final part = PlaceholderTextPart('Hello World');
        expect(part.text(), equals('Hello World'));
        expect(part.resolve(context), equals('Hello World'));
      });

      test('should handle empty text', () {
        final part = PlaceholderTextPart('');
        expect(part.text(), equals(''));
        expect(part.resolve(context), equals(''));
      });

      test('should handle special characters', () {
        final part = PlaceholderTextPart('Special: !@#\$%^&*()');
        expect(part.text(), equals('Special: !@#\$%^&*()'));
        expect(part.resolve(context), equals('Special: !@#\$%^&*()'));
      });
    });

    group('SimplePlaceholderPart', () {
      test('should resolve with key', () {
        final part = SimplePlaceholderPart('#{name}', 'name', null);
        expect(part.text(), equals('#{name}'));
        expect(part.resolve(context), equals('Alice'));
      });

      test('should use fallback when key not found', () {
        final part = SimplePlaceholderPart('#{unknown}', 'unknown', 'Guest');
        expect(part.resolve(context), equals('Guest'));
      });

      test('should throw when no fallback and key not found', () {
        final part = SimplePlaceholderPart('#{unknown}', 'unknown', null);
        expect(() => part.resolve(context), throwsA(isA<PlaceholderResolutionException>()));
      });

      test('should handle recursive resolution', () {
        final part = SimplePlaceholderPart('#{nested}', 'nested', null);
        expect(part.resolve(context), equals('Alice'));
      });
    });

    group('NestedPlaceholderPart', () {
      test('should resolve dynamic key', () {
        final keyParts = [PlaceholderTextPart('name')];
        final part = NestedPlaceholderPart('#{name}', keyParts, null);
        expect(part.resolve(context), equals('Alice'));
      });

      test('should use default parts when key not found', () {
        final keyParts = [PlaceholderTextPart('unknown')];
        final defaultParts = [PlaceholderTextPart('Default Value')];
        final part = NestedPlaceholderPart('#{unknown}', keyParts, defaultParts);
        expect(part.resolve(context), equals('Default Value'));
      });

      test('should resolve complex nested structure', () {
        final keyParts = [PlaceholderTextPart('nested')];
        final part = NestedPlaceholderPart('#{nested}', keyParts, null);
        expect(part.resolve(context), equals('Alice'));
      });
    });
  });

  group('PlaceholderParsedValue', () {
    late PlaceholderPartResolutionContext context;

    setUp(() {
      final properties = {'name': 'Alice', 'greeting': 'Hello'};
      final parser = PlaceholderParser('#{', '}', ':', null, false);
      context = PlaceholderPartResolutionContext(
        (key) => properties[key],
        '#{',
        '}',
        false,
        (text) => parser.parse(text).parts,
        LogFactory.getLog(PlaceholderPartResolutionContext),
      );
    });

    test('should resolve all parts', () {
      final parts = [
        PlaceholderTextPart('Hello '),
        SimplePlaceholderPart('#{name}', 'name', null),
        PlaceholderTextPart('!'),
      ];
      final parsedValue = PlaceholderParsedValue('Hello #{name}!', parts);
      expect(parsedValue.resolve(context), equals('Hello Alice!'));
    });

    test('should handle empty parts list', () {
      final parsedValue = PlaceholderParsedValue('', []);
      expect(parsedValue.resolve(context), equals(''));
    });

    test('should rethrow resolution exceptions with context', () {
      final parts = [SimplePlaceholderPart('#{unknown}', 'unknown', null)];
      final parsedValue = PlaceholderParsedValue('#{unknown}', parts);
      expect(() => parsedValue.resolve(context), throwsA(isA<PlaceholderResolutionException>()));
    });
  });

  group('PlaceholderPartResolutionContext', () {
    late PlaceholderPartResolutionContext context;
    late Map<String, String> properties;

    setUp(() {
      properties = {'name': 'Alice', 'greeting': 'Hello'};
      final parser = PlaceholderParser('#{', '}', ':', null, false);
      context = PlaceholderPartResolutionContext(
        (key) => properties[key],
        '#{',
        '}',
        false,
        (text) => parser.parse(text).parts,
        LogFactory.getLog(PlaceholderPartResolutionContext),
      );
    });

    test('should resolve placeholder', () {
      expect(context.resolvePlaceholder('name'), equals('Alice'));
      expect(context.resolvePlaceholder('unknown'), isNull);
    });

    test('should handle unresolvable placeholder when not ignoring', () {
      expect(
        () => context.handleUnresolvablePlaceholder('unknown', '#{unknown}'),
        throwsA(isA<PlaceholderResolutionException>()),
      );
    });

    test('should return placeholder text when ignoring unresolvable', () {
      final ignoringContext = PlaceholderPartResolutionContext(
        (key) => properties[key],
        '#{',
        '}',
        true,
        (text) => [],
        LogFactory.getLog(PlaceholderPartResolutionContext),
      );
      expect(ignoringContext.handleUnresolvablePlaceholder('unknown', '#{unknown}'), equals('#{unknown}'));
    });

    test('should convert to placeholder text', () {
      expect(context.toPlaceholderText('name'), equals('#{name}'));
    });

    test('should track visited placeholders', () {
      context.flagPlaceholderAsVisited('name');
      expect(() => context.flagPlaceholderAsVisited('name'), throwsA(isA<PlaceholderResolutionException>()));
    });

    test('should remove visited placeholders', () {
      context.flagPlaceholderAsVisited('name');
      context.removePlaceholder('name');
      // Should not throw when flagging again after removal
      context.flagPlaceholderAsVisited('name');
    });
  });

  group('PropertyPlaceholderHelper', () {
    late PropertyPlaceholderHelper helper;
    late Map<String, String> properties;

    setUp(() {
      helper = PropertyPlaceholderHelper('#{', '}');
      properties = {
        'name': 'Alice',
        'greeting': 'Hello',
        'app.title': 'MyApp',
        'nested': '#{name}',
      };
    });

    test('should replace placeholders with map', () {
      final result = helper.replacePlaceholders('Hello #{name}!', properties);
      expect(result, equals('Hello Alice!'));
    });

    test('should replace placeholders with resolver function', () {
      final result = helper.replacePlaceholdersWithResolver('Hello #{name}!', (key) => properties[key]);
      expect(result, equals('Hello Alice!'));
    });

    test('should handle multiple placeholders', () {
      final result = helper.replacePlaceholders('#{greeting} #{name}!', properties);
      expect(result, equals('Hello Alice!'));
    });

    test('should ignore unresolvable placeholders by default', () {
      final result = helper.replacePlaceholders('Hello #{unknown}!', properties);
      expect(result, equals('Hello #{unknown}!'));
    });

    group('with custom configuration', () {
      late PropertyPlaceholderHelper customHelper;

      setUp(() {
        customHelper = PropertyPlaceholderHelper.more('#{', '}', ':', Character('\\'), false);
      });

      test('should use fallback values', () {
        final result = customHelper.replacePlaceholders('Hello #{unknown:Guest}!', properties);
        expect(result, equals('Hello Guest!'));
      });

      test('should handle escaped placeholders', () {
        final result = customHelper.replacePlaceholders('Hello \\#{name}!', properties);
        expect(result, equals('Hello #{name}!'));
      });

      test('should throw on unresolvable when not ignoring', () {
        expect(
          () => customHelper.replacePlaceholders('Hello #{unknown}!', properties),
          throwsA(isA<PlaceholderResolutionException>()),
        );
      });
    });
  });

  group('PlaceholderParsedSection', () {
    test('should store key and fallback', () {
      final section = PlaceholderParsedSection('key', 'fallback');
      expect(section.key, equals('key'));
      expect(section.fallback, equals('fallback'));
    });

    test('should handle null fallback', () {
      final section = PlaceholderParsedSection('key', null);
      expect(section.key, equals('key'));
      expect(section.fallback, isNull);
    });
  });

  group('Integration Tests', () {
    test('should handle real-world configuration scenario', () {
      final parser = PlaceholderParser('#{', '}', ':', Character('\\'), false);
      final config = {
        'app.name': 'MyApplication',
        'app.version': '1.0.0',
        'env': 'production',
        'production.db.host': 'prod-db.example.com',
        'production.db.port': '5432',
        'development.db.host': 'localhost',
        'development.db.port': '5433',
        'db.name': 'myapp_db',
        'db.user': 'admin',
      };

      final template = 'Connecting to #{#{env}.db.host}:#{#{env}.db.port}/#{db.name} as #{db.user} for #{app.name} v#{app.version}';
      final result = parser.replacePlaceholders(template, (key) => config[key]);
      
      expect(result, equals('Connecting to prod-db.example.com:5432/myapp_db as admin for MyApplication v1.0.0'));
    });

    test('should handle template with fallbacks and escaping', () {
      final parser = PlaceholderParser('#{', '}', ':', Character('\\'), false);
      final config = {
        'user.name': 'Alice',
        'app.title': 'MyApp',
      };

      final template = 'Welcome #{user.name:Guest} to \\#{app.title} (#{app.title})! Debug: \\#{debug:off}';
      final result = parser.replacePlaceholders(template, (key) => config[key]);
      
      expect(result, equals('Welcome Alice to #{app.title} (MyApp)! Debug: #{debug:off}'));
    });

    test('should handle complex nested scenario with multiple levels', () {
      final parser = PlaceholderParser('#{', '}', ':', null, false);
      final config = {
        'env': 'prod',
        'region': 'us-east-1',
        'prod.us-east-1.endpoint': 'https://api-prod-east.example.com',
        'prod.us-west-2.endpoint': 'https://api-prod-west.example.com',
        'dev.us-east-1.endpoint': 'https://api-dev-east.example.com',
        'service.name': 'user-service',
        'version': '2.1.0',
      };

      final template = 'Deploying #{service.name} v#{version} to #{#{env}.#{region}.endpoint}';
      final result = parser.replacePlaceholders(template, (key) => config[key]);
      
      expect(result, equals('Deploying user-service v2.1.0 to https://api-prod-east.example.com'));
    });
  });
}