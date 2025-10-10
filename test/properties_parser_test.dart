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

import 'package:jetleaf_utils/src/parsers/properties_parser.dart';
import 'package:test/test.dart';

import '_helpers.dart';

void main() {
  group('PropertiesParser', () {
    late PropertiesParser parser;

    setUp(() {
      parser = PropertiesParser();
    });

    group('parse', () {
      test('parses simple properties', () {
        const props = '''
        name=test
        value=42
        enabled=true
        ''';
        final result = parser.parse(props);
        
        expect(result['name'], equals('test'));
        expect(result['value'], equals('42'));
        expect(result['enabled'], equals('true'));
      });

      test('handles nested properties with dot notation', () {
        const props = '''
        database.host=localhost
        database.port=5432
        database.name=mydb
        ''';
        final result = parser.parse(props);
        
        expect(result['database']['host'], equals('localhost'));
        expect(result['database']['port'], equals('5432'));
        expect(result['database']['name'], equals('mydb'));
      });

      test('preserves special property values', () {
        const props = '''
        url=#{base.url}/api
        token=@{security.token}
        mixed=prefix-#{value}-@{other}-suffix
        ''';
        final result = parser.parse(props);
        
        expect(result['url'], equals('#{base.url}/api'));
        expect(result['token'], equals('@{security.token}'));
        expect(result['mixed'], equals('prefix-#{value}-@{other}-suffix'));
      });

      test('ignores comments', () {
        const props = '''
        # This is a comment
        name=test
        ! This is also a comment
        value=42
        ''';
        final result = parser.parse(props);
        
        expect(result['name'], equals('test'));
        expect(result['value'], equals('42'));
        expect(result.length, equals(2));
      });

      test('handles line continuations', () {
        const props = '''
        long.value=This is a very \\
                   long value that \\
                   spans multiple lines
        ''';
        final result = parser.parse(props);
        
        expect(result['long']['value'], 
               equals('This is a very long value that spans multiple lines'));
      });

      test('handles colon separator', () {
        const props = '''
        name: test
        value: 42
        ''';
        final result = parser.parse(props);
        
        expect(result['name'], equals('test'));
        expect(result['value'], equals('42'));
      });

      test('handles escaped characters', () {
        const props = r'''
        path=C\:\\Program Files\\App
        newline=Line 1\nLine 2
        tab=Column1\tColumn2
        ''';
        final result = parser.parse(props);
        
        expect(result['path'], equals('C:\\Program Files\\App'));
        expect(result['newline'], equals('Line 1\nLine 2'));
        expect(result['tab'], equals('Column1\tColumn2'));
      });

      test('handles empty values', () {
        const props = '''
        empty=
        space= 
        ''';
        final result = parser.parse(props);
        
        expect(result['empty'], equals(''));
        expect(result['space'], equals(''));
      });
    });

    group('parseAsset', () {
      test('parses asset with content bytes', () {
        const props = 'name=from_asset\nvalue=123';
        final asset = TestAsset(
          filePath: 'config.properties',
          fileName: 'config.properties',
          packageName: 'test',
          contentBytes: Uint8List.fromList(props.codeUnits),
        );
        
        final result = parser.parseAsset(asset);
        expect(result['name'], equals('from_asset'));
        expect(result['value'], equals('123'));
      });
    });
  });
}