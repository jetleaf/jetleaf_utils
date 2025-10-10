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

import 'placeholder/placeholder_resolver.dart';
import 'placeholder/property_placeholder_helper.dart';

/// {@template system_property_utils}
/// Utility class for resolving `#{...}`-style placeholders within strings
/// using system properties or environment variables.
///
/// This class provides static methods to:
/// - Resolve system placeholders like `#{user.name}`
/// - Configure whether unresolved placeholders should throw or be ignored
///
/// It supports default value resolution using the colon `:` separator, and
/// escaping using the backslash `\`.
///
/// ### Example (strict resolution)
/// ```dart
/// final result = SystemPropertyUtils.resolvePlaceholders('Hello #{USER}');
/// print(result); // Throws if USER is not found
/// ```
///
/// ### Example (lenient resolution)
/// ```dart
/// final result = SystemPropertyUtils.resolvePlaceholdersWithPlaceholder(
///   'Hello #{USER:Guest}',
///   true,
/// );
/// print(result); // Hello Guest
/// ```
/// {@endtemplate}
abstract class SystemPropertyUtils {
  /// Prefix for property placeholders: `#{`
  static final String PLACEHOLDER_PREFIX = "#{";

  /// Suffix for property placeholders: `}`
  static final String PLACEHOLDER_SUFFIX = "}";

  /// Value separator for property placeholders: `:`
  static final String VALUE_SEPARATOR = ":";

  /// Escape character for property placeholders: `\`
  ///
  /// Allows escaping of prefix/suffix and separator characters.
  static final Character ESCAPE_CHARACTER = Character('\\');

  static final PropertyPlaceholderHelper _strictHelper = PropertyPlaceholderHelper.more(
    PLACEHOLDER_PREFIX,
    PLACEHOLDER_SUFFIX,
    VALUE_SEPARATOR,
    ESCAPE_CHARACTER,
    false,
  );

  static final PropertyPlaceholderHelper _nonStrictHelper = PropertyPlaceholderHelper.more(
    PLACEHOLDER_PREFIX,
    PLACEHOLDER_SUFFIX,
    VALUE_SEPARATOR,
    ESCAPE_CHARACTER,
    true,
  );

  /// {@macro system_property_utils}
  ///
  /// Resolves all `#{...}` placeholders in [text] using system properties
  /// and environment variables.
  ///
  /// This method is *strict*: if a placeholder cannot be resolved
  /// and no default value is specified, an [IllegalArgumentException]
  /// will be thrown.
  ///
  /// ### Example
  /// ```dart
  /// final result = SystemPropertyUtils.resolvePlaceholders('Hello #{USER}');
  /// ```
  static String resolvePlaceholders(String text) {
    return resolvePlaceholdersWithPlaceholder(text, false);
  }

  /// {@macro system_property_utils}
  ///
  /// Resolves all `#{...}` placeholders in [text] using system properties
  /// and environment variables.
  ///
  /// If [ignoreUnresolvablePlaceholders] is `true`, unresolved placeholders
  /// are left in place and no exception is thrown.
  ///
  /// ### Example
  /// ```dart
  /// final result = SystemPropertyUtils.resolvePlaceholdersWithPlaceholder(
  ///   'Welcome #{USER:Guest}',
  ///   true,
  /// );
  /// print(result); // e.g., 'Welcome Guest'
  /// ```
  static String resolvePlaceholdersWithPlaceholder(String text, bool ignoreUnresolvablePlaceholders) {
    if (text.isEmpty) {
      return text;
    }

    final helper = ignoreUnresolvablePlaceholders
        ? _nonStrictHelper
        : _strictHelper;

    return helper.replacePlaceholdersWithResolver(
      text,
      SystemPropertyPlaceholderResolver(text).resolvePlaceholder,
    );
  }
}

/// {@template system_property_placeholder_resolver}
/// A [PlaceholderResolver] implementation that resolves placeholders
/// using system properties and environment variables.
///
/// It first attempts to resolve the placeholder name from
/// [System.getProperty]. If not found, it then tries [System.getEnvVar].
///
/// If both fail, it returns `null` and logs the error to `System.err`.
///
/// This is useful when resolving configuration values that may be defined
/// via system-level properties or OS-level environment variables.
///
/// ### Example
/// ```dart
/// final text = 'Hello \#{USER}';
/// final resolver = SystemPropertyPlaceholderResolver(text);
/// final value = resolver.resolvePlaceholder('USER');
/// print(value); // e.g., 'francis'
/// ```
///
/// Can be used with [PropertyPlaceholderHelper] to perform substitution:
/// ```dart
/// final helper = PropertyPlaceholderHelper('\#{', '}');
/// final result = helper.replacePlaceholdersWithResolver(text, resolver.resolvePlaceholder);
/// ```
/// {@endtemplate}
class SystemPropertyPlaceholderResolver implements PlaceholderResolver {
  /// The original text being parsed. Used only for logging context.
  final String text;

  /// {@macro system_property_placeholder_resolver}
  ///
  /// Creates a resolver instance for the given placeholder-containing [text].
  SystemPropertyPlaceholderResolver(this.text);

  @override
  String? resolvePlaceholder(String placeholderName) {
    try {
      String? propVal = System.getProperty(placeholderName);
      propVal ??= System.getEnvVar(placeholderName);
      return propVal;
    } on Throwable catch (ex) {
      System.err.println("Could not resolve placeholder '$placeholderName' in [$text] as system property: $ex");
      return null;
    }
  }
}