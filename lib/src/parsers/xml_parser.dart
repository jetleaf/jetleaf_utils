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

import 'parser.dart';
import '../exceptions.dart';

/// {@template xml_parser}
/// A parser for XML configuration files.
/// 
/// Converts XML elements to nested maps, with attributes prefixed by '@'
/// and text content stored under '#text'. Preserves special property values
/// like #{} and @{} for later resolution.
/// 
/// ### Example usage:
/// ```dart
/// void main() {
///   final parser = XmlParser();
/// 
///   final config = parser.parse('<root><child>value</child></root>');
///   print(config['root']['child']); // Output: value
/// 
///   final config = parser.parseAsset(asset);
///   print(config['root']['child']); // Output: value
/// 
///   final config = parser.parseFile('config.xml');
///   print(config['root']['child']); // Output: value
/// }
/// ```
/// {@endtemplate}
class XmlParser extends Parser {
  /// {@macro xml_parser}
  XmlParser();

  @override
  Map<String, dynamic> parse(String source) {
    try {
      final root = _parseRootElement(source.trim());
      return root;
    } catch (e) {
      throw ParserException('Failed to parse XML: $e');
    }
  }

  // ---- Root ---------------------------------------------------------------

  /// {@template xml_parser_parse_root_element}
  /// Parses the root element of the given XML string.
  /// 
  /// {@endtemplate}
  Map<String, dynamic> _parseRootElement(String xml) {
    if (xml.isEmpty) return {};
    xml = _removeComments(xml);
    xml = _removeXmlDeclaration(xml);
    xml = xml.trim();
    if (xml.isEmpty) return {};

    final parsed = _parseElement(xml);
    return {parsed['tagName'] as String: parsed['content']};
  }

  /// {@template xml_parser_remove_comments}
  /// Removes XML comments from the given XML string.
  /// 
  /// {@endtemplate}
  String _removeComments(String xml) => xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

  /// {@template xml_parser_remove_xml_declaration}
  /// Removes the XML declaration from the given XML string.
  /// 
  /// {@endtemplate}
  String _removeXmlDeclaration(String xml) => xml.replaceAll(RegExp(r'<\?xml.*?\?>', dotAll: true), '').trim();

  // ---- Element parsing ----------------------------------------------------

  /// {@template xml_parser_parse_element}
  /// Parses the given XML element string.
  /// 
  /// {@endtemplate}
  Map<String, dynamic> _parseElement(String elementXml) {
    final openStart = elementXml.indexOf('<');
    if (openStart < 0) {
      // Text only (shouldn’t reach here for well-formed elements)
      return {'tagName': '', 'content': elementXml};
    }

    final openEnd = _findTagEnd(elementXml, openStart);
    if (openEnd < 0) {
      throw ParserException('Malformed tag: missing ">" in: ${_preview(elementXml)}');
    }

    // Self-closing? <tag .../>
    final selfClosing = openEnd > openStart && elementXml[openEnd - 1] == '/';

    // Extract '<tagName attrs...'
    final tagHeader = elementXml.substring(openStart + 1, openEnd).trim();
    final tagName = _extractTagName(tagHeader);
    if (tagName.isEmpty) {
      throw ParserException('Missing tag name in: ${_preview(elementXml)}');
    }
    final attributes = _extractAttributes(tagHeader);

    if (selfClosing) {
      // <tag .../>
      return {
        'tagName': tagName,
        'content': attributes.isEmpty ? '' : attributes,
      };
    }

    // Find closing </tagName>
    final closeStart = _findMatchingClose(elementXml, tagName, openEnd + 1);
    if (closeStart < 0) {
      throw ParserException('Missing closing tag for <$tagName> in: ${_preview(elementXml)}');
    }
    final closeEnd = _findTagEnd(elementXml, closeStart);
    if (closeEnd < 0) {
      throw ParserException('Malformed closing tag for <$tagName>');
    }

    final inner = elementXml.substring(openEnd + 1, closeStart).trim();

    // If inner contains child elements
    final childrenXml = _extractElements(inner);
    if (childrenXml.isNotEmpty) {
      final children = <String, dynamic>{};
      for (final child in childrenXml) {
        final parsedChild = _parseElement(child);
        final childName = parsedChild['tagName'] as String;
        final childContent = parsedChild['content'];

        if (children.containsKey(childName)) {
          if (children[childName] is! List) {
            children[childName] = [children[childName]];
          }
          (children[childName] as List).add(childContent);
        } else {
          children[childName] = childContent;
        }
      }

      if (attributes.isEmpty) {
        return {'tagName': tagName, 'content': children};
      } else {
        final content = <String, dynamic>{};
        content.addAll(attributes);
        content.addAll(children);
        return {'tagName': tagName, 'content': content};
      }
    }

    // Leaf text or empty
    if (inner.isNotEmpty) {
      if (attributes.isEmpty) {
        // pure text
        return {'tagName': tagName, 'content': inner};
      } else {
        // attributes + text
        final content = <String, dynamic>{};
        content.addAll(attributes);
        content['#text'] = inner;
        return {'tagName': tagName, 'content': content};
      }
    }

    // Empty inner
    return {'tagName': tagName, 'content': attributes.isEmpty ? '' : attributes};
  }

  // ---- Helpers: element scanning ------------------------------------------

  // Find '>' for a tag starting at `from`, respecting quotes inside attributes.
  int _findTagEnd(String s, int from) {
    bool inSingle = false, inDouble = false;
    for (int i = from; i < s.length; i++) {
      final ch = s.codeUnitAt(i);
      if (ch == 0x22 && !inSingle) { // "
        inDouble = !inDouble;
      } else if (ch == 0x27 && !inDouble) { // '
        inSingle = !inSingle;
      } else if (ch == 0x3E && !inSingle && !inDouble) { // >
        return i;
      }
    }
    return -1;
  }

  // Find matching closing tag for <tagName ...> beginning search at `pos`.
  int _findMatchingClose(String s, String tagName, int pos) {
    final closeToken = '</$tagName';
    final openToken = '<$tagName';
    int depth = 0;
    int i = pos;

    while (i < s.length) {
      final next = s.indexOf('<', i);
      if (next < 0) return -1;

      // Closing of same tag?
      if (s.startsWith(closeToken, next)) {
        if (depth == 0) return next;
        depth--;
        i = _findTagEnd(s, next) + 1;
        continue;
      }

      // Opening of same tag?
      if (s.startsWith(openToken, next)) {
        final end = _findTagEnd(s, next);
        if (end < 0) return -1;
        final isSelfClosing = end > next && s[end - 1] == '/';
        if (!isSelfClosing) depth++;
        i = end + 1;
        continue;
      }

      // Any other tag – skip past its end to keep scanning
      final end = _findTagEnd(s, next);
      if (end < 0) return -1;
      i = end + 1;
    }
    return -1;
  }

  // Extract top-level child elements contained in `xml` (no regex).
  List<String> _extractElements(String xml) {
    final out = <String>[];
    int i = 0;
    while (i < xml.length) {
      // skip whitespace and text between elements
      while (i < xml.length && xml[i] != '<') i++;
      if (i >= xml.length) break;

      final start = i;
      final openEnd = _findTagEnd(xml, start);
      if (openEnd < 0) break;

      // detect name & self-closing
      final header = xml.substring(start + 1, openEnd);
      if (header.startsWith('/')) {
        // stray closing – move on
        i = openEnd + 1;
        continue;
      }

      final name = _extractTagName(header);
      final selfClosing = openEnd > start && xml[openEnd - 1] == '/';
      if (selfClosing) {
        out.add(xml.substring(start, openEnd + 1));
        i = openEnd + 1;
        continue;
      }

      final closeStart = _findMatchingClose(xml, name, openEnd + 1);
      if (closeStart < 0) {
        // malformed; bail out with remaining substring
        out.add(xml.substring(start));
        break;
      }
      final closeEnd = _findTagEnd(xml, closeStart);
      if (closeEnd < 0) {
        out.add(xml.substring(start));
        break;
      }

      out.add(xml.substring(start, closeEnd + 1));
      i = closeEnd + 1;
    }
    return out;
  }

  /// {@template xml_parser_extract_tag_name}
  /// Extracts the tag name from the given tag header.
  /// 
  /// {@endtemplate}
  String _extractTagName(String tagHeader) {
    final s = tagHeader.trim();
    int i = 0;
    // read until whitespace, '/', or '>'
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      if (c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D || c == 0x2F || c == 0x3E) break;
      i++;
    }
    return s.substring(0, i);
  }

  // ---- Attribute parsing WITHOUT regex ------------------------------------

  /// {@template xml_parser_extract_attributes}
  /// Extracts attributes from the given tag header.
  /// 
  /// {@endtemplate}
  Map<String, dynamic> _extractAttributes(String tagHeader) {
    final attrs = <String, dynamic>{};

    // Skip the tag name
    int i = 0;
    while (i < tagHeader.length && !_isSpaceOrDivider(tagHeader.codeUnitAt(i))) i++;
    // Parse name="value" pairs
    while (i < tagHeader.length) {
      // skip spaces and trailing slashes
      while (i < tagHeader.length) {
        final c = tagHeader.codeUnitAt(i);
        if (c == 0x2F) { i++; continue; } // '/'
        if (_isSpace(c)) { i++; continue; }
        break;
      }
      if (i >= tagHeader.length) break;

      // name
      final nameStart = i;
      while (i < tagHeader.length && _isNameChar(tagHeader.codeUnitAt(i))) i++;
      if (i == nameStart) break; // no more attributes
      final name = tagHeader.substring(nameStart, i);

      // skip spaces
      while (i < tagHeader.length && _isSpace(tagHeader.codeUnitAt(i))) i++;
      if (i >= tagHeader.length || tagHeader[i] != '=') break;
      i++; // '='
      while (i < tagHeader.length && _isSpace(tagHeader.codeUnitAt(i))) i++;
      if (i >= tagHeader.length) break;

      final quote = tagHeader[i];
      if (quote != '\'' && quote != '"') {
        // unquoted value (rare in XML, but handle)
        final valStart = i;
        while (i < tagHeader.length &&
            !_isSpaceOrDivider(tagHeader.codeUnitAt(i))) i++;
        final value = tagHeader.substring(valStart, i);
        attrs['@$name'] = value;
        continue;
      }

      // quoted value
      i++; // past opening quote
      final valStart = i;
      while (i < tagHeader.length && tagHeader[i] != quote) i++;
      final value = tagHeader.substring(valStart, i);
      if (i < tagHeader.length) i++; // past closing quote

      attrs['@$name'] = value;
    }

    return attrs;
  }

  /// {@template xml_parser_is_space}
  /// Checks if the given character is a whitespace character.
  /// 
  /// {@endtemplate}
  bool _isSpace(int c) => c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D;

  /// {@template xml_parser_is_space_or_divider}
  /// Checks if the given character is a whitespace or divider character.
  /// 
  /// {@endtemplate}
  bool _isSpaceOrDivider(int c) => _isSpace(c) || c == 0x2F || c == 0x3E; // '/', '>'

  /// {@template xml_parser_is_name_char}
  /// Checks if the given character is a valid XML name character.
  /// 
  /// {@endtemplate}
  bool _isNameChar(int c) {
    // a-z A-Z 0-9 _ - : .
    return (c >= 0x30 && c <= 0x39) || // 0-9
           (c >= 0x41 && c <= 0x5A) || // A-Z
           (c >= 0x61 && c <= 0x7A) || // a-z
           c == 0x5F || // _
           c == 0x2D || // -
           c == 0x3A || // :
           c == 0x2E;   // .
  }

  /// {@template xml_parser_preview}
  /// Returns a preview of the given string, truncated to the specified maximum length.
  /// 
  /// {@endtemplate}
  String _preview(String s, [int max = 80]) => s.length <= max ? s : s.substring(0, max) + '...';

  // ---- Asset & File -------------------------------------------------------

  @override
  Map<String, dynamic> parseAsset(Asset asset) {
    try {
      return super.parseAsset(asset);
    } catch (e) {
      throw ParserException('Failed to parse XML asset ${asset.getFileName()}: $e');
    }
  }

  @override
  Map<String, dynamic> parseFile(String path) {
    try {
      return super.parseFile(path);
    } catch (e) {
      if (e is ParserException) rethrow;
      throw ParserException('Failed to parse XML file $path: $e');
    }
  }
}