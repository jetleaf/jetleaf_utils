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
import 'package:jetleaf_logging/logging.dart';
import 'package:meta/meta.dart';

import '../assert.dart';
import '../exceptions.dart';
import 'placeholder_resolver.dart';

/// {@template placeholder_parser}
/// A utility class for parsing and resolving placeholders within a string.
///
/// Supports placeholder expressions of the form:
/// ```text
/// Hello, #{user.name:Guest}! —> // Output: Hello, Alice! if user.name resolves to "Alice"
///     or "Hello, Guest!" if it does not.
/// ```
///
/// Supports nested placeholders and fallback values:
/// ```text
/// #{app.title:#{default.title:MyApp}}
/// ```
///
/// Example usage:
/// ```dart
/// final parser = PlaceholderParser(r'#{', '}', ':', r'\', false);
/// final result = parser.replacePlaceholders('Welcome #{user.name:Guest}', MyResolver());
/// print(result); // Welcome Alice or Welcome Guest
/// ```
///
/// You can control:
/// - Prefix/suffix (e.g., `#{...}` or `[[...]]`)
/// - Escape characters (e.g., `\#{...}` to skip parsing)
/// - Fallback separator (e.g., `:` or `|`)
/// - Whether to ignore unresolvable placeholders
///
/// {@endtemplate}
final class PlaceholderParser {
  static final Log logger = LogFactory.getLog(PlaceholderParser);

  static final Map<String, String> wellKnownSimplePrefixes = {
    '}': '{',
    ']': '[',
    ')': '(',
  };

  late String _simplePrefix;

  final String _prefix;

	final String _suffix;

	final String? _separator;

	final bool _ignoreUnresolvablePlaceholders;

	final Character? _escape;

  /// {@macro placeholder_parser}
  PlaceholderParser(
    this._prefix,
    this._suffix,
    this._separator,
    this._escape,
    this._ignoreUnresolvablePlaceholders,
  ) {
    String? simplePrefixForSuffix = wellKnownSimplePrefixes[_suffix];
    if (simplePrefixForSuffix != null && _prefix.endsWith(simplePrefixForSuffix)) {
      _simplePrefix = simplePrefixForSuffix;
    } else {
      _simplePrefix = _prefix;
    }
  }

  /// {@template placeholder_parser_replace_placeholders}
  /// Replaces all placeholders in the given [value] using the provided [placeholderResolver].
  ///
  /// This will parse the [value], resolve all placeholders recursively using
  /// [placeholderResolver], and return the fully interpolated string.
  ///
  /// If a placeholder cannot be resolved:
  /// - It uses the fallback (if provided)
  /// - Or throws an error unless configured to ignore unresolvable placeholders
  ///
  /// Example:
  /// ```dart
  /// final parser = PlaceholderParser(r'#{', '}', ':', null, false);
  /// final result = parser.replacePlaceholders('Hi #{name:User}', MyResolver());
  /// print(result); // Hi Alice or Hi User
  /// ```
  /// {@endtemplate}
  String replacePlaceholders(String value, PlaceholderResolverFn placeholderResolver) {
    PlaceholderParsedValue parsedValue = parse(value);
    PlaceholderPartResolutionContext resolutionContext = PlaceholderPartResolutionContext(
      placeholderResolver,
      _prefix,
      _suffix,
      _ignoreUnresolvablePlaceholders,
      (candidate) => _parseWithPlaceholder(candidate, false),
      logger,
    );
    return parsedValue.resolve(resolutionContext);
  }

  /// {@template placeholder_parser_parse}
  /// Parses the given [value] into a [PlaceholderParsedValue] structure without resolving it.
  ///
  /// This method breaks the string into a list of `Part`s (text and placeholders),
  /// but does not attempt to resolve them.
  ///
  /// Useful if you need to inspect the structure of a string before resolving it.
  /// {@endtemplate}
  PlaceholderParsedValue parse(String value) {
    List<PlaceholderPart> parts = _parseWithPlaceholder(value, false);
    return PlaceholderParsedValue(value, parts);
  }

  List<PlaceholderPart> _parseWithPlaceholder(String value, bool inPlaceholder) {
		LinkedList<PlaceholderPart> parts = LinkedList();

		int startIndex = _nextStartPrefix(value, 0);
		if (startIndex == -1) {
			PlaceholderPart part = (inPlaceholder ? createSimplePlaceholderPart(value) : PlaceholderTextPart(value));
			parts.add(part);
			return parts;
		}
		int position = 0;
		while (startIndex != -1) {
			int endIndex = _nextValidEndPrefix(value, startIndex);
			if (endIndex == -1) { // Not a valid placeholder, consume the prefix and continue
				_addText(value, position, startIndex + _prefix.length, parts);
				position = startIndex + _prefix.length;
				startIndex = _nextStartPrefix(value, position);
			} else if (_isEscaped(value, startIndex)) { // Not a valid index, accumulate and skip the escape character
				_addText(value, position, startIndex - 1, parts);
				_addText(value, startIndex, startIndex + _prefix.length, parts);
				position = startIndex + _prefix.length;
				startIndex = _nextStartPrefix(value, position);
			} else { // Found valid placeholder, recursive parsing
				_addText(value, position, startIndex, parts);
				String placeholder = value.substring(startIndex + _prefix.length, endIndex);
				List<PlaceholderPart> placeholderParts = _parseWithPlaceholder(placeholder, true);
				parts.addAll(placeholderParts);
				startIndex = _nextStartPrefix(value, endIndex + _suffix.length);
				position = endIndex + _suffix.length;
			}
		}
		// Add rest of text if necessary
		_addText(value, position, value.length, parts);
		return (inPlaceholder ? List.of([_createNestedPlaceholderPart(value, parts)]) : parts);
	}

  SimplePlaceholderPart createSimplePlaceholderPart(String text) {
		PlaceholderParsedSection section = _parseSection(text);
		return SimplePlaceholderPart(text, section.key, section.fallback);
	}

  NestedPlaceholderPart _createNestedPlaceholderPart(String text, List<PlaceholderPart> parts) {
		if (_separator == null) {
			return NestedPlaceholderPart(text, parts, null);
		}
		List<PlaceholderPart> keyParts = ArrayList<PlaceholderPart>();
		List<PlaceholderPart> defaultParts = ArrayList<PlaceholderPart>();
		for (int i = 0; i < parts.length; i++) {
			PlaceholderPart part = parts.get(i);
			if (part is! PlaceholderTextPart) {
				keyParts.add(part);
			}
			else {
				String candidate = part.text();
				PlaceholderParsedSection section = _parseSection(candidate);
				keyParts.add(PlaceholderTextPart(section.key));
				if (section.fallback != null) {
					defaultParts.add(PlaceholderTextPart(section.fallback!));
					defaultParts.addAll(parts.sublist(i + 1, parts.length));
					return NestedPlaceholderPart(text, keyParts, defaultParts);
				}
			}
		}
		return NestedPlaceholderPart(text, keyParts, null);
	}

  PlaceholderParsedSection _parseSection(String value) {
		if (_separator == null || !value.contains(_separator)) {
			return PlaceholderParsedSection(value, null);
		}

		int position = 0;
		int index = value.indexOf(_separator, position);
		StringBuilder buffer = StringBuilder();
		while (index != -1) {
			if (_isEscaped(value, index)) {
				// Accumulate, without the escape character.
				buffer.append(value.substring(position, index - 1));
				buffer.append(value.substring(index, index + _separator.length));
				position = index + _separator.length;
				index = value.indexOf(_separator, position);
			}
			else {
				buffer.append(value.substring(position, index));
				String key = buffer.toString();
				String fallback = value.substring(index + _separator.length);
				return PlaceholderParsedSection(key, fallback);
			}
		}
		buffer.append(value.substring(position));
		return PlaceholderParsedSection(buffer.toString(), null);
	}

  static void _addText(String value, int start, int end, LinkedList<PlaceholderPart> parts) {
		if (start > end) {
			return;
		}

		String text = value.substring(start, end);
		if (text.isNotEmpty) {
			if (parts.isNotEmpty) {
				PlaceholderPart current = parts.removeLast();
				if (current is PlaceholderTextPart) {
					parts.add(PlaceholderTextPart(current.text() + text));
				}
				else {
					parts.add(current);
					parts.add(PlaceholderTextPart(text));
				}
			}
			else {
				parts.add(PlaceholderTextPart(text));
			}
		}
	}

  int _nextStartPrefix(String value, int index) {
		return value.indexOf(_prefix, index);
	}

  int _nextValidEndPrefix(String value, int startIndex) {
		int index = startIndex + _prefix.length;
		int withinNestedPlaceholder = 0;
		while (index < value.length) {
			if (_substringMatch(value, index, _suffix)) {
				if (withinNestedPlaceholder > 0) {
					withinNestedPlaceholder--;
					index = index + _suffix.length;
				}
				else {
					return index;
				}
			}
			else if (_substringMatch(value, index, _simplePrefix)) {
				withinNestedPlaceholder++;
				index = index + _simplePrefix.length;
			}
			else {
				index++;
			}
		}
		return -1;
	}

  bool _isEscaped(String value, int index) {
		return (_escape != null && index > 0 && Character(value[index - 1]) == _escape);
	}

  /// Checks if [value] has [substr] starting at [index]
  bool _substringMatch(String value, int index, String substr) {
    if (index + substr.length > value.length) return false;
    return value.substring(index, index + substr.length) == substr;
  }
}

/// {@template nested_placeholder_part}
/// A [PlaceholderPart] that represents a nested placeholder expression with optional fallback.
///
/// This is used to represent placeholders whose keys or fallbacks themselves contain
/// inner placeholder expressions, such as:
///
/// ```text
/// #{#{env:dev.name}:#{default.value}}
/// ```
///
/// In this example:
/// - `keyParts` would resolve `#{env:dev.name}`
/// - `defaultParts` would resolve `#{default.value}`
///
/// The resolution process:
/// 1. Resolves `keyParts` to get the final key.
/// 2. Tries to resolve that key using [resolveRecursively].
/// 3. If unresolved, tries `defaultParts` if provided.
/// 4. If still unresolved, delegates to
///    [PlaceholderPartResolutionContext.handleUnresolvablePlaceholder].
///
/// This allows for recursive resolution and fallback substitution,
/// enabling powerful and composable placeholder configurations.
///
/// {@endtemplate}
class NestedPlaceholderPart extends PlaceholderAbstractPart {
  /// The parts that make up the dynamic key of the placeholder.
  ///
  /// For example, for `#{#{env}.name}`, this would contain parts for `#{env}` and `.name`.
  final List<PlaceholderPart> keyParts;

  /// The optional parts that make up the default/fallback value of the placeholder.
  ///
  /// This is used when the main key cannot be resolved.
  final List<PlaceholderPart>? defaultParts;

  /// {@macro nested_placeholder_part}
  ///
  /// Constructs a new [NestedPlaceholderPart] with the given [text],
  /// [keyParts], and optional [defaultParts].
  NestedPlaceholderPart(super.text, this.keyParts, this.defaultParts);

  @override
  String resolve(PlaceholderPartResolutionContext resolutionContext) {
    String resolvedKey = PlaceholderPart.resolveAll(keyParts, resolutionContext);
    String? value = resolveRecursively(resolutionContext, resolvedKey);
    if (value != null) {
      return value;
    } else if (defaultParts != null) {
      return PlaceholderPart.resolveAll(defaultParts!, resolutionContext);
    }
    return resolutionContext.handleUnresolvablePlaceholder(resolvedKey, text());
  }
}

/// {@template abstract_part}
/// Base class for all [PlaceholderPart] implementations that represent a segment
/// of a parsed placeholder expression.
///
/// This class provides common functionality for handling the raw text
/// of the part and recursive resolution of nested placeholders.
///
/// Concrete subclasses (e.g., [PlaceholderTextPart], [PlaceholderPart]) must
/// implement resolution behavior by overriding `resolve(...)`.
///
/// Example:
/// ```dart
/// class PlaceholderPart extends AbstractPart {
///   final String key;
///
///   PlaceholderPart(this.key) : super('\#{#key}');
///
///   @override
///   String resolve(PartResolutionContext ctx) {
///     return resolveRecursively(ctx, key) ?? ctx.handleUnresolvablePlaceholder(key, text());
///   }
/// }
/// ```
///
/// This class should not be used directly—extend it to define custom parts.
/// {@endtemplate}
abstract class PlaceholderAbstractPart implements PlaceholderPart {
  /// The raw placeholder or literal text this part represents.
  final String _text;

  /// {@macro abstract_part}
  const PlaceholderAbstractPart(this._text);

  @override
  String text() => _text;

  /// Recursively resolves the placeholder identified by [key] using the provided [resolutionContext].
  ///
  /// This method performs the following:
  /// - Calls `resolvePlaceholder(key)` to get a value.
  /// - If a value exists, it flags the placeholder as visited.
  /// - It parses the resolved value into nested parts.
  /// - If those parts are not just plain text (i.e., contain other placeholders),
  ///   it delegates resolution to [PlaceholderParsedValue.resolve].
  /// - Finally, it removes the placeholder from the visited list to avoid circular references.
  ///
  /// If no value is found, it returns `null`.
  ///
  /// Throws [PlaceholderResolutionException] if circular reference is detected.
  @protected
  String? resolveRecursively(PlaceholderPartResolutionContext resolutionContext, String key) {
    String? resolvedValue = resolutionContext.resolvePlaceholder(key);
    if (resolvedValue != null) {
      resolutionContext.flagPlaceholderAsVisited(key);

      List<PlaceholderPart> nestedParts = resolutionContext.parse(resolvedValue);
      String value = _toText(nestedParts);

      if (!_isTextOnly(nestedParts)) {
        value = PlaceholderParsedValue(resolvedValue, nestedParts).resolve(resolutionContext);
      }

      resolutionContext.removePlaceholder(key);
      return value;
    }

    return null;
  }

  /// Returns `true` if all parts are of type [PlaceholderTextPart], meaning no further resolution is needed.
  bool _isTextOnly(List<PlaceholderPart> parts) {
    return parts.stream().allMatch((part) => part is PlaceholderTextPart);
  }

  /// Joins the text of all parts into a single string.
  String _toText(List<PlaceholderPart> parts) {
    StringBuilder sb = StringBuilder();
    for (PlaceholderPart part in parts) {
      sb.append(part.text());
    }
    return sb.toString();
  }
}

/// {@template parsed_section}
/// Represents a parsed section of a placeholder string,
/// typically extracted from a raw placeholder like `#{key:default}`.
///
/// This class holds:
/// - The **key** part (e.g., `key`)
/// - The **fallback** part if present (e.g., `default`)
///
/// It is used during placeholder parsing to distinguish between the
/// key to be resolved and the fallback value to use when resolution fails.
///
/// Example:
/// ```text
/// #{app.name:MyApp}
/// ```
/// would be parsed into:
/// ```dart
/// ParsedSection('app.name', 'MyApp');
/// ```
///
/// This class is used internally during placeholder analysis and decomposition,
/// and is not meant to be exposed to end users directly.
///
/// {@endtemplate}
class PlaceholderParsedSection {
  /// The placeholder key (e.g., `app.name`).
  final String key;

  /// The optional fallback value (e.g., `MyApp`).
  final String? fallback;

  /// {@macro parsed_section}
  PlaceholderParsedSection(this.key, this.fallback);
}

/// {@template parsed_value}
/// A container for a parsed text and its constituent `Part` objects.
///
/// This class holds the original placeholder expression (`text`) and the
/// parsed structure (`parts`) used to resolve dynamic placeholders in text.
///
/// You typically obtain a `ParsedValue` when parsing a template-like string
/// with placeholders, such as:
///
/// ```dart
/// final parsedValue = ParsedValue('\#{greeting}, \#{user}!', [
///   LiteralPart(''),
///   PlaceholderPart('greeting'),
///   LiteralPart(', '),
///   PlaceholderPart('user'),
///   LiteralPart('!')
/// ]);
///
/// final resolved = parsedValue.resolve(context); // e.g. 'Hello, Alice!'
/// ```
///
/// It delegates the resolution of each part to the [PlaceholderPart.resolveAll] method and
/// rethrows any `PlaceholderResolutionException` with additional context about
/// the original unresolved value.
///
/// This class is commonly used internally by the placeholder resolution engine.
/// {@endtemplate}
class PlaceholderParsedValue {
  /// The original raw text, including unresolved placeholders.
  final String text;

  /// The parsed components (literal and placeholder parts) that make up the text.
  final List<PlaceholderPart> parts;

  /// {@macro parsed_value}
  PlaceholderParsedValue(this.text, this.parts);

  /// Resolves all parts into a single string using the provided [resolutionContext].
  ///
  /// This method iterates through all the [parts] and delegates resolution to
  /// each part using [PlaceholderPart.resolveAll]. If a `PlaceholderResolutionException`
  /// occurs, it rethrows the exception with the unresolved [text] attached for context.
  ///
  /// Example:
  /// ```dart
  /// final value = ParsedValue('Hello, \#{user}!', [...]);
  /// final result = value.resolve(context); // Resolves to 'Hello, Alice!'
  /// ```
  ///
  /// Throws [PlaceholderResolutionException] if any placeholder could not be resolved.
  String resolve(PlaceholderPartResolutionContext resolutionContext) {
    try {
      return PlaceholderPart.resolveAll(parts, resolutionContext);
    } on PlaceholderResolutionException catch (ex) {
      throw ex.withValue(text);
    }
  }
}

/// {@template part_resolution_context}
/// A resolution context for placeholder expressions, providing configuration,
/// resolution logic, and tracking for visited placeholders.
///
/// This context is passed to [PlaceholderPart]s during resolution, giving them access to:
/// - the [PlaceholderResolver] to use
/// - the placeholder [prefix] and [suffix]
/// - whether to [ignoreUnresolvablePlaceholders]
/// - a [parser] to break down text into parts
/// - a [logger] for tracing
/// - a [visitedPlaceholders] set to detect circular references
///
/// It is a central piece of the placeholder resolution engine.
/// {@endtemplate}
class PlaceholderPartResolutionContext implements PlaceholderResolver {
  /// The placeholder prefix (e.g. `#{`).
  final String prefix;

  /// The placeholder suffix (e.g. `}`).
  final String suffix;

  /// Whether to ignore unresolvable placeholders and leave them as-is.
  final bool ignoreUnresolvablePlaceholders;

  /// A function that parses raw text into [PlaceholderPart]s.
  final List<PlaceholderPart> Function(String) parser;

  /// The underlying resolver used to resolve individual placeholder values.
  final PlaceholderResolverFn resolver;

  /// Set of placeholders that have already been visited (for circular reference detection).
  Set<String>? visitedPlaceholders;

  /// Logger used for resolution tracing.
  final Log logger;

  /// {@macro part_resolution_context}
  PlaceholderPartResolutionContext(
    this.resolver,
    this.prefix,
    this.suffix,
    this.ignoreUnresolvablePlaceholders,
    this.parser,
    this.logger,
  );

  @override
  String? resolvePlaceholder(String placeholderName) {
    String? value = resolver.resolvePlaceholder(placeholderName);
    if (value != null && logger.getIsTraceEnabled()) {
      logger.trace("Resolved placeholder '$placeholderName'");
    }
    return value;
  }

  /// {@template part_resolution_handle_unresolvable}
  /// Handles what to do when a placeholder cannot be resolved.
  ///
  /// If [ignoreUnresolvablePlaceholders] is `true`, returns the unresolved
  /// placeholder in its original placeholder format.
  ///
  /// Otherwise, throws a [PlaceholderResolutionException].
  /// {@endtemplate}
  String handleUnresolvablePlaceholder(String key, String text) {
    if (ignoreUnresolvablePlaceholders) {
      return toPlaceholderText(key);
    }
    String? originalValue = (!key.equals(text) ? toPlaceholderText(text) : null);
    throw PlaceholderResolutionException("Could not resolve placeholder '%s'".formatted(key), key, originalValue);
  }

  /// {@template part_resolution_to_placeholder_text}
  /// Reconstructs a placeholder expression from the [text] using the context’s
  /// [prefix] and [suffix].
  ///
  /// ```dart
  /// ctx.toPlaceholderText('host') // -> "#{host}"
  /// ```
  /// {@endtemplate}
  String toPlaceholderText(String text) => prefix + text + suffix;

  /// {@template part_resolution_parse}
  /// Parses the given [text] into a list of [PlaceholderPart]s using the context’s [parser].
  ///
  /// ```dart
  /// ctx.parse('host') // -> [TextPart('host')]
  /// ```
  /// {@endtemplate}
  List<PlaceholderPart> parse(String text) => parser(text);

  /// {@template part_resolution_flag_placeholder_as_visited}
  /// Marks the given [placeholder] as visited to detect circular references.
  ///
  /// If the placeholder is already visited, throws a [PlaceholderResolutionException].
  /// {@endtemplate}
  void flagPlaceholderAsVisited(String placeholder) {
    visitedPlaceholders ??= <String>{};

    if (!visitedPlaceholders!.add(placeholder)) {
      throw PlaceholderResolutionException("Circular placeholder reference '%s'".formatted(placeholder), placeholder, null);
    }
  }

  /// {@template part_resolution_remove_placeholder}
  /// Removes the given [placeholder] from the visited placeholders set.
  ///
  /// This is typically used when a placeholder is resolved successfully.
  /// {@endtemplate}
  void removePlaceholder(String placeholder) {
    Assert.state(visitedPlaceholders != null, "Visited placeholders must not be null");
    visitedPlaceholders!.remove(placeholder);
  }
}

/// {@template part_interface}
/// Represents a segment or fragment of a placeholder expression.
///
/// A `Part` is a building block used during placeholder parsing and resolution.
/// It may represent literal text or a placeholder that must be resolved using a
/// [`PartResolutionContext`].
///
/// This interface is used by the placeholder parsing engine to build a list of
/// `Part`s which can then be resolved dynamically during runtime.
///
/// You typically do not implement this directly unless building a custom
/// placeholder parser or resolver engine.
///
/// ### Example usage
///
/// ```dart
/// final context = MyPartResolutionContext(); // Your custom implementation
/// final parts = <Part>[...]; // Populated from parsing
/// final resolved = Part.resolveAll(parts, context);
/// print(resolved); // Prints the fully resolved placeholder string
/// ```
/// {@endtemplate}
abstract interface class PlaceholderPart {
  /// {@macro part_interface}

  /// {@template part_resolve}
  /// Resolves this part using the given [resolutionContext].
  ///
  /// The implementation will determine how to transform this part into
  /// a final string result. For example, a placeholder part would extract
  /// its value from the context, while a literal part would return itself.
  ///
  /// ### Example
  /// ```dart
  /// part.resolve(context); // -> "resolved value"
  /// ```
  /// {@endtemplate}
  String resolve(PlaceholderPartResolutionContext resolutionContext);

  /// {@template part_text}
  /// Returns the raw textual representation of this part.
  ///
  /// This is the unprocessed form of the part. For literal text, it's the
  /// actual string; for placeholder parts, it's the placeholder name.
  ///
  /// ### Example
  /// ```dart
  /// final text = part.text(); // "host", or "${host}"
  /// ```
  /// {@endtemplate}
  String text();

  /// {@template part_resolve_all}
  /// Resolves and concatenates all [parts] using the given [resolutionContext].
  ///
  /// This utility method allows a list of `Part`s to be resolved into a
  /// single final string with all placeholders or text fragments merged.
  ///
  /// ### Example
  /// ```dart
  /// final result = Part.resolveAll(parts, context);
  /// print(result); // "http://localhost:8080"
  /// ```
  ///
  /// It internally uses [resolve] on each [PlaceholderPart] and builds the full result.
  /// {@endtemplate}
  static String resolveAll(Iterable<PlaceholderPart> parts, PlaceholderPartResolutionContext resolutionContext) {
    StringBuilder sb = StringBuilder();
    for (PlaceholderPart part in parts) {
      sb.append(part.resolve(resolutionContext));
    }
    return sb.toString();
  }
}

/// {@template text_part}
/// A [PlaceholderPart] implementation that represents literal, already-resolved text within a placeholder expression.
///
/// `TextPart` is used for static text segments that require no further processing or resolution.
///
/// These parts are returned as-is during placeholder resolution. They typically appear in expressions like:
///
/// ```dart
/// final part = TextPart('hello');
/// print(part.resolve(context)); // prints 'hello'
/// ```
///
/// This class extends [PlaceholderAbstractPart] and simply returns the original text when resolved.
/// {@endtemplate}
class PlaceholderTextPart extends PlaceholderAbstractPart {
  /// {@macro text_part}
  ///
  /// Creates a new [PlaceholderTextPart] with the given static [text].
  ///
  /// Example:
  /// ```dart
  /// var part = TextPart('static');
  /// print(part.text()); // 'static'
  /// ```
  PlaceholderTextPart(super.text);

  @override
  String resolve(PlaceholderPartResolutionContext resolutionContext) => text();
}

/// {@template simple_placeholder_part}
/// A [PlaceholderPart] that represents a basic placeholder expression with an optional fallback.
///
/// This class is used to resolve expressions like `#{name}` or `#{name:defaultValue}`
/// where `name` is the key to resolve, and `defaultValue` is an optional fallback.
///
/// Example usage:
/// ```dart
/// var part = SimplePlaceholderPart(r'#{user}', 'user', null);
/// var result = part.resolve(context); // resolved value or throws
/// ```
///
/// The resolution process attempts the following:
/// 1. Tries to resolve the full `text()` (e.g., `#{user}`) recursively.
/// 2. If unsuccessful, tries to resolve just the `key` (e.g., `user`).
/// 3. If still unresolved, uses the `fallback` if provided.
/// 4. Otherwise, it calls [PlaceholderPartResolutionContext.handleUnresolvablePlaceholder].
///
/// This class extends [PlaceholderAbstractPart], which provides shared recursive resolution logic.
/// {@endtemplate}
class SimplePlaceholderPart extends PlaceholderAbstractPart {
  /// The raw key of the placeholder (e.g., `user` in `#{user}`).
  final String key;

  /// An optional fallback value to use if the placeholder cannot be resolved.
  final String? fallback;

  /// {@macro simple_placeholder_part}
  ///
  /// Constructs a new [SimplePlaceholderPart] with the original [text],
  /// [key], and optional [fallback] value.
  SimplePlaceholderPart(super.text, this.key, this.fallback);

  @override
  String resolve(PlaceholderPartResolutionContext resolutionContext) {
    String? value = _resolveRecursively(resolutionContext);
    if (value != null) {
      return value;
    } else if (fallback != null) {
      return fallback!;
    }
    return resolutionContext.handleUnresolvablePlaceholder(key, text());
  }

  /// Internal helper that handles recursive resolution logic.
  ///
  /// It first attempts to resolve [text()] if it differs from the raw [key].
  /// Then, it attempts to resolve the [key] directly.
  String? _resolveRecursively(PlaceholderPartResolutionContext resolutionContext) {
    if (!text().equals(key)) {
      String? value = resolveRecursively(resolutionContext, text());
      if (value != null) {
        return value;
      }
    }
    return resolveRecursively(resolutionContext, key);
  }
}