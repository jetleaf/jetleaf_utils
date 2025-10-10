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
import 'dart:isolate';

import '../exceptions.dart';

/// {@template bundler_manager}
/// Core manager class that handles all asset bundling logic.
/// 
/// This class contains the implementation details for:
/// - Package URI resolution using multiple strategies
/// - File system operations and caching
/// - Package root detection across different deployment scenarios
/// - Error handling and recovery mechanisms
/// 
/// The manager is designed to be used by bundler implementations
/// and should not be used directly by end users.
/// {@endtemplate}
class AssetLoaderManager {
  final String _packageName;
  final Map<String, String> _cache = <String, String>{};
  String? _packageRootPath;

  /// Creates a new bundler manager for the specified package.
  /// 
  /// [packageName] - The name of the package to load assets from
  AssetLoaderManager(this._packageName);

  /// Gets the configured package name.
  String get packageName => _packageName;

  /// Loads an asset from the package using multiple resolution strategies.
  /// 
  /// [relativePath] - Path relative to the package root
  /// 
  /// Returns the file content as a string.
  /// Throws [AssetLoaderException] if the asset cannot be found.
  Future<String> loadAsset(String relativePath) async {
    // Check cache first
    if (_cache.containsKey(relativePath)) {
      return _cache[relativePath]!;
    }

    final content = await _loadFromPackage(relativePath);
    _cache[relativePath] = content;
    return content;
  }

  /// Checks if an asset exists in the package.
  /// 
  /// [relativePath] - Path relative to the package root
  /// 
  /// Returns true if the asset exists, false otherwise.
  Future<bool> assetExists(String relativePath) async {
    try {
      await _loadFromPackage(relativePath);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Clears the internal cache.
  void clearCache() {
    _cache.clear();
    _packageRootPath = null;
  }

  /// Gets the package root path.
  /// 
  /// Returns the resolved package root directory path,
  /// or null if it cannot be determined.
  Future<String?> getPackageRoot() async {
    return await _findPackageRoot();
  }

  /// Loads a file from the package using multiple resolution strategies.
  Future<String> _loadFromPackage(String relativePath) async {
    // Normalize the path
    final normalizedPath = relativePath.replaceAll('\\', '/');
    
    // Strategy 1: Try resolving via package URI (most reliable)
    try {
      final packageUri = Uri.parse('package:$_packageName/$normalizedPath');
      final resolvedUri = await Isolate.resolvePackageUri(packageUri);
      
      if (resolvedUri != null) {
        final file = File.fromUri(resolvedUri);
        if (await file.exists()) {
          return await file.readAsString();
        }
      }
    } catch (e) {
      // Continue to next strategy
    }

    // Strategy 2: Try finding package root and loading directly
    try {
      final packageRoot = await _findPackageRoot();
      if (packageRoot != null) {
        final file = File('$packageRoot/$normalizedPath');
        if (await file.exists()) {
          return await file.readAsString();
        }
      }
    } catch (e) {
      // Continue to next strategy
    }

    // Strategy 3: Try loading from current script location (development mode)
    try {
      final scriptUri = Platform.script;
      if (scriptUri.scheme == 'file') {
        final scriptPath = scriptUri.toFilePath();
        final possibleRoots = _getPossiblePackageRoots(scriptPath);
        
        for (final root in possibleRoots) {
          final file = File('$root/$normalizedPath');
          if (await file.exists()) {
            return await file.readAsString();
          }
        }
      }
    } catch (e) {
      // Continue to final error
    }

    throw AssetLoaderException('Asset not found: $relativePath', relativePath);
  }

  /// Finds the package root directory.
  Future<String?> _findPackageRoot() async {
    if (_packageRootPath != null) {
      return _packageRootPath;
    }

    // Try to resolve the package root via package URI
    try {
      final packageUri = Uri.parse('package:$_packageName/');
      final resolvedUri = await Isolate.resolvePackageUri(packageUri);
      
      if (resolvedUri != null) {
        final packagePath = resolvedUri.toFilePath();
        // Remove trailing slash and 'lib/' if present
        final rootPath = packagePath.endsWith('/lib/') 
            ? packagePath.substring(0, packagePath.length - 5)
            : packagePath.endsWith('/lib')
            ? packagePath.substring(0, packagePath.length - 4)
            : packagePath;
        
        _packageRootPath = rootPath;
        return _packageRootPath;
      }
    } catch (e) {
      // Continue with alternative methods
    }

    // Fallback: Try to find package root from current script location
    try {
      final scriptUri = Platform.script;
      if (scriptUri.scheme == 'file') {
        final scriptPath = scriptUri.toFilePath();
        final possibleRoots = _getPossiblePackageRoots(scriptPath);
        
        for (final root in possibleRoots) {
          final pubspecFile = File('$root/pubspec.yaml');
          if (await pubspecFile.exists()) {
            final content = await pubspecFile.readAsString();
            if (content.contains('name: $_packageName')) {
              _packageRootPath = root;
              return _packageRootPath;
            }
          }
        }
      }
    } catch (e) {
      // Continue
    }

    return null;
  }

  /// Gets possible package root directories based on a script path.
  List<String> _getPossiblePackageRoots(String scriptPath) {
    final possibleRoots = <String>[];
    final parts = scriptPath.split(Platform.pathSeparator);
    
    // Walk up the directory tree looking for package roots
    for (int i = parts.length - 1; i >= 0; i--) {
      final currentPath = parts.sublist(0, i + 1).join(Platform.pathSeparator);
      possibleRoots.add(currentPath);
      
      // Also check if this might be inside a .pub-cache
      if (parts[i] == '.pub-cache' && i + 4 < parts.length) {
        // Typical pub cache structure: .pub-cache/hosted/pub.dev/package-version/
        final packagePath = parts.sublist(0, i + 5).join(Platform.pathSeparator);
        possibleRoots.add(packagePath);
      }
    }
    
    return possibleRoots;
  }
}