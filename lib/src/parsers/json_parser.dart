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

import 'dart:convert';

import 'package:jetleaf_lang/lang.dart';

import 'parser.dart';
import '../exceptions.dart';

/// {@template json_parser}
/// A parser for JSON configuration files.
/// 
/// Supports standard JSON syntax while preserving special property values
/// like #{} and @{} for later resolution.
/// 
/// ### Example usage:
/// ```dart
/// void main() {
///   final parser = JsonParser();
/// 
///   final config = parser.parse('{"host": "localhost", "port": 8080}');
///   print(config['host']); // Output: localhost
/// 
///   final config = parser.parseAsset(asset);
///   print(config['host']); // Output: localhost
/// 
///   final config = parser.parseFile('config.json');
///   print(config['host']); // Output: localhost
/// }
/// ```
/// {@endtemplate}
class JsonParser extends Parser {
  /// {@macro json_parser}
  JsonParser();

  @override
  Map<String, dynamic> parse(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      } else if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      } else {
        throw ParserException('JSON root must be an object, got ${decoded.runtimeType}');
      }
    } catch (e) {
      if (e is ParserException) rethrow;
      throw ParserException('Failed to parse JSON: $e');
    }
  }

  @override
  Map<String, dynamic> parseAsset(Asset asset) {
    try {
      return super.parseAsset(asset);
    } catch (e) {
      throw ParserException('Failed to parse JSON asset ${asset.getFileName()}: $e');
    }
  }

  @override
  Map<String, dynamic> parseFile(String path) {
    try {
      return super.parseFile(path);
    } catch (e) {
      if (e is ParserException) rethrow;
      throw ParserException('Failed to parse JSON file $path: $e');
    }
  }
}