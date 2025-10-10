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

import 'interface.dart';
import '_bundler.dart';
import '../exceptions.dart';

/// {@template jet_asset_bundler}
/// A configurable asset bundler for loading files from Dart packages.
/// 
/// This bundler can be configured to load assets from any Dart package,
/// making it flexible for different use cases. It provides a clean API
/// for loading package assets with proper error handling and caching.
/// 
/// Example usage:
/// ```dart
/// // For JetLeaf package
/// final jetAssetLoader = AssetLoader.forJetLeaf();
/// final html = await jetAssetLoader.load('resources/html/404.html');
/// 
/// // For custom package
/// final myAssetLoader = AssetLoader.forPackage('my_package');
/// final config = await myAssetLoader.load('config/settings.json');
/// ```
/// {@endtemplate}
class AssetLoader implements AssetLoaderInterface {
  final AssetLoaderManager _manager;

  /// Creates a new asset bundler for the specified package.
  /// 
  /// [packageName] - The name of the package to load assets from
  AssetLoader._(this._manager);

  /// Creates a new asset bundler for the specified package.
  /// 
  /// [packageName] - The name of the package to load assets from
  /// 
  /// Returns a configured [AssetLoader] instance.
  factory AssetLoader.forPackage(String packageName) {
    final manager = AssetLoaderManager(packageName);
    return AssetLoader._(manager);
  }

  /// Creates a new asset bundler specifically for the JetLeaf package.
  /// 
  /// This is a convenience factory for the most common use case.
  /// 
  /// Returns a [AssetLoader] configured for the 'jetleaf' package.
  factory AssetLoader.forJetLeaf() {
    return AssetLoader.forPackage('jetleaf');
  }

  @override
  Future<String> load(String relativePath) async {
    try {
      return await _manager.loadAsset(relativePath);
    } catch (e) {
      throw AssetLoaderException('Failed to load asset: $relativePath', relativePath, cause: e);
    }
  }

  @override
  Future<bool> exists(String relativePath) async {
    try {
      return await _manager.assetExists(relativePath);
    } catch (e) {
      return false;
    }
  }

  @override
  void clearCache() {
    _manager.clearCache();
  }

  @override
  Future<String?> getPackageRoot() async {
    return await _manager.getPackageRoot();
  }

  @override
  String get packageName => _manager.packageName;
}

/// {@template jetleaf_leaf_bundler}
/// The default asset bundler used by JetLeaf to load internal framework assets.
///
/// This is typically used to resolve HTML templates, static files, and other
/// bundled resources that are shipped with JetLeaf itself.
///
/// It uses the `Platform.script` or similar runtime metadata to locate
/// assets relative to the JetLeaf package.
///
/// Example:
/// ```dart
/// final html = await jetLeafAssetLoader.loadAsString('errors/404.html');
/// ```
/// {@endtemplate}
final AssetLoaderInterface jetLeafAssetLoader = AssetLoader.forJetLeaf();

/// {@template jetleaf_root_bundler}
/// Creates an asset bundler for a user-defined package.
///
/// This allows you to load assets (e.g. templates, partials, config files)
/// from your own project's `lib/`, `assets/`, or other accessible folders
/// using the package's declared name.
///
/// [packageName] must match the name defined in your `pubspec.yaml`.
///
/// Example:
/// ```dart
/// final assetLoader = rootAssetLoader('my_app');
/// final template = await assetLoader.loadAsString('templates/welcome.html');
/// ```
///
/// Throws a [AssetLoaderException] if the asset cannot be located or loaded.
/// {@endtemplate}
///
/// - [packageName]: The name of the Dart package to resolve assets from.
/// - Returns a [AssetLoaderInterface] for loading assets in that package.
AssetLoaderInterface rootAssetLoader(String packageName) => AssetLoader.forPackage(packageName);