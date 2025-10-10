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

import "package:jetleaf_lang/lang.dart";
import "package:meta/meta.dart";

import "placeholder_parser.dart";
import "placeholder_resolver.dart";

/// {@template property_placeholder_helper}
/// A utility class for resolving string values that contain placeholders
/// in the format `#{name}`.
///
/// The placeholder values can be substituted using either a `Map<String, String>`
/// or a custom [PlaceholderResolverFn].
///
/// ### Example
/// ```dart
/// final helper = PropertyPlaceholderHelper('\#{', '}');
/// final result = helper.replacePlaceholders('Hello \#{name}!', {'name': 'World'});
/// print(result); // Output: Hello World!
/// ```
///
/// You can also provide default values or escape characters using the
/// [PropertyPlaceholderHelper.more] constructor.
///
/// ### Advanced Example
/// ```dart
/// final helper = PropertyPlaceholderHelper.more('\#{', '}', ':', r'\', false);
/// final result = helper.replacePlaceholders('Welcome \#{user:Guest}', {});
/// print(result); // Output: Welcome Guest
/// ```
/// {@endtemplate}
class PropertyPlaceholderHelper {
  /// The internal parser that handles placeholder resolution logic.
  late final PlaceholderParser parser;

  /// {@macro property_placeholder_helper}
  ///
  /// Creates a new [PropertyPlaceholderHelper] with the given prefix and suffix.
  /// Unresolvable placeholders are ignored by default.
  ///
  /// ### Example
  /// ```dart
  /// final helper = PropertyPlaceholderHelper('\#{', '}');
  /// ```
  PropertyPlaceholderHelper(String placeholderPrefix, String placeholderSuffix)
      : this.more(placeholderPrefix, placeholderSuffix, null, null, true);

  /// {@macro property_placeholder_helper}
  ///
  /// Creates a new [PropertyPlaceholderHelper] with full configuration.
  ///
  /// - [valueSeparator] allows default values (e.g., `\#{name:default}`)
  /// - [escapeCharacter] allows placeholders to be escaped (e.g., `\\\#{name}`)
  /// - [ignoreUnresolvablePlaceholders] controls if unresolved placeholders throw an error
  ///
  /// ### Example
  /// ```dart
  /// final helper = PropertyPlaceholderHelper.more('\#{', '}', ':', r'\', false);
  /// ```
	PropertyPlaceholderHelper.more(String placeholderPrefix, String placeholderSuffix,
			String? valueSeparator, Character? escapeCharacter,
			bool ignoreUnresolvablePlaceholders) {
		parser = PlaceholderParser(placeholderPrefix, placeholderSuffix, valueSeparator, escapeCharacter, ignoreUnresolvablePlaceholders);
	}

	/// Replaces all `#{name}`-style placeholders in [value] using the given [properties] map.
  ///
  /// ### Example
  /// ```dart
  /// final result = helper.replacePlaceholders('Hello \#{user}!', {'user': 'Alice'});
  /// print(result); // Output: Hello Alice!
  /// ```
  ///
  /// If a placeholder is not found and `ignoreUnresolvablePlaceholders` is false, an error will be thrown.
	String replacePlaceholders(String value, final Map<String, String> properties) {
		return replacePlaceholdersWithResolver(value, (key) => properties[key]);
	}

	/// Replaces all `#{name}`-style placeholders in [value] using a [placeholderResolver].
  ///
  /// ### Example
  /// ```dart
  /// final result = helper.replacePlaceholdersWithResolver('Hi \#{id}', (key) => '42');
  /// print(result); // Output: Hi 42
  /// ```
  ///
  /// The [placeholderResolver] is a function that receives a key and returns its replacement string.
  String replacePlaceholdersWithResolver(String value, PlaceholderResolverFn placeholderResolver) {
		return parseStringValue(value, placeholderResolver);
	}

	@protected
  String parseStringValue(String value, PlaceholderResolverFn placeholderResolver) {
		return parser.replacePlaceholders(value, placeholderResolver);
	}
}