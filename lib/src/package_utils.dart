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

/// {@template package_util}
/// Utility class for resolving and caching Dart packages at runtime.
///
/// `PackageUtils` provides static methods to locate `Package` instances
/// from the runtime, cache them for efficient access, and avoid redundant scans.
///
/// It works in combination with a runtime reflection system, where available
/// packages can be discovered via `Runtime.getAllPackages()`.
///
/// ### Example:
/// ```dart
/// final package = PackageUtils.getPackage('my_library');
/// print(package.name);
/// ```
///
/// If the package is not found during lookup, an [Exception] will be thrown.
///
/// This utility is helpful in frameworks that need to access package metadata,
/// scan classes, or perform analysis on Dart packages.
/// {@endtemplate}
abstract class PackageUtils {
  /// Internal cache of resolved packages by name.
  static final Map<String, Package> _packages = {};

  /// {@macro package_util}
  ///
  /// Returns a [Package] by its name. If the package has been previously
  /// resolved, it will be returned from the cache.
  ///
  /// If the package cannot be found in the runtime environment, this method
  /// throws an [Exception].
  ///
  /// ### Example:
  /// ```dart
  /// try {
  ///   final package = PackageUtils.getPackage('jetleaf_core');
  ///   print('Package URI: ${package.uri}');
  /// } catch (e) {
  ///   print('Package not found');
  /// }
  /// ```
  static Package? getPackage(String name) {
    if (_packages.containsKey(name)) {
      return _packages[name];
    }

    final package = Runtime.getAllPackages().firstWhereOrNull((p) => p.getName() == name);
    if (package == null) {
      return null;
    }

    return _packages[name] = package;
  }
}