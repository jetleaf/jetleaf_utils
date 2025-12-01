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

import 'package:test/test.dart';
import 'json_parser_test.dart' as json_tests;
import 'xml_parser_test.dart' as xml_tests;
import 'properties_parser_test.dart' as properties_tests;
import 'yaml_parser_test.dart' as yaml_tests;
import 'dart_parser_test.dart' as dart_tests;
import 'env_parser_test.dart' as env_tests;

void main() {
  group('All Parser Tests', () {
    json_tests.main();
    xml_tests.main();
    properties_tests.main();
    yaml_tests.main();
    dart_tests.main();
    env_tests.main();
  });
}