# jetleaf_utils

High-level utilities for the JetLeaf framework ecosystem. This package provides configuration parsers, placeholder resolution, string and assertion helpers, asset loading utilities, and more.

- Homepage: https://jetleaf.hapnium.com
- Repository: https://github.com/jetleaf/jetleaf_utils
- License: See `LICENSE`

## Contents
- **[Features](#features)**
- **[Install](#install)**
- **[Quick Start](#quick-start)**
- **[Usage](#usage)**
  - **[Parsers](#parsers-json-yaml-xml-properties-dart-env)**
  - **[Placeholders](#placeholders-propertyplaceholderhelper--placeholderparser)**
  - **[Asset Loading](#asset-loading-assetloader)**
  - **[Assertions](#assertions-assert)**
  - **[String Utilities](#string-utilities-stringutils)**
  - **[System Properties](#system-properties-systempropertyutils)**
  - **[Exceptions](#exceptions)**
  - **[Package Utils](#package-utils)**
- **[Testing](#testing)**
- **[Changelog](#changelog)**
- **[Contributing](#contributing)**
- **[Compatibility](#compatibility)**
- **[Security](#security)**

## Features
- **Parsers** for multiple formats: JSON, YAML, XML, `.properties`, Dart map literals, and `.env`.
- **Placeholder resolution** with `#{name}` syntax, defaults, escaping, and nesting.
- **Asset loading** from Dart packages with caching and multiple resolution strategies.
- **String helpers** and **assertion utilities** for robust runtime checks.
- **System property** placeholder resolver using environment variables.

Exports are available via `lib/utils.dart`.

## Install
Add to your `pubspec.yaml`:

```yaml
dependencies:
  jetleaf_utils:
    hosted: https://onepub.dev/api/fahnhnofly/
    version: ^1.0.0
```

Minimum SDK: Dart ^3.9.0

Import:

```dart
import 'package:jetleaf_utils/utils.dart';
```

## Quick Start
```dart
import 'package:jetleaf_utils/utils.dart';

void main() {
  // Parse JSON
  final jsonConfig = JsonParser().parse('{"host":"localhost","port":8080}');

  // Resolve placeholders
  final helper = PropertyPlaceholderHelper.more('#{', '}', ':', Character('\\'), false);
  final greeting = helper.replacePlaceholders('Hello #{name:Guest}!', {'name': 'Alice'});

  // Load an asset from a package
  final loader = AssetLoader.forPackage('jetleaf');
  // final html = await loader.load('resources/html/404.html');

  // String and assertions
  Assert.hasText(greeting, 'Greeting must not be blank');
  final cleaned = StringUtils.trimAllWhitespace('  a b  ');

  print(jsonConfig['host']);
  print(greeting);
  print(cleaned);
}
```

## Usage

### Parsers (JSON, YAML, XML, Properties, Dart, ENV)
All parsers implement `Parser` and expose `parse`, `parseAsset`, and `parseFile`.

- **JSON**: `JsonParser` (`lib/src/parsers/json_parser.dart`)

```dart
final parser = JsonParser();
final cfg = parser.parse('{"debug": true}');
// Or from file: parser.parseFile('config.json');
```

- **YAML**: `YamlParser` (`lib/src/parsers/yaml_parser.dart`)

```dart
final parser = YamlParser();
final cfg = parser.parse('host: localhost\nport: 8080');
```

- **XML**: `XmlParser` (`lib/src/parsers/xml_parser.dart`)

```dart
final parser = XmlParser();
final cfg = parser.parse('<root><child>value</child></root>');
// Access: cfg['root']['child']
```

- **Properties**: `PropertiesParser` (`lib/src/parsers/properties_parser.dart`)

```dart
final parser = PropertiesParser();
final cfg = parser.parse('host=localhost\nport=8080');
// Nested keys with dots and indices are supported
```

- **Dart map literal**: `DartParser` (`lib/src/parsers/dart_parser.dart`)

```dart
const source = 'final config = {"host":"localhost","debug":true};';
final cfg = DartParser().parse(source);
```

- **.env**: `EnvParser` (`lib/src/parsers/env_parser.dart`)

```dart
final src = 'HOST=localhost\nPASSWORD="p@ss word"';
final env = EnvParser().parse(src);
```

### Placeholders (`PropertyPlaceholderHelper` / `PlaceholderParser`)
- Use `PropertyPlaceholderHelper` for high-level replacement with maps or a resolver function.
- Grammar supports prefix/suffix (e.g., `#{`/`}`), default separator `:`, and escaping `\\`.

```dart
final helper = PropertyPlaceholderHelper.more('#{', '}', ':', Character('\\'), false);
final out = helper.replacePlaceholders('Welcome #{user:Guest}', {'user': 'Alice'});
// out: 'Welcome Alice'
```

For direct parsing/resolution, see `PlaceholderParser` in `lib/src/placeholder/placeholder_parser.dart` and `PlaceholderResolver` in `placeholder_resolver.dart`.

### Asset Loading (`AssetLoader`)
Load assets from Dart packages using multiple resolution strategies under the hood.

```dart
final jetAssets = AssetLoader.forJetLeaf();
final exists = await jetAssets.exists('resources/html/404.html');
if (exists) {
  final html = await jetAssets.load('resources/html/404.html');
}

final myAssets = AssetLoader.forPackage('my_package');
final configJson = await myAssets.load('config/settings.json');
```

See `lib/src/asset_loader/bundler.dart` and `lib/src/asset_loader/interface.dart`.

### Assertions (`Assert`)
Runtime checks that throw typed exceptions from `jetleaf_lang`.

```dart
Assert.state(user.isActive, 'User must be active');
Assert.isTrue(age > 18, 'Age must be greater than 18');
Assert.hasText(username, 'Username must not be empty');
Assert.notEmpty(items, 'Items list must not be empty');
Assert.isInstanceOf<String>(value, 'Expected a String');
```

See `lib/src/assert.dart`.

### String Utilities (`StringUtils`)
Common string helpers. See `lib/src/string_utils.dart` for the full API.

```dart
StringUtils.hasText(' h ');                 // true
StringUtils.trimAllWhitespace('  a b  ');   // 'ab'
StringUtils.countOccurrencesOf('abcabc','a'); // 2
StringUtils.cleanPath('/foo/../bar');       // '/bar'
```

### System Properties (`SystemPropertyUtils`)
Resolve `#{...}` placeholders using environment variables with strict or lenient modes.

```dart
// Strict: throws if unresolved and no default
final s1 = SystemPropertyUtils.resolvePlaceholders('Hello #{USER}');

// Lenient: keeps unresolved or uses default
final s2 = SystemPropertyUtils.resolvePlaceholdersWithPlaceholder('Hello #{USER:Guest}', true);
```

See `lib/src/system_property_utils.dart`.

### Exceptions
- `AssetLoaderException` for asset loading errors.
- `ParserException` for parse errors.
- `PlaceholderResolutionException` for placeholder issues.

See `lib/src/exceptions.dart`.

### Package Utils
Lookup a runtime `Package` by name (when available via `jetleaf_lang` runtime):

```dart
final pkg = PackageUtils.getPackage('jetleaf');
if (pkg != null) {
  // pkg.getName(), pkg.uri, etc.
}
```

See `lib/src/package_utils.dart`.

## Testing
Run tests with:

```bash
dart test
```

See `test/` for coverage of parsers and placeholders.

## Changelog
See `CHANGELOG.md`.

## Contributing
Issues and PRs are welcome at the GitHub repository.

1. Fork and create a feature branch.
2. Add tests for new functionality.
3. Run `dart test` and ensure lints pass.
4. Open a PR with a concise description and examples.

## Compatibility
- Dart SDK: `>=3.9.0 <4.0.0`
- Depends on `jetleaf_lang` and `jetleaf_logging` (see `pubspec.yaml`).

## Security
- No secrets are stored in this package.
- When loading assets, validate user-controlled paths if exposing loaders externally.
