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

/// {@template string_utils}
/// 🚀 `StringUtils` — A collection of common string manipulation utilities.
///
/// This class provides static methods for checking string properties,
/// modifying, formatting, parsing, and cleaning strings. It aims to simplify
/// typical string-related tasks like trimming, tokenizing, quoting, and path manipulation.
///
/// ---
///
/// ### 📦 Example Usage:
///
/// ```dart
/// StringUtils.hasText(' hello ');                      // true
/// StringUtils.trimAllWhitespace('  a b  ');            // 'ab'
/// StringUtils.countOccurrencesOf('abcabc', 'a');       // 2
/// StringUtils.cleanPath('/foo/../bar');                // '/bar'
/// StringUtils.tokenizeToStringArray('a,b;c', ',;');    // ['a', 'b', 'c']
/// ```
///
/// All methods are static and null-safe where applicable.
/// {@endtemplate}
class StringUtils {
  /// {@macro string_utils}
  StringUtils._();

  /// Check if a string has length
  static bool hasLength(String? str) {
    return str != null && str.isNotEmpty;
  }

  /// Check if a string contains whitespace
  static bool containsWhitespace(String? str) {
    if (!hasLength(str)) return false;
    return str!.contains(RegExp(r'\s'));
  }

  /// Trim all whitespace from a string
  static String trimAllWhitespace(String str) {
    if (!hasLength(str)) return str;
    return str.replaceAll(RegExp(r'\s'), '');
  }

  /// Trim leading character from string
  static String trimLeadingCharacter(String str, String leadingCharacter) {
    if (!hasLength(str)) return str;
    while (str.startsWith(leadingCharacter)) {
      str = str.substring(1);
    }
    return str;
  }

  /// Trim trailing character from string
  static String trimTrailingCharacter(String str, String trailingCharacter) {
    if (!hasLength(str)) return str;
    while (str.endsWith(trailingCharacter)) {
      str = str.substring(0, str.length - 1);
    }
    return str;
  }

  /// Test if string starts with prefix, ignoring case
  static bool startsWithIgnoreCase(String? str, String? prefix) {
    if (str == null || prefix == null) return false;
    if (str.length < prefix.length) return false;
    return str.toLowerCase().startsWith(prefix.toLowerCase());
  }

  /// Test if string ends with suffix, ignoring case
  static bool endsWithIgnoreCase(String? str, String? suffix) {
    if (str == null || suffix == null) return false;
    if (str.length < suffix.length) return false;
    return str.toLowerCase().endsWith(suffix.toLowerCase());
  }

  /// Count occurrences of substring in string
  static int countOccurrencesOf(String str, String sub) {
    if (!hasLength(str) || !hasLength(sub)) return 0;
    int count = 0;
    int pos = 0;
    while ((pos = str.indexOf(sub, pos)) != -1) {
      count++;
      pos += sub.length;
    }
    return count;
  }

  /// Replace all occurrences of oldPattern with newPattern
  static String replace(String inString, String oldPattern, String newPattern) {
    if (!hasLength(inString) || !hasLength(oldPattern)) return inString;
    return inString.replaceAll(oldPattern, newPattern);
  }

  /// Delete all occurrences of pattern
  static String delete(String inString, String pattern) {
    return replace(inString, pattern, '');
  }

  /// Delete any character in charsToDelete
  static String deleteAny(String inString, String? charsToDelete) {
    if (!hasLength(inString) || !hasLength(charsToDelete)) return inString;
    
    final buffer = StringBuffer();
    for (int i = 0; i < inString.length; i++) {
      final char = inString[i];
      if (!charsToDelete!.contains(char)) {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  /// Quote a string with single quotes
  static String? quote(String? str) {
    return str != null ? "'$str'" : null;
  }

  /// Unqualify a string by removing everything before the last dot
  static String unqualify(String qualifiedName, [String separator = '.']) {
    final index = qualifiedName.lastIndexOf(separator);
    return index != -1 ? qualifiedName.substring(index + 1) : qualifiedName;
  }

  /// Capitalize first letter
  static String capitalize(String str) {
    if (!hasLength(str)) return str;
    return str[0].toUpperCase() + str.substring(1);
  }

  /// Uncapitalize first letter
  static String uncapitalize(String str) {
    if (!hasLength(str)) return str;
    return str[0].toLowerCase() + str.substring(1);
  }

  /// Extract filename from path
  static String? getFilename(String? path) {
    if (path == null) return null;
    final separatorIndex = path.lastIndexOf('/');
    return separatorIndex != -1 ? path.substring(separatorIndex + 1) : path;
  }

  /// Extract file extension from path
  static String? getFilenameExtension(String? path) {
    if (path == null) return null;
    final extIndex = path.lastIndexOf('.');
    if (extIndex == -1) return null;
    final folderIndex = path.lastIndexOf('/');
    if (folderIndex > extIndex) return null;
    return path.substring(extIndex + 1);
  }

  /// Strip filename extension
  static String stripFilenameExtension(String path) {
    final extIndex = path.lastIndexOf('.');
    if (extIndex == -1) return path;
    final folderIndex = path.lastIndexOf('/');
    if (folderIndex > extIndex) return path;
    return path.substring(0, extIndex);
  }

  /// Clean path by normalizing separators and resolving . and ..
  static String cleanPath(String path) {
    if (!hasLength(path)) return path;
    
    String normalizedPath = path.replaceAll('\\', '/');
    
    if (!normalizedPath.contains('.')) return normalizedPath;
    
    final parts = normalizedPath.split('/');
    final cleanParts = <String>[];
    
    for (final part in parts) {
      if (part == '.' || part.isEmpty) {
        continue;
      } else if (part == '..') {
        if (cleanParts.isNotEmpty && cleanParts.last != '..') {
          cleanParts.removeLast();
        } else {
          cleanParts.add(part);
        }
      } else {
        cleanParts.add(part);
      }
    }
    
    final result = cleanParts.join('/');
    return normalizedPath.startsWith('/') ? '/$result' : result;
  }

  /// Split string at first occurrence of delimiter
  static List<String>? split(String? toSplit, String? delimiter) {
    if (!hasLength(toSplit) || !hasLength(delimiter)) return null;
    final index = toSplit!.indexOf(delimiter!);
    if (index < 0) return null;
    return [
      toSplit.substring(0, index),
      toSplit.substring(index + delimiter.length)
    ];
  }

  /// Convert collection to delimited string
  static String collectionToDelimitedString(
    Iterable? collection, 
    String delimiter, [
    String prefix = '',
    String suffix = ''
  ]) {
    if (collection == null || collection.isEmpty) return '';
    return collection.map((e) => '$prefix$e$suffix').join(delimiter);
  }

  /// Convert collection to comma delimited string
  static String collectionToCommaDelimitedString(Iterable? collection) {
    return collectionToDelimitedString(collection, ',');
  }

  /// Tokenizes a string into a list using multiple [delimiters].
  ///
  /// Trims and ignores empty tokens by default.
  static List<String> tokenizeToStringArray(
    String? str, 
    String delimiters, [
    bool trimTokens = true,
    bool ignoreEmptyTokens = true
  ]) {
    if (str == null) return [];
    
    final tokens = <String>[];
    final regex = RegExp('[${RegExp.escape(delimiters)}]+');
    final parts = str.split(regex);
    
    for (String token in parts) {
      if (trimTokens) token = token.trim();
      if (!ignoreEmptyTokens || token.isNotEmpty) {
        tokens.add(token);
      }
    }
    
    return tokens;
  }

  /// Convert delimited list to string array
  static List<String> delimitedListToStringArray(String? str, String? delimiter) {
    if (str == null) return [];
    if (delimiter == null) return [str];
    return str.split(delimiter);
  }

  /// Convert comma delimited list to string array
  static List<String> commaDelimitedListToStringList(String? str) {
    return delimitedListToStringArray(str, ',');
  }

  /// Convert comma delimited list to set
  static Set<String> commaDelimitedListToSet(String? str) {
    return commaDelimitedListToStringList(str).toSet();
  }

  /// Check if string matches character
  static bool matchesCharacter(String? str, String singleCharacter) {
    return str != null && str.length == 1 && str == singleCharacter;
  }

  /// Truncate string
  /// 
  /// Truncates the string to the specified threshold, adding "..." if the string is longer than the threshold.
  /// 
  /// [threshold] is the maximum length of the string to return. If the string is longer than this, it will be truncated.
  /// 
  /// Throws [InvalidArgumentException] if [threshold] is less than or equal to 0.
  /// 
  /// Returns the truncated string if it is longer than the threshold, otherwise returns the original string.
  static String truncate(String str, [int threshold = 100]) {
    if (threshold <= 0) throw InvalidArgumentException('Truncation threshold must be positive: $threshold');
    if (str.length > threshold) {
      return '${str.substring(0, threshold)} (truncated)...';
    }
    return str;
  }
}