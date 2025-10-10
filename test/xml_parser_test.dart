import 'dart:typed_data';

import 'package:jetleaf_utils/src/parsers/xml_parser.dart';
import 'package:test/test.dart';

import '_helpers.dart';

void main() {
  group('XmlParser', () {
    late XmlParser parser;

    setUp(() {
      parser = XmlParser();
    });

    group('parse', () {
      test('parses simple XML', () {
        const xml = '''
        <config>
          <name>test</name>
          <value>42</value>
        </config>
        ''';
        final result = parser.parse(xml);
        
        expect(result['config']['name'], equals('test'));
        expect(result['config']['value'], equals('42'));
      });

      test('parses XML with attributes', () {
        const xml = '''
        <database host="localhost" port="5432">
          <name>mydb</name>
        </database>
        ''';
        final result = parser.parse(xml);
        
        expect(result['database']['@host'], equals('localhost'));
        expect(result['database']['@port'], equals('5432'));
        expect(result['database']['name'], equals('mydb'));
      });

      test('handles self-closing tags', () {
        const xml = '''
        <config>
          <feature enabled="true"/>
          <debug/>
        </config>
        ''';
        final result = parser.parse(xml);
        
        expect(result['config']['feature']['@enabled'], equals('true'));
      });

      test('preserves special property values', () {
        const xml = '''
        <config>
          <url>#{base.url}/api</url>
          <token>@{security.token}</token>
          <mixed>prefix-#{value}-@{other}-suffix</mixed>
        </config>
        ''';
        final result = parser.parse(xml);
        
        expect(result['config']['url'], equals('#{base.url}/api'));
        expect(result['config']['token'], equals('@{security.token}'));
        expect(result['config']['mixed'], equals('prefix-#{value}-@{other}-suffix'));
      });

      test('handles multiple elements with same name', () {
        const xml = '''
        <config>
          <item>first</item>
          <item>second</item>
          <item>third</item>
        </config>
        ''';
        final result = parser.parse(xml);
        
        expect(result['config']['item'], equals(['first', 'second', 'third']));
      });

      test('ignores XML comments', () {
        const xml = '''
        <!-- This is a comment -->
        <config>
          <!-- Another comment -->
          <name>test</name>
        </config>
        ''';
        final result = parser.parse(xml);
        
        expect(result['config']['name'], equals('test'));
      });

      test('handles XML declaration', () {
        const xml = '''
        <?xml version="1.0" encoding="UTF-8"?>
        <config>
          <name>test</name>
        </config>
        ''';
        final result = parser.parse(xml);
        
        expect(result['config']['name'], equals('test'));
      });

      test('handles nested structures', () {
        const xml = '''
        <config>
          <database>
            <connection>
              <host>localhost</host>
              <port>5432</port>
            </connection>
          </database>
        </config>
        ''';
        final result = parser.parse(xml);
        
        expect(result['config']['database']['connection']['host'], equals('localhost'));
        expect(result['config']['database']['connection']['port'], equals('5432'));
      });
    });

    group('parseAsset', () {
      test('parses asset with content bytes', () {
        const xml = '<config><name>from_asset</name></config>';
        final asset = TestAsset(
          filePath: 'config.xml',
          fileName: 'config.xml',
          packageName: 'test',
          contentBytes: Uint8List.fromList(xml.codeUnits),
        );
        
        final result = parser.parseAsset(asset);
        expect(result['config']['name'], equals('from_asset'));
      });
    });
  });
}