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

/// {@template assert}
/// A utility class that provides static assertion methods for validating
/// arguments and states in your application.
///
/// These methods help ensure that certain conditions hold true at runtime.
/// If a condition fails, an appropriate exception is thrown.
///
/// Example usage:
/// ```dart
/// Assert.notNull(user, 'User must not be null');
/// Assert.hasText(username, 'Username must not be empty');
/// Assert.isInstanceOf<String>(input, 'Expected a String input');
/// ```
///
/// Typically used in service classes, configuration validation,
/// or during framework lifecycle operations.
/// {@endtemplate}
class Assert {
  /// {@macro assert}
  Assert._();

  /// {@template assert.state}
  /// Asserts that a boolean [expression] is true.
  ///
  /// Throws a [NoGuaranteeException] with the provided [message]
  /// if the expression evaluates to false.
  ///
  /// Example:
  /// ```dart
  /// Assert.state(user.isActive, 'User must be active');
  /// ```
  /// {@endtemplate}
  static void state(bool expression, String message) {
    if (!expression) {
      throw NoGuaranteeException(message);
    }
  }

  /// {@template assert.isTrue}
  /// Asserts that a boolean [expression] is true.
  ///
  /// Throws an [InvalidArgumentException] with the given [message]
  /// if the expression evaluates to false.
  ///
  /// Example:
  /// ```dart
  /// Assert.isTrue(age > 18, 'Age must be greater than 18');
  /// ```
  /// {@endtemplate}
  static void isTrue(bool expression, String message) {
    if (!expression) {
      throw InvalidArgumentException(message);
    }
  }

  /// {@template assert.hasLength}
  /// Asserts that the given [text] is not null and not empty.
  ///
  /// Throws an [InvalidArgumentException] with the given [message]
  /// if the text is null or empty.
  ///
  /// Example:
  /// ```dart
  /// Assert.hasLength(password, 'Password cannot be empty');
  /// ```
  /// {@endtemplate}
  static void hasLength(String? text, String message) {
    if (text == null || text.isEmpty) {
      throw InvalidArgumentException(message);
    }
  }

  /// {@template assert.hasText}
  /// Asserts that the given [text] contains non-whitespace characters.
  ///
  /// Throws an [InvalidArgumentException] with the given [message]
  /// if the text is null, empty, or contains only whitespace.
  ///
  /// Example:
  /// ```dart
  /// Assert.hasText(comment, 'Comment cannot be blank');
  /// ```
  /// {@endtemplate}
  static void hasText(String? text, String message) {
    if (text == null || text.trim().isEmpty) {
      throw InvalidArgumentException(message);
    }
  }

  /// {@template assert.doesNotContain}
  /// Asserts that the given [textToSearch] does not contain the given [substring].
  ///
  /// Throws an [InvalidArgumentException] with the given [message]
  /// if the [substring] is found in [textToSearch].
  ///
  /// Example:
  /// ```dart
  /// Assert.doesNotContain(email, ' ', 'Email cannot contain spaces');
  /// ```
  /// {@endtemplate}
  static void doesNotContain(String? textToSearch, String substring, String message) {
    if (textToSearch != null && textToSearch.contains(substring)) {
      throw InvalidArgumentException(message);
    }
  }

  /// {@template assert.notEmpty}
  /// Asserts that the given [list] is not null and not empty.
  ///
  /// Throws an [InvalidArgumentException] with the given [message]
  /// if the list is null or empty.
  ///
  /// Example:
  /// ```dart
  /// Assert.notEmpty(items, 'Items list must not be empty');
  /// ```
  /// {@endtemplate}
  static void notEmpty(List? list, String message) {
    if (list == null || list.isEmpty) {
      throw InvalidArgumentException(message);
    }
  }

  /// {@template assert.notEmptyMap}
  /// Asserts that the given [map] is not null and not empty.
  ///
  /// Throws an [InvalidArgumentException] with the given [message]
  /// if the map is null or empty.
  ///
  /// Example:
  /// ```dart
  /// Assert.notEmptyMap(headers, 'Headers must not be empty');
  /// ```
  /// {@endtemplate}
  static void notEmptyMap(Map? map, String message) {
    if (map == null || map.isEmpty) {
      throw InvalidArgumentException(message);
    }
  }

  /// {@template assert.isInstanceOf}
  /// Asserts that the given [obj] is an instance of type [T].
  ///
  /// Throws an [InvalidArgumentException] with the given [message]
  /// if the object is not of the expected type.
  ///
  /// Example:
  /// ```dart
  /// Assert.isInstanceOf<String>(value, 'Expected a String');
  /// ```
  /// {@endtemplate}
  static void isInstanceOf<T>(Object? obj, String message) {
    if (obj is! T) {
      throw InvalidArgumentException(message);
    }
  }
}