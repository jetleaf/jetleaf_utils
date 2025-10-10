// ---------------------------------------------------------------------------
// 🍃 JetLeaf Framework - https://jetleaf.hapnium.com
//
// Copyright © 2025 Hapnium & JetLeaf Contributors. All rights reserved.
//
// This source file is part of the JetLeaf Framework and is protected
// under copyright law. You may not copy, modify, or distribute this file
// except in compliance with the JetLeaf license.
//
// For licensing terms, see the LICENSE file in the root of this project.
// ---------------------------------------------------------------------------
// 
// 🔧 Powered by Hapnium — the Dart backend engine 🍃

import 'dart:typed_data';

import 'package:jetleaf_utils/src/parsers/dart_parser.dart';
import 'package:test/test.dart';

import '_helpers.dart';

void main() {
  group('DartParser', () {
    late DartParser parser;

    setUp(() {
      parser = DartParser();
    });

    group('parse', () {
      test('parses simple Dart map', () {
        const dart = '''
        final config = {
          'name': 'test',
          'value': 42,
          'enabled': true,
        };
        ''';
        final result = parser.parse(dart);
        
        expect(result['name'], equals('test'));
        expect(result['value'], equals(42));
        expect(result['enabled'], equals(true));
      });

      test('parses nested Dart map', () {
        const dart = '''
        const config = {
          'database': {
            'host': 'localhost',
            'port': 5432,
          },
          'features': ['auth', 'logging'],
        };
        ''';
        final result = parser.parse(dart);
        
        expect(result['database']['host'], equals('localhost'));
        expect(result['database']['port'], equals(5432));
        expect(result['features'], equals(['auth', 'logging']));
      });

      test('preserves special property values', () {
        const dart = '''
        var config = {
          'url': '#{base.url}/api',
          'token': '@{security.token}',
          'mixed': 'prefix-#{value}-@{other}-suffix',
        };
        ''';
        final result = parser.parse(dart);
        
        expect(result['url'], equals('#{base.url}/api'));
        expect(result['token'], equals('@{security.token}'));
        expect(result['mixed'], equals('prefix-#{value}-@{other}-suffix'));
      });

      test('handles different data types', () {
        const dart = '''
        {
          'string': 'hello',
          'integer': 123,
          'double': 45.67,
          'boolean': true,
          'null_value': null,
          'list': [1, 'two', true],
        }
        ''';
        final result = parser.parse(dart);
        
        expect(result['string'], equals('hello'));
        expect(result['integer'], equals(123));
        expect(result['double'], equals(45.67));
        expect(result['boolean'], equals(true));
        expect(result['null_value'], isNull);
        expect(result['list'], equals([1, 'two', true]));
      });

      test('handles unquoted keys', () {
        const dart = '''
        {
          name: 'test',
          value: 42,
        }
        ''';
        final result = parser.parse(dart);
        
        expect(result['name'], equals('test'));
        expect(result['value'], equals(42));
      });

      test('ignores comments', () {
        const dart = '''
        // This is a single line comment
        {
          'name': 'test', // End of line comment
          /* Multi-line
             comment */
          'value': 42,
        }
        ''';
        final result = parser.parse(dart);
        
        expect(result['name'], equals('test'));
        expect(result['value'], equals(42));
        expect(result.length, equals(2));
      });

      test('handles escaped strings', () {
        const dart = r'''
        {
          'newline': 'Line 1\nLine 2',
          'tab': 'Column1\tColumn2',
          'quote': 'He said "Hello"',
          'backslash': 'Path\\to\\file',
        }
        ''';
        final result = parser.parse(dart);
        
        expect(result['newline'], equals('Line 1\nLine 2'));
        expect(result['tab'], equals('Column1\tColumn2'));
        expect(result['quote'], equals('He said "Hello"'));
        expect(result['backslash'], equals('Path\\to\\file'));
      });

      test('parses direct map literal', () {
        const dart = '''
        {
          'direct': 'map',
          'no': 'assignment',
        }
        ''';
        final result = parser.parse(dart);
        
        expect(result['direct'], equals('map'));
        expect(result['no'], equals('assignment'));
      });
    });

    group('parseAsset', () {
      test('parses asset with content bytes', () {
        const dart = "{'name': 'from_asset', 'value': 123}";
        final asset = TestAsset(
          filePath: 'config.dart',
          fileName: 'config.dart',
          packageName: 'test',
          contentBytes: Uint8List.fromList(dart.codeUnits),
        );
        
        final result = parser.parseAsset(asset);
        expect(result['name'], equals('from_asset'));
        expect(result['value'], equals(123));
      });
    });
  });
}