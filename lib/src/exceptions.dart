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

/// {@template bundler_exception}
/// An exception thrown when an asset cannot be loaded by the JetLeaf bundler.
///
/// This exception typically occurs when trying to read or resolve a file
/// that does not exist, is inaccessible, or fails during the bundling process.
///
/// The [assetPath] provides the full relative or absolute path of the asset
/// that failed to load, and the optional [cause] can point to the underlying
/// exception that triggered the failure.
///
/// Example usage:
/// ```dart
/// throw AssetLoaderException('Failed to load template', 'templates/home.html');
/// ```
/// {@endtemplate}
class AssetLoaderException extends RuntimeException {
  /// The full path to the asset that could not be loaded.
  final String assetPath;

  /// {@macro bundler_exception}
  ///
  /// - [message]: A human-readable error message describing the failure.
  /// - [assetPath]: The relative or absolute path of the asset.
  /// - [cause]: (Optional) The underlying cause of the error.
  AssetLoaderException(super.message, this.assetPath, {super.cause});

  /// Returns a human-readable string representation of the exception,
  /// including the asset path and the underlying cause, if present.
  @override
  String toString() {
    final buffer = StringBuffer('AssetLoaderException: $message');
    buffer.writeln('\nAsset path: $assetPath');
    if (cause != null) {
      buffer.writeln('Caused by: $cause');
    }
    return buffer.toString();
  }
}

/// {@template placeholder_resolution_exception}
/// Exception thrown when placeholder resolution fails.
///
/// Contains the reason, the problematic placeholder, and the resolution
/// path (the chain of values that led to the failure).
///
/// Example:
/// ```dart
/// throw PlaceholderResolutionException(
///   'Unresolvable placeholder',
///   'my.key',
///   'my.key=value'
/// );
/// ```
/// {@endtemplate}
class PlaceholderResolutionException extends RuntimeException {
  /// Reason for the failure.
  final String reason;

  /// The placeholder that could not be resolved.
  final String placeholder;

  /// Resolution chain (e.g. key -> fallback -> default) that led to the error.
  final List<String> values;

  /// Creates an exception with a reason, placeholder, and optional value.
  PlaceholderResolutionException(
    this.reason,
    this.placeholder, [
    String? value,
  ])  : values = value != null ? [value] : const [],
        super(_buildMessage(reason, value != null ? [value] : const []));

  /// Internal constructor used to support multiple values in the resolution chain.
  PlaceholderResolutionException._internal(
    this.reason,
    this.placeholder,
    this.values,
  ) : super(_buildMessage(reason, values));

  /// Adds a parent resolution value to the chain and returns a new exception.
  PlaceholderResolutionException withValue(String value) {
    return PlaceholderResolutionException._internal(
      reason,
      placeholder,
      [...values, value],
    );
  }

  /// Builds a detailed error message.
  static String _buildMessage(String reason, List<String> values) {
    if (values.isEmpty) return reason;
    final valueChain = values.map((v) => '"$v"').toList();
    return '$reason in value %s'.formatted([valueChain.join(' <-- ')]);
  }
}

/// {@template parser_exception}
/// Exception thrown when parsing fails.
/// 
/// This exception is thrown by [Parser] implementations when parsing fails.
///
/// Example:
/// ```dart
/// throw ParserException('Failed to parse config', 'config.json');
/// ```
/// {@endtemplate}
class ParserException extends RuntimeException {
  /// {@macro parser_exception}
  ParserException(super.message, {super.cause});
}