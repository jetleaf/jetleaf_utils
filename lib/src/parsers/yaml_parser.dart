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

import 'package:jetleaf_lang/lang.dart';

import 'parser.dart';
import '../exceptions.dart';

/// {@template yaml_parser}
/// A parser for YAML configuration files.
/// 
/// Supports YAML syntax including nested structures, lists, and comments.
/// Preserves special property values like #{} and @{} for later resolution.
/// 
/// #{} and @{} are used to preserve special property values like #{} and @{} for later resolution.
/// 
/// ### Example usage:
/// ```dart
/// void main() {
///   final parser = YamlParser();
/// 
///   final config = parser.parse('key: value');
///   print(config['key']); // Output: value
/// 
///   final config = parser.parseAsset(asset);
///   print(config['key']); // Output: value
/// 
///   final config = parser.parseFile('config.yaml');
///   print(config['key']); // Output: value
/// }
/// ```
/// {@endtemplate}
class YamlParser extends Parser {
  /// {@macro yaml_parser}
  YamlParser();

  @override
  Map<String, dynamic> parse(String source) {
    try {
      final lines = source.split('\n');
      final root = <String, dynamic>{};

      // containerStack holds either Map<String,dynamic> or List<dynamic>
      final List<dynamic> containerStack = [root];
      final List<int> indentStack = [0];

      for (var i = 0; i < lines.length; i++) {
        var originalLine = lines[i];
        var line = originalLine.replaceFirst(RegExp(r'\r$'), '').trimRight();
        if (line.trim().isEmpty) continue;
        final trimmed = line.trim();
        if (trimmed.startsWith('#')) continue; // comment

        final indent = _getIndentation(originalLine);

        // pop containers until current indent is < stack top indent
        while (indentStack.isNotEmpty && indent <= indentStack.last && indentStack.length > 1) {
          indentStack.removeLast();
          containerStack.removeLast();
        }

        final currentContainer = containerStack.last;

        // List item
        if (trimmed.startsWith('-')) {
          final itemText = trimmed.length > 1 ? trimmed.substring(1).trim() : '';

          // Ensure we have a List to append to. If currentContainer is Map, attempt to attach list to last key.
          List<dynamic>? targetList;
          if (currentContainer is List) {
            targetList = currentContainer;
          } else if (currentContainer is Map<String, dynamic>) {
            if (currentContainer.isEmpty) {
              // nothing to attach list to — create an anonymous list? skip
              // This case shouldn't normally occur for well-formed YAML that uses key: followed by - items
              targetList = <dynamic>[];
              // We cannot assign to a key, so append to root? fallback:
              (containerStack.first as Map)[
                  '__anonymous_list_${indentStack.length}_$i'] = targetList;
            } else {
              // assume last key stores the list
              final lastKey = currentContainer.keys.last;
              var existing = currentContainer[lastKey];
              if (existing is! List) {
                existing = <dynamic>[];
                currentContainer[lastKey] = existing;
              }
              targetList = existing;
            }
          } else {
            // unknown container type - skip
            continue;
          }

          // Process itemText
          if (itemText.isEmpty) {
            // item is a nested map (block sequence)
            final newMap = <String, dynamic>{};
            targetList.add(newMap);
            // push newMap as current container with indent greater than '-' line
            containerStack.add(newMap);
            indentStack.add(indent + 1);
          } else if (itemText.contains(':')) {
            // inline map item: "- key: value"
            final colonIdx = itemText.indexOf(':');
            final k = itemText.substring(0, colonIdx).trim();
            final vstr = itemText.substring(colonIdx + 1).trim();
            final entryMap = <String, dynamic>{k: _parseValue(vstr)};
            targetList.add(entryMap);
          } else {
            // scalar item
            targetList.add(_parseValue(itemText));
          }

          continue;
        }

        // Key: value or key: (empty => nested structure)
        if (trimmed.contains(':')) {
          final colonIndex = trimmed.indexOf(':');
          final key = trimmed.substring(0, colonIndex).trim();
          final valueStr = trimmed.substring(colonIndex + 1).trim();

          if (currentContainer is! Map<String, dynamic>) {
            // if we are inside a List with a Map last element, use that map
            if (currentContainer is List && currentContainer.isNotEmpty && currentContainer.last is Map<String, dynamic>) {
              final parentMap = currentContainer.last as Map<String, dynamic>;
              if (valueStr.isEmpty) {
                // decide whether to create a list or map by looking ahead
                final next = _peekNextNonEmptyLine(lines, i);
                if (next != null && next.indent > indent && next.trim.startsWith('-')) {
                  final list = <dynamic>[];
                  parentMap[key] = list;
                  containerStack.add(list);
                  indentStack.add(indent + 1);
                } else {
                  final nested = <String, dynamic>{};
                  parentMap[key] = nested;
                  containerStack.add(nested);
                  indentStack.add(indent + 1);
                }
              } else {
                parentMap[key] = _parseValue(valueStr);
              }
              continue;
            } else {
              // Unexpected: current container is not a map - create a map and attach? fallback to root
              if (containerStack.first is Map<String, dynamic>) {
                (containerStack.first as Map)[key] = valueStr.isEmpty ? <String, dynamic>{} : _parseValue(valueStr);
                if (valueStr.isEmpty) {
                  containerStack.add((containerStack.first as Map)[key]);
                  indentStack.add(indent + 1);
                }
                continue;
              }
            }
          }

          // currentContainer is a Map<String,dynamic>
          final map = currentContainer as Map<String, dynamic>;

          if (valueStr.isEmpty) {
            // Need to look ahead to decide if this key maps to a List or Map
            final next = _peekNextNonEmptyLine(lines, i);
            if (next != null && next.indent > indent && next.trim.startsWith('-')) {
              // create a list
              final list = <dynamic>[];
              map[key] = list;
              containerStack.add(list);
              indentStack.add(indent + 1);
            } else {
              // create a nested map
              final nested = <String, dynamic>{};
              map[key] = nested;
              containerStack.add(nested);
              indentStack.add(indent + 1);
            }
          } else if (valueStr.startsWith('[') && valueStr.endsWith(']')) {
            map[key] = _parseInlineArray(valueStr);
          } else if (valueStr.startsWith('{') && valueStr.endsWith('}')) {
            map[key] = _parseInlineObject(valueStr);
          } else {
            map[key] = _parseValue(valueStr);
          }

          continue;
        }

        // If we get here: a line without ":" and not starting with "-". We treat as scalar or ignore.
        // For robustness, try to attach to last map if possible.
        if (currentContainer is Map<String, dynamic> && currentContainer.isNotEmpty) {
          final lastKey = currentContainer.keys.last;
          // append/overwrite? Usually unexpected - we set as lastKey's value if it's a Map and previously empty.
          final lastVal = currentContainer[lastKey];
          if (lastVal is Map<String, dynamic> && lastVal.isEmpty) {
            // treat this line as "key: value" missing colon; skip in strict parser
            // ignore
          } else if (lastVal is List) {
            // could be something like a list item without '-'; ignore or add
          }
        }
      }

      return root;
    } catch (e) {
      throw ParserException('Failed to parse YAML: $e');
    }
  }

  /// Look ahead to next non-empty, non-comment line and return its trimmed text and indentation.
  _NextLine? _peekNextNonEmptyLine(List<String> lines, int currentIndex) {
    for (var j = currentIndex + 1; j < lines.length; j++) {
      final raw = lines[j];
      final trimmed = raw.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      return _NextLine(trimmed, _getIndentation(raw));
    }
    return null;
  }

  /// {@template yaml_parser_get_indentation}
  /// Returns the indentation level of the given line.
  /// 
  /// {@endtemplate}
  int _getIndentation(String line) {
    int count = 0;
    for (final char in line.runes) {
      if (char == 32) { // space
        count++;
      } else if (char == 9) { // tab
        count += 2; // Treat tab as 2 spaces
      } else {
        break;
      }
    }
    return count;
  }

  /// {@template yaml_parser_parse_value}
  /// Parses a YAML value into a Dart value.
  /// 
  /// {@endtemplate}
  dynamic _parseValue(String value) {
    value = value.trim();
    
    final commentIndex = value.indexOf('#');
    if (commentIndex != -1) {
      // Check if # is inside quotes
      bool inQuotes = false;
      String? quoteChar;
      
      for (int i = 0; i < commentIndex; i++) {
        final char = value[i];
        if (!inQuotes && (char == '"' || char == "'")) {
          inQuotes = true;
          quoteChar = char;
        } else if (inQuotes && char == quoteChar && (i == 0 || value[i - 1] != '\\')) {
          inQuotes = false;
          quoteChar = null;
        }
      }
      
      if (!inQuotes) {
        value = value.substring(0, commentIndex).trim();
      }
    }
    
    // Handle quoted strings
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      return value.substring(1, value.length - 1);
    }
    
    // Handle booleans
    if (value.toLowerCase() == 'true') return true;
    if (value.toLowerCase() == 'false') return false;
    
    // Handle null
    if (value.toLowerCase() == 'null' || value == '~') return null;
    
    // Handle numbers
    if (RegExp(r'^-?\d+$').hasMatch(value)) {
      return int.tryParse(value) ?? value;
    }
    if (RegExp(r'^-?\d+\.\d+$').hasMatch(value)) {
      return double.tryParse(value) ?? value;
    }
    
    // Return as string (preserving special syntax like #{} and @{})
    return value;
  }

  /// {@template yaml_parser_parse_inline_array}
  /// Parses an inline YAML array into a Dart list.
  /// 
  /// {@endtemplate}
  List<dynamic> _parseInlineArray(String arrayStr) {
    final content = arrayStr.substring(1, arrayStr.length - 1).trim();
    if (content.isEmpty) return [];
    
    final items = <dynamic>[];
    final parts = _splitByComma(content);
    
    for (final part in parts) {
      items.add(_parseValue(part.trim()));
    }
    
    return items;
  }

  /// {@template yaml_parser_parse_inline_object}
  /// Parses an inline YAML object into a Dart map.
  /// 
  /// {@endtemplate}
  Map<String, dynamic> _parseInlineObject(String objectStr) {
    final content = objectStr.substring(1, objectStr.length - 1).trim();
    if (content.isEmpty) return {};
    
    final result = <String, dynamic>{};
    final parts = _splitByComma(content);
    
    for (final part in parts) {
      final colonIndex = part.indexOf(':');
      if (colonIndex != -1) {
        final key = part.substring(0, colonIndex).trim();
        final value = part.substring(colonIndex + 1).trim();
        result[key] = _parseValue(value);
      }
    }
    
    return result;
  }

  /// {@template yaml_parser_split_by_comma}
  /// Splits a string by commas, preserving nested structures.
  /// 
  /// {@endtemplate}
  List<String> _splitByComma(String str) {
    final parts = <String>[];
    final buffer = StringBuffer();
    int depth = 0;
    bool inQuotes = false;
    String? quoteChar;
    
    for (int i = 0; i < str.length; i++) {
      final char = str[i];
      
      if (!inQuotes && (char == '"' || char == "'")) {
        inQuotes = true;
        quoteChar = char;
      } else if (inQuotes && char == quoteChar) {
        inQuotes = false;
        quoteChar = null;
      } else if (!inQuotes) {
        if (char == '[' || char == '{') {
          depth++;
        } else if (char == ']' || char == '}') {
          depth--;
        } else if (char == ',' && depth == 0) {
          parts.add(buffer.toString());
          buffer.clear();
          continue;
        }
      }
      
      buffer.write(char);
    }
    
    if (buffer.isNotEmpty) {
      parts.add(buffer.toString());
    }
    
    return parts;
  }

  @override
  Map<String, dynamic> parseAsset(Asset asset) {
    try {
      return super.parseAsset(asset);
    } catch (e) {
      throw ParserException('Failed to parse YAML asset ${asset.getFileName()}: $e');
    }
  }

  @override
  Map<String, dynamic> parseFile(String path) {
    try {
      return super.parseFile(path);
    } catch (e) {
      if (e is ParserException) rethrow;
      throw ParserException('Failed to parse YAML file $path: $e');
    }
  }
}

/// {@template yaml_parser_next_line}
/// Look ahead to next non-empty, non-comment line and return its trimmed text and indentation.
/// 
/// {@endtemplate}
class _NextLine {
  final String text; // trimmed text
  final int indent;

  /// {@macro yaml_parser_next_line}
  _NextLine(this.text, this.indent);

  /// {@template yaml_parser_next_line_get_trim}
  /// Returns the trimmed text of the next line.
  /// 
  /// {@endtemplate}
  String get trim => text;
}