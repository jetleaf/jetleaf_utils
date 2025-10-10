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
import 'package:jetleaf_utils/src/parsers/yaml_parser.dart';
import 'package:test/test.dart';

import '_helpers.dart';

void main() {
  group('YamlParser', () {
    late YamlParser parser;

    setUp(() {
      parser = YamlParser();
    });

    group('parse', () {
      test('parses simple YAML', () {
        const yaml = '''
        name: test
        value: 42
        enabled: true
        ''';
        final result = parser.parse(yaml);
        
        expect(result['name'], equals('test'));
        expect(result['value'], equals(42));
        expect(result['enabled'], equals(true));
      });

      test('parses nested YAML', () {
        const yaml = '''
        database:
          host: localhost
          port: 5432
          credentials:
            username: admin
            password: secret
        ''';
        final result = parser.parse(yaml);
        
        expect(result['database']['host'], equals('localhost'));
        expect(result['database']['port'], equals(5432));
        expect(result['database']['credentials']['username'], equals('admin'));
        expect(result['database']['credentials']['password'], equals('secret'));
      });

      test('preserves special property values', () {
        const yaml = '''
        url: "#{base.url}/api"
        token: "@{security.token}"
        mixed: "prefix-#{value}-@{other}-suffix"
        ''';
        final result = parser.parse(yaml);
        
        expect(result['url'], equals('#{base.url}/api'));
        expect(result['token'], equals('@{security.token}'));
        expect(result['mixed'], equals('prefix-#{value}-@{other}-suffix'));
      });

      test('handles different data types', () {
        const yaml = '''
        string: hello
        integer: 123
        float: 45.67
        boolean_true: true
        boolean_false: false
        null_value: null
        null_tilde: ~
        ''';
        final result = parser.parse(yaml);
        
        expect(result['string'], equals('hello'));
        expect(result['integer'], equals(123));
        expect(result['float'], equals(45.67));
        expect(result['boolean_true'], equals(true));
        expect(result['boolean_false'], equals(false));
        expect(result['null_value'], isNull);
        expect(result['null_tilde'], isNull);
      });

      test('handles inline arrays', () {
        const yaml = '''
        simple_array: [1, 2, 3]
        mixed_array: ["hello", 42, true]
        empty_array: []
        ''';
        final result = parser.parse(yaml);
        
        expect(result['simple_array'], equals([1, 2, 3]));
        expect(result['mixed_array'], equals(['hello', 42, true]));
        expect(result['empty_array'], equals([]));
      });

      test('handles inline objects', () {
        const yaml = '''
        inline_object: {name: "test", value: 42}
        empty_object: {}
        ''';
        final result = parser.parse(yaml);
        
        expect(result['inline_object']['name'], equals('test'));
        expect(result['inline_object']['value'], equals(42));
        expect(result['empty_object'], equals({}));
      });

      test('ignores comments', () {
        const yaml = '''
        # This is a comment
        name: test  # End of line comment
        # Another comment
        value: 42
        ''';
        final result = parser.parse(yaml);
        
        expect(result['name'], equals('test'));
        expect(result['value'], equals(42));
        expect(result.length, equals(2));
      });

      test('handles quoted strings', () {
        const yaml = '''
        single_quoted: 'Hello World'
        double_quoted: "Hello World"
        with_spaces: "  spaced  "
        ''';
        final result = parser.parse(yaml);
        
        expect(result['single_quoted'], equals('Hello World'));
        expect(result['double_quoted'], equals('Hello World'));
        expect(result['with_spaces'], equals('  spaced  '));
      });
    });

    group('parseAsset', () {
      test('parses asset with content bytes', () {
        const yaml = 'name: from_asset\nvalue: 123';
        final asset = TestAsset(
          filePath: 'config.yaml',
          fileName: 'config.yaml',
          packageName: 'test',
          contentBytes: Uint8List.fromList(yaml.codeUnits),
        );
        
        final result = parser.parseAsset(asset);
        expect(result['name'], equals('from_asset'));
        expect(result['value'], equals(123));
      });
    });
  });
}