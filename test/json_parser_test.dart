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

import 'package:jetleaf_utils/src/exceptions.dart';
import 'package:jetleaf_utils/src/parsers/json_parser.dart';
import 'package:test/test.dart';

import '_helpers.dart';

void main() {
  group('JsonParser', () {
    late JsonParser parser;

    setUp(() {
      parser = JsonParser();
    });

    group('parse', () {
      test('parses simple JSON object', () {
        const json = '{"name": "test", "value": 42}';
        final result = parser.parse(json);
        
        expect(result, equals({'name': 'test', 'value': 42}));
      });

      test('parses nested JSON object', () {
        const json = '''
        {
          "database": {
            "host": "localhost",
            "port": 5432
          },
          "features": ["auth", "logging"]
        }
        ''';
        final result = parser.parse(json);
        
        expect(result['database']['host'], equals('localhost'));
        expect(result['database']['port'], equals(5432));
        expect(result['features'], equals(['auth', 'logging']));
      });

      test('preserves special property values', () {
        const json = '''
        {
          "url": "#{base.url}/api",
          "token": "@{security.token}",
          "mixed": "prefix-#{value}-@{other}-suffix"
        }
        ''';
        final result = parser.parse(json);
        
        expect(result['url'], equals('#{base.url}/api'));
        expect(result['token'], equals('@{security.token}'));
        expect(result['mixed'], equals('prefix-#{value}-@{other}-suffix'));
      });

      test('handles various data types', () {
        const json = '''
        {
          "string": "hello",
          "number": 123,
          "float": 45.67,
          "boolean": true,
          "null_value": null,
          "array": [1, "two", true]
        }
        ''';
        final result = parser.parse(json);
        
        expect(result['string'], equals('hello'));
        expect(result['number'], equals(123));
        expect(result['float'], equals(45.67));
        expect(result['boolean'], equals(true));
        expect(result['null_value'], isNull);
        expect(result['array'], equals([1, 'two', true]));
      });

      test('throws ParserException for invalid JSON', () {
        expect(() => parser.parse('{"invalid": json}'), 
               throwsA(isA<ParserException>()));
      });

      test('throws ParserException for non-object root', () {
        expect(() => parser.parse('["array", "root"]'), 
               throwsA(isA<ParserException>()));
      });
    });

    group('parseAsset', () {
      test('parses asset with content bytes', () {
        const json = '{"from": "asset", "value": 123}';
        final asset = TestAsset(
          filePath: 'config.json',
          fileName: 'config.json',
          packageName: 'test',
          contentBytes: Uint8List.fromList(json.codeUnits),
        );
        
        final result = parser.parseAsset(asset);
        expect(result, equals({'from': 'asset', 'value': 123}));
      });

      test('preserves special syntax in asset', () {
        const json = '{"ref": "#{config.value}", "env": "@{ENV_VAR}"}';
        final asset = TestAsset(
          filePath: 'config.json',
          fileName: 'config.json',
          packageName: 'test',
          contentBytes: Uint8List.fromList(json.codeUnits),
        );
        
        final result = parser.parseAsset(asset);
        expect(result['ref'], equals('#{config.value}'));
        expect(result['env'], equals('@{ENV_VAR}'));
      });
    });

    group('parseAs', () {
      test('returns same result as parseAsset', () {
        const json = '{"test": "value"}';
        final asset = TestAsset(
          filePath: 'test.json',
          fileName: 'test.json',
          packageName: 'test',
          contentBytes: Uint8List.fromList(json.codeUnits),
        );
        
        final assetResult = parser.parseAsset(asset);
        final asResult = parser.parseAs(asset);
        
        expect(asResult, equals(assetResult));
      });
    });

    group('parseFile', () {
      test('throws ParserException for non-existent file', () {
        expect(() => parser.parseFile('non_existent.json'),
               throwsA(isA<ParserException>()));
      });
    });
  });
}