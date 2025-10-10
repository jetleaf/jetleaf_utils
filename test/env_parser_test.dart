import 'dart:typed_data';

import 'package:jetleaf_utils/utils.dart';
import 'package:test/test.dart';

import '_helpers.dart';

void main() {
  group('EnvParser', () {
    late EnvParser parser;

    setUp(() {
      parser = EnvParser();
    });

    test('parses simple key=value', () {
      final result = parser.parse('FOO=bar');
      expect(result, {'FOO': 'bar'});
    });

    test('parses with colon delimiter', () {
      final result = parser.parse('FOO:bar');
      expect(result['FOO'], 'bar');
    });

    test('ignores comments and blank lines', () {
      final src = '''
# comment
; another comment

FOO=bar
BAZ=qux
''';
      final result = parser.parse(src);
      expect(result, {
        'FOO': 'bar',
        'BAZ': 'qux',
      });
    });

    test('supports export prefix', () {
      final result = parser.parse('export FOO=bar');
      expect(result['FOO'], 'bar');
    });

    test('normalizes CRLF and BOM', () {
      final src = '\uFEFFFOO=bar\r\nBAR=baz\rQUX=zap';
      final result = parser.parse(src);
      expect(result, {
        'FOO': 'bar',
        'BAR': 'baz',
        'QUX': 'zap',
      });
    });

    test('unquoted value with inline comment', () {
      final src = 'FOO=bar # this is a comment';
      final result = parser.parse(src);
      expect(result['FOO'], 'bar');
    });

    test('quoted values (single and double)', () {
      final src = '''
SINGLE='hello world'
DOUBLE="hello world"
''';
      final result = parser.parse(src);
      expect(result['SINGLE'], 'hello world');
      expect(result['DOUBLE'], 'hello world');
    });

    test('quoted values with escapes', () {
      final src = r'''
DOUBLE="line1\nline2\tTabbed \"Quote\""
SINGLE='It\'s fine'
''';
      final result = parser.parse(src);
      expect(result['DOUBLE'], 'line1\nline2\tTabbed "Quote"');
      expect(result['SINGLE'], "It's fine");
    });

    test('multiline quoted values', () {
      final src = '''
FOO="line1
line2
line3"
''';
      final result = parser.parse(src);
      expect(result['FOO'], 'line1\nline2\nline3');
    });

    test('unterminated quoted value throws', () {
      final src = 'FOO="hello';
      expect(() => parser.parse(src), throwsA(isA<ParserException>()));
    });

    test('empty value defaults to empty string', () {
      final src = 'FOO=';
      final result = parser.parse(src);
      expect(result['FOO'], '');
    });

    test('key without value defaults to empty string', () {
      final src = 'FOO';
      final result = parser.parse(src);
      expect(result['FOO'], '');
    });

    test('invalid key throws', () {
      final src = '123FOO=bar';
      expect(() => parser.parse(src), throwsA(isA<ParserException>()));
    });

    test('parseFile wraps exceptions', () {
      expect(() => parser.parseFile('nonexistent.env'),
          throwsA(isA<ParserException>()));
    });

    test('parseAsset wraps exceptions', () {
      final asset = TestAsset(filePath: 'fake.env', fileName: 'fake.env', packageName: 'test', contentBytes: Uint8List.fromList('INVALID=@@'.codeUnits));
      final result = parser.parseAsset(asset);
      expect(result['INVALID'], '@@');
    });
  });
}
