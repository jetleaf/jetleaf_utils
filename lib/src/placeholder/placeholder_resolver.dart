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

/// {@template placeholder_resolver}
/// Strategy interface for resolving placeholder values in configuration strings.
///
/// A `PlaceholderResolver` is typically used in systems like property resolvers,
/// YAML or `.properties` processors, and templating engines to resolve
/// values like `#{host}` or `#{user.name}`.
///
/// If the placeholder cannot be resolved, this interface allows returning `null`
/// to indicate that no replacement is to be made.
///
/// ### Example
/// ```dart
/// class MapPlaceholderResolver implements PlaceholderResolver {
///   final Map<String, String> values;
///
///   MapPlaceholderResolver(this.values);
///
///   @override
///   String? resolvePlaceholder(String placeholderName) => values[placeholderName];
/// }
///
/// final resolver = MapPlaceholderResolver({'port': '8080'});
/// print(resolver.resolvePlaceholder('port')); // 8080
/// ```
/// {@endtemplate}
abstract interface class PlaceholderResolver {
  /// {@macro placeholder_resolver}

  /// Resolves the supplied [placeholderName] to its replacement value.
  ///
  /// Returns `null` if no replacement should be made.
  ///
  /// This method is typically called by a property placeholder parser or
  /// configuration string processor.
  ///
  /// - [placeholderName]: The name of the placeholder (without `#{`).
  /// - Returns: The replacement value, or `null` if unresolved.
  String? resolvePlaceholder(String placeholderName);
}

typedef PlaceholderResolverFn = String? Function(String placeholderName);

/// {@template placeholder_resolver_ext}
/// Extension to provide a method-style interface on [PlaceholderResolverFn] functions.
/// {@endtemplate}
extension PlaceholderResolverExtension on PlaceholderResolverFn {
  /// Resolves the placeholder [name] using the underlying function.
  String? resolvePlaceholder(String name) => this(name);
}