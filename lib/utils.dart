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

/// 🧩 **JetLeaf Utilities Library**
///
/// This library provides a collection of general-purpose utilities for
/// JetLeaf applications, including:
/// - placeholder resolution
/// - configuration file parsing (JSON, YAML, XML, Dart, env, properties)
/// - stack trace parsing and mapping
/// - string, package, and system property helpers
///
/// It is designed to streamline common framework-level operations and
/// provide a consistent set of tools for application development.
///
///
/// ## 🔑 Key Concepts
///
/// ### 🔧 Placeholder Resolution
/// - `PlaceholderParser` — parses placeholders in strings (e.g., `${value}`)  
/// - `PlaceholderResolver` — resolves placeholders to actual values  
/// - `PropertyPlaceholderHelper` — utility methods for working with placeholders
///
///
/// ### 📄 Configuration File Parsers
/// Support multiple file formats for configuration:
/// - `JsonParser` — parses JSON configuration  
/// - `YamlParser` — parses YAML configuration  
/// - `XmlParser` — parses XML configuration  
/// - `PropertiesParser` — parses `.properties` files  
/// - `DartParser` — parses Dart code as configuration  
/// - `EnvParser` — parses environment variables  
/// - `Parser` — base interface for custom parsers
///
///
/// ### 🧾 Stack Trace Parsing
/// - `StackTraceParser` — parses raw stack traces  
/// - `TraceFrame` — represents a single frame in the stack trace  
/// - `TraceMapping` — maps frames for better readability
///
/// Useful for debugging, logging, and error reporting.
///
///
/// ### 🛠 General Utilities
/// - `assert.dart` — extended assertion helpers  
/// - `exceptions.dart` — common exception types  
/// - `package_utils.dart` — helpers for package management  
/// - `string_utils.dart` — string manipulation utilities  
/// - `system_property_utils.dart` — helpers for accessing system properties
///
///
/// ## 🎯 Intended Usage
///
/// Import this library when you need:
/// - robust placeholder resolution  
/// - configuration parsing from multiple formats  
/// - stack trace analysis and formatting  
/// - helper utilities for strings, packages, and system properties
///
/// Example:
/// ```dart
/// import 'package:jetleaf_utils/utils.dart';
///
/// final parser = JsonParser();
/// final config = parser.parse(jsonString);
///
/// final resolved = PropertyPlaceholderHelper.replacePlaceholders(
///   'Hello ${name}', {'name': 'JetLeaf'}
/// );
/// ```
///
///
/// © 2025 Hapnium & JetLeaf Contributors
library;

export 'src/placeholder/placeholder_parser.dart';
export 'src/placeholder/placeholder_resolver.dart';
export 'src/placeholder/property_placeholder_helper.dart';

export 'src/parsers/json_parser.dart';
export 'src/parsers/xml_parser.dart';
export 'src/parsers/properties_parser.dart';
export 'src/parsers/yaml_parser.dart';
export 'src/parsers/dart_parser.dart';
export 'src/parsers/env_parser.dart';
export 'src/parsers/parser.dart';

export 'src/stack_trace/stack_trace_parser.dart';
export 'src/stack_trace/trace_frame.dart';
export 'src/stack_trace/trace_mapping.dart';

export 'src/exceptions.dart';
export 'src/assert.dart';
export 'src/package_utils.dart';
export 'src/string_utils.dart';
export 'src/system_property_utils.dart';