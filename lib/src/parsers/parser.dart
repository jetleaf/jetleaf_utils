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

import 'dart:io';

import 'package:jetleaf_lang/lang.dart';

import '../exceptions.dart';

/// {@template parser}
/// A **base interface for all configuration parsers** in Jetleaf.
///
/// Parsers are responsible for converting raw configuration sources
/// (strings, assets, or files) into a normalized `Map<String, dynamic>`
/// representation.  
/// This abstraction allows Jetleaf to support multiple configuration
/// formats (JSON, YAML, XML, properties files, etc.) while providing
/// a unified API for accessing configuration values.
///
/// ### Core responsibilities:
/// - Parse raw string sources with [parse].
/// - Parse from [Asset]s with [parseAsset].
/// - Parse into generic objects with [parseAs].
/// - Optionally parse directly from files with [parseFile].
///
/// ### Example implementation (JSON parser):
/// ```dart
/// class JsonParser extends Parser {
///   @override
///   Map<String, dynamic> parse(String source) {
///     return jsonDecode(source) as Map<String, dynamic>;
///   }
///
///   @override
///   Map<String, dynamic> parseFile(String path) {
///     final fileContent = File(path).readAsStringSync();
///     return parse(fileContent);
///   }
/// }
///
/// void main() {
///   final parser = JsonParser();
///
///   final config = parser.parse('{"host": "localhost", "port": 8080}');
///   print(config['host']); // Output: localhost
/// }
/// ```
/// {@endtemplate}
abstract class Parser {
  /// {@template parser_parse}
  /// Parses the given [source] string into a `Map<String, dynamic>`.
  ///
  /// Implementations must:
  /// - Convert the raw string into structured key-value pairs.
  /// - Return a valid map representation.
  /// - Throw a [FormatException] if parsing fails due to invalid syntax
  ///   or unexpected input.
  ///
  /// Example:
  /// ```dart
  /// final config = parser.parse('{"debug": true}');
  /// print(config['debug']); // true
  /// ```
  /// {@endtemplate}
  Map<String, dynamic> parse(String source) => throw ParserException('Parser does not support parsing strings');

  /// {@template parser_parse_asset}
  /// Parses a Jetleaf [Asset] into a `Map<String, dynamic>`.
  ///
  /// The default implementation converts the asset's bytes to a string
  /// and delegates to [parse]. Implementations may override this for
  /// more efficient handling (e.g., decoding binary formats).
  ///
  /// Example:
  /// ```dart
  /// final asset = Asset('config.json');
  /// final config = parser.parseAsset(asset);
  /// print(config['host']); // localhost
  /// ```
  /// {@endtemplate}
  Map<String, dynamic> parseAsset(Asset asset) => parse(asset.getContentAsString());

  /// {@template parser_parse_as}
  /// Parses the given [Asset] and returns it as a generic [Object].
  ///
  /// This is useful when the parser needs to support both structured
  /// maps and more dynamic representations. By default, it delegates
  /// to [parseAsset].
  ///
  /// Example:
  /// ```dart
  /// final asset = Asset('config.yaml');
  /// final result = parser.parseAs(asset);
  /// print(result); // Map<String, dynamic>
  /// ```
  /// {@endtemplate}
  Object parseAs(Asset asset) => parseAsset(asset);

  /// {@template parser_parse_file}
  /// Optionally parses configuration directly from a file located at [path].
  ///
  /// By default, this method throws a [ParserException] to indicate that
  /// file-based parsing is not supported.  
  /// Implementations should override this if file parsing is required.
  ///
  /// Example:
  /// ```dart
  /// final config = parser.parseFile('config.json');
  /// print(config['port']); // e.g. 8080
  /// ```
  /// {@endtemplate}
  Map<String, dynamic> parseFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw ParserException('File not found: $path');
    }
    final content = file.readAsStringSync();
    return parse(content);
  }
}