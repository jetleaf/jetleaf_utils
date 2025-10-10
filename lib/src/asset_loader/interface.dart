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

/// {@template bundler_interface}
/// Abstract interface for asset bundling operations.
/// 
/// This interface defines the contract for loading assets from packages,
/// providing a consistent API for different bundler implementations.
/// 
/// Implementations should handle:
/// - Loading assets from package resources
/// - Caching for performance optimization
/// - Error handling with appropriate exceptions
/// - Package resolution across different deployment scenarios
/// {@endtemplate}
abstract class AssetLoaderInterface {
  /// Loads an asset from the configured package as a string.
  /// 
  /// [relativePath] - Path relative to the package root
  /// 
  /// Returns the file content as a string.
  /// Throws [BundlerException] if the asset cannot be found or loaded.
  Future<String> load(String relativePath);

  /// Checks if an asset exists without loading it.
  /// 
  /// [relativePath] - Path relative to the package root
  /// 
  /// Returns true if the asset exists, false otherwise.
  Future<bool> exists(String relativePath);

  /// Clears the internal cache.
  /// 
  /// This method should be called when you want to force reload
  /// assets from disk instead of using cached versions.
  void clearCache();

  /// Gets the package root path for debugging purposes.
  /// 
  /// Returns the resolved package root directory path,
  /// or null if it cannot be determined.
  Future<String?> getPackageRoot();

  /// Gets the configured package name.
  /// 
  /// Returns the name of the package this bundler is configured for.
  String get packageName;
}