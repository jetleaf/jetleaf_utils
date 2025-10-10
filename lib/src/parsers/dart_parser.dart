import 'package:jetleaf_lang/lang.dart';

import 'parser.dart';
import '../exceptions.dart';

/// {@template dart_parser}
/// A **parser for Dart configuration files** in Jetleaf.
///
/// This parser supports parsing Dart **map literals** and **variable declarations**
/// to extract configuration data.  
/// It is designed to handle:
/// - `final`, `const`, or `var` assignments with map literals.
/// - Direct map literals (`{ ... }`).
/// - Nested maps and lists.
/// - Strings, numbers, booleans, and null values.
/// - Preservation of special Jetleaf property syntax (`#{}` and `@{}`),
///   which are returned as raw strings for later resolution.
///
/// ### Example usage:
/// ```dart
/// void main() {
///   final parser = DartParser();
///
///   const source = '''
///   final config = {
///     "host": "localhost",
///     "port": 8080,
///     "debug": true,
///     "nested": {
///       "feature": "enabled"
///     },
///     "list": [1, 2, 3],
///     "dynamic": "#{someExpression}"
///   };
///   ''';
///
///   final config = parser.parse(source);
///
///   print(config['host']); // localhost
///   print(config['port']); // 8080
///   print(config['nested']); // {feature: enabled}
///   print(config['list']); // [1, 2, 3]
///   print(config['dynamic']); // #{someExpression}
/// }
/// ```
/// {@endtemplate}
class DartParser extends Parser {
  /// {@macro dart_parser}
  DartParser();

  @override
  Map<String, dynamic> parse(String source) {
    try {
      // Remove comments and clean up the source
      final cleanSource = _removeComments(source);
      
      // Look for map literals or variable assignments
      final mapMatch = RegExp(r'(?:final|const|var)?\s*\w*\s*=\s*(\{.*\})', dotAll: true)
          .firstMatch(cleanSource);
      
      if (mapMatch != null) {
        return _parseMapLiteral(mapMatch.group(1)!);
      }
      
      // Try to parse as direct map literal
      final directMapMatch = RegExp(r'^\s*(\{.*\})\s*$', dotAll: true)
          .firstMatch(cleanSource);
      
      if (directMapMatch != null) {
        return _parseMapLiteral(directMapMatch.group(1)!);
      }
      
      throw ParserException('No valid Dart map found in source');
    } catch (e) {
      if (e is ParserException) rethrow;
      throw ParserException('Failed to parse Dart: $e');
    }
  }

  /// {@template remove_comments}
  /// Removes single-line and multi-line comments from the given [source].
  /// {@endtemplate}
  String _removeComments(String source) {
    // Remove single-line comments
    source = source.replaceAll(RegExp(r'//.*$', multiLine: true), '');
    
    // Remove multi-line comments
    source = source.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
    
    return source;
  }

  /// {@template parse_map_literal}
  /// Parses a Dart map literal from the given [mapStr].
  /// {@endtemplate}
  Map<String, dynamic> _parseMapLiteral(String mapStr) {
    mapStr = mapStr.trim();
    if (!mapStr.startsWith('{') || !mapStr.endsWith('}')) {
      throw ParserException('Invalid map literal format');
    }
    
    final content = mapStr.substring(1, mapStr.length - 1).trim();
    if (content.isEmpty) return {};
    
    final result = <String, dynamic>{};
    final entries = _parseMapEntries(content);
    
    for (final entry in entries) {
      final colonIndex = entry.indexOf(':');
      if (colonIndex == -1) continue;
      
      final keyStr = entry.substring(0, colonIndex).trim();
      final valueStr = entry.substring(colonIndex + 1).trim();
      
      final key = _parseKey(keyStr);
      final value = _parseValue(valueStr);
      
      result[key] = value;
    }
    
    return result;
  }

  /// {@template parse_map_entries}
  /// Parses the entries of a Dart map literal from the given [content].
  /// {@endtemplate}
  List<String> _parseMapEntries(String content) {
    final entries = <String>[];
    final buffer = StringBuffer();
    int depth = 0;
    bool inString = false;
    String? stringDelimiter;
    
    for (int i = 0; i < content.length; i++) {
      final char = content[i];
      
      if (!inString) {
        if (char == '"' || char == "'") {
          inString = true;
          stringDelimiter = char;
        } else if (char == '{' || char == '[') {
          depth++;
        } else if (char == '}' || char == ']') {
          depth--;
        } else if (char == ',' && depth == 0) {
          entries.add(buffer.toString().trim());
          buffer.clear();
          continue;
        }
      } else {
        if (char == stringDelimiter && (i == 0 || content[i - 1] != '\\')) {
          inString = false;
          stringDelimiter = null;
        }
      }
      
      buffer.write(char);
    }
    
    if (buffer.isNotEmpty) {
      entries.add(buffer.toString().trim());
    }
    
    return entries;
  }

  /// {@template parse_key}
  /// Parses a key from the given [keyStr].
  /// {@endtemplate}
  String _parseKey(String keyStr) {
    keyStr = keyStr.trim();
    
    // Handle quoted keys
    if ((keyStr.startsWith('"') && keyStr.endsWith('"')) ||
        (keyStr.startsWith("'") && keyStr.endsWith("'"))) {
      return keyStr.substring(1, keyStr.length - 1);
    }
    
    // Handle unquoted identifiers
    return keyStr;
  }

  /// {@template parse_value}
  /// Parses a value from the given [valueStr].
  /// {@endtemplate}
  dynamic _parseValue(String valueStr) {
    valueStr = valueStr.trim();
    
    // Handle null
    if (valueStr == 'null') return null;
    
    // Handle booleans
    if (valueStr == 'true') return true;
    if (valueStr == 'false') return false;
    
    // Handle strings
    if ((valueStr.startsWith('"') && valueStr.endsWith('"')) ||
        (valueStr.startsWith("'") && valueStr.endsWith("'"))) {
      return _unescapeString(valueStr.substring(1, valueStr.length - 1));
    }
    
    // Handle numbers
    if (RegExp(r'^-?\d+$').hasMatch(valueStr)) {
      return int.tryParse(valueStr) ?? valueStr;
    }
    if (RegExp(r'^-?\d+\.\d+$').hasMatch(valueStr)) {
      return double.tryParse(valueStr) ?? valueStr;
    }
    
    // Handle lists
    if (valueStr.startsWith('[') && valueStr.endsWith(']')) {
      return _parseList(valueStr);
    }
    
    // Handle nested maps
    if (valueStr.startsWith('{') && valueStr.endsWith('}')) {
      return _parseMapLiteral(valueStr);
    }
    
    // Return as string for any other value (including special syntax)
    return valueStr;
  }

  /// {@template unescape_string}
  /// Unescapes a string by replacing escape sequences with their corresponding characters.
  /// {@endtemplate}
  String _unescapeString(String str) {
    final escapeMap = {
      'n': '\n',
      'r': '\r',
      't': '\t',
      '"': '"',
      "'": "'",
      '\\': '\\',
    };

    // Match backslash + one character
    return str.replaceAllMapped(
      RegExp(r'\\(.)'),
      (match) => escapeMap[match[1]] ?? match[0]!,
    );
  }

  /// {@template parse_list}
  /// Parses a list from the given [listStr].
  /// {@endtemplate}
  List<dynamic> _parseList(String listStr) {
    final content = listStr.substring(1, listStr.length - 1).trim();
    if (content.isEmpty) return [];
    
    final items = <dynamic>[];
    final elements = _parseListElements(content);
    
    for (final element in elements) {
      items.add(_parseValue(element.trim()));
    }
    
    return items;
  }

  /// {@template parse_list_elements}
  /// Parses the elements of a list from the given [content].
  /// {@endtemplate}
  List<String> _parseListElements(String content) {
    final elements = <String>[];
    final buffer = StringBuffer();
    int depth = 0;
    bool inString = false;
    String? stringDelimiter;
    
    for (int i = 0; i < content.length; i++) {
      final char = content[i];
      
      if (!inString) {
        if (char == '"' || char == "'") {
          inString = true;
          stringDelimiter = char;
        } else if (char == '{' || char == '[') {
          depth++;
        } else if (char == '}' || char == ']') {
          depth--;
        } else if (char == ',' && depth == 0) {
          elements.add(buffer.toString());
          buffer.clear();
          continue;
        }
      } else {
        if (char == stringDelimiter && (i == 0 || content[i - 1] != '\\')) {
          inString = false;
          stringDelimiter = null;
        }
      }
      
      buffer.write(char);
    }
    
    if (buffer.isNotEmpty) {
      elements.add(buffer.toString());
    }
    
    return elements;
  }

  @override
  Map<String, dynamic> parseAsset(Asset asset) {
    try {
      return super.parseAsset(asset);
    } catch (e) {
      throw ParserException('Failed to parse Dart asset ${asset.getFileName()}: $e');
    }
  }

  @override
  Map<String, dynamic> parseFile(String path) {
    try {
      return super.parseFile(path);
    } catch (e) {
      if (e is ParserException) rethrow;
      throw ParserException('Failed to parse Dart file $path: $e');
    }
  }
}