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

/// {@template properties_parser}
/// A parser for Java-style properties files.
/// 
/// Supports key=value pairs, comments (# and !), line continuations (\),
/// and nested properties using dot notation. Preserves special property values
/// like #{} and @{} for later resolution.
/// 
/// ### Example usage:
/// ```dart
/// void main() {
///   final parser = PropertiesParser();
/// 
///   final config = parser.parse('host=localhost\nport=8080');
///   print(config['host']); // Output: localhost
/// 
///   final config = parser.parseAsset(asset);
///   print(config['host']); // Output: localhost
/// 
///   final config = parser.parseFile('config.properties');
///   print(config['host']); // Output: localhost
/// }
/// ```
/// {@endtemplate}
class PropertiesParser extends Parser {
  /// {@macro properties_parser}
  PropertiesParser();

  @override
  Map<String, dynamic> parse(String source) {
    try {
      final result = <String, dynamic>{};
      final lines = source.split('\n');
      String? continuedLine;
      
      for (var line in lines) {
        line = line.trim();
        
        // Handle line continuation
        if (continuedLine != null) {
          line = continuedLine + line;
          continuedLine = null;
        }
        
        // Skip empty lines and comments
        if (line.isEmpty || line.startsWith('#') || line.startsWith('!')) {
          continue;
        }
        
        // Check for line continuation
        if (line.endsWith('\\')) {
          continuedLine = line.substring(0, line.length - 1);
          continue;
        }
        
        // Parse key=value pair
        final separatorIndex = _findSeparator(line);
        if (separatorIndex == -1) {
          continue; // Skip invalid lines
        }
        
        final key = line.substring(0, separatorIndex).trim();
        final value = line.substring(separatorIndex + 1).trim();
        
        if (key.isNotEmpty) {
          _setNestedValue(result, key, _unescapeValue(value));
        }
      }
      
      return result;
    } catch (e) {
      throw ParserException('Failed to parse properties: $e');
    }
  }

  /// {@template properties_parser_find_separator}
  /// Finds the index of the first unescaped = or : in the given line.
  /// 
  /// {@endtemplate}
  int _findSeparator(String line) {
    // Look for = or : that's not escaped
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if ((char == '=' || char == ':') && (i == 0 || line[i - 1] != '\\')) {
        return i;
      }
    }
    return -1;
  }

  /// {@template properties_parser_unescape_value}
  /// Unescapes a properties value by replacing escaped characters with their
  /// unescaped counterparts.
  /// 
  /// {@endtemplate}
  String _unescapeValue(String value) {
    return value
        .replaceAll('\\n', '\n')
        .replaceAll('\\r', '\r')
        .replaceAll('\\t', '\t')
        .replaceAll('\\\\', '\\')
        .replaceAll('\\=', '=')
        .replaceAll('\\:', ':');
  }

  /// {@template properties_parser_set_nested_value}
  /// Sets a nested value in the given map.
  /// 
  /// {@endtemplate}
  void _setNestedValue(Map<String, dynamic> map, String key, String value) {
    final parts = key.split('.');
    dynamic current = map;

    for (int partIndex = 0; partIndex < parts.length; partIndex++) {
      final isLastPart = partIndex == parts.length - 1;
      final segment = parts[partIndex];

      // base name before any [index]
      final baseMatch = RegExp(r'^([^\[]+)').firstMatch(segment);
      final base = baseMatch != null ? baseMatch.group(1)! : segment;

      // all indices like [0], [1]
      final indices = RegExp(r'\[(\d+)\]').allMatches(segment).map((m) => int.parse(m.group(1)!)).toList();

      if (indices.isEmpty) {
        // simple property: "foo"
        if (current is Map<String, dynamic>) {
          if (isLastPart) {
            current[base] = value;
            return;
          } else {
            // ensure nested map exists
            if (current[base] == null || current[base] is! Map<String, dynamic>) {
              current[base] = <String, dynamic>{};
            }
            current = current[base];
            continue;
          }
        } else if (current is List) {
          // we are inside a list context, use last element's map
          if (current.isEmpty || current.last is! Map<String, dynamic>) {
            current.add(<String, dynamic>{});
          }
          final lastMap = current.last as Map<String, dynamic>;
          if (isLastPart) {
            lastMap[base] = value;
            return;
          } else {
            if (lastMap[base] == null || lastMap[base] is! Map<String, dynamic>) {
              lastMap[base] = <String, dynamic>{};
            }
            current = lastMap[base];
            continue;
          }
        } else {
          // unexpected container type - replace with map
          final newMap = <String, dynamic>{};
          if (isLastPart) {
            // can't attach key to unknown container; fallback to top-level map
            map[base] = value;
            return;
          } else {
            map[base] = newMap;
            current = newMap;
            continue;
          }
        }
      } else {
        // base with indices, e.g. "pods[0][1]"
        // Ensure a list exists at current[base] (when current is Map)
        if (current is Map<String, dynamic>) {
          if (current[base] == null || current[base] is! List<dynamic>) {
            current[base] = <dynamic>[];
          }
          dynamic list = current[base] as List<dynamic>;

          // Process each index in sequence
          for (int idxPos = 0; idxPos < indices.length; idxPos++) {
            final idx = indices[idxPos];
            // extend list
            while (list.length <= idx) {
              list.add(null);
            }

            final isLastIndex = idxPos == indices.length - 1;

            if (isLastIndex) {
              if (isLastPart) {
                // final destination: set scalar value
                list[idx] = value;
                return;
              } else {
                // need to descend: ensure element is a Map
                if (list[idx] == null || list[idx] is! Map<String, dynamic>) {
                  list[idx] = <String, dynamic>{};
                }
                current = list[idx];
                break; // move to next partIndex loop
              }
            } else {
              // nested lists like arr[0][1] => ensure list[idx] is List
              if (list[idx] == null || list[idx] is! List<dynamic>) {
                list[idx] = <dynamic>[];
              }
              list = list[idx] as List<dynamic>;
              // continue processing deeper index in this segment
            }
          } // end indices loop
          continue; // continue outer parts loop
        } else if (current is List) {
          // current is a list (we are in a list context), use the last item as the map that contains base
          if (current.isEmpty || current.last is! Map<String, dynamic>) {
            current.add(<String, dynamic>{});
          }
          final lastMap = current.last as Map<String, dynamic>;
          // Recursively treat base+indices on this lastMap
          _setNestedValue(lastMap, segment + (parts.length - 1 > partIndex ? '.' + parts.sublist(partIndex + 1).join('.') : ''), value);
          return;
        } else {
          // fallback: create map at top and recurse
          if (isLastPart) {
            map[base] = value;
            return;
          } else {
            map[base] = <String, dynamic>{};
            _setNestedValue(map[base] as Map<String, dynamic>, parts.sublist(partIndex + 1).join('.'), value);
            return;
          }
        }
      } // end indices handling
    } // end parts loop
  }

  @override
  Map<String, dynamic> parseAsset(Asset asset) {
    try {
      return super.parseAsset(asset);
    } catch (e) {
      throw ParserException('Failed to parse Properties asset ${asset.getFileName()}: $e');
    }
  }

  @override
  Map<String, dynamic> parseFile(String path) {
    try {
      return super.parseFile(path);
    } catch (e) {
      if (e is ParserException) rethrow;
      throw ParserException('Failed to parse Properties file $path: $e');
    }
  }
}