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

import '../exceptions.dart';
import 'parser.dart';

/// {@template env_parser}
/// Parses dotenv (`.env`) style files into a `Map<String, dynamic>`.
///
/// ### Supported features
/// - UTF-8 BOM removal.
/// - Normalization of line endings (`\r\n` / `\r` → `\n`).
/// - Blank line and comment (`#` or `;`) skipping.
/// - `export` prefix (e.g. `export KEY=VALUE`).
/// - Key validation: must match `^[A-Za-z_][A-Za-z0-9_.-]*$`.
/// - Key/value delimiters: `=` or `:` (outside of quotes).
/// - Quoted values:
///   - Single-quoted → literal except `\'` and `\\`.
///   - Double-quoted → supports `\n`, `\r`, `\t`, `\"`, `\'`, `\\`.
///   - Multi-line quoted values are supported.
/// - Unquoted values:
///   - Strips inline comments after `#` or `;`.
///   - Supports escaping comment markers and spaces with `\`.
///
/// ### Example
/// ```env
/// # standard
/// HOST=localhost
/// PORT=8080
///
/// # quoted
/// PASSWORD="p@ss word"
///
/// # multi-line
/// CERT="-----BEGIN-----
/// some-data
/// -----END-----"
/// ```
///
/// Produces:
/// ```dart
/// {
///   'HOST': 'localhost',
///   'PORT': '8080',
///   'PASSWORD': 'p@ss word',
///   'CERT': '-----BEGIN-----\nsome-data\n-----END-----'
/// }
/// ```
/// {@endtemplate}
class EnvParser extends Parser {
  /// Create an EnvParser.
  /// 
  /// {@macro env_parser}
  EnvParser();

  @override
  Map<String, dynamic> parse(String source) {
    try {
      final normalized = _normalizeNewlines(source);
      return _parseLines(normalized);
    } catch (e) {
      throw ParserException('Failed to parse ENV: $e');
    }
  }

  // ---- Root ---------------------------------------------------------------

  /// Normalize line endings to '\n' and remove BOM if present.
  String _normalizeNewlines(String s) {
    var t = s;
    // Remove BOM (UTF-8)
    if (t.isNotEmpty && t.codeUnitAt(0) == 0xFEFF) {
      t = t.substring(1);
    }
    // Normalize CRLF and CR to LF
    t = t.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    return t;
  }

  // ---- Main parser -------------------------------------------------------

  Map<String, dynamic> _parseLines(String src) {
    final out = <String, dynamic>{};
    final lines = src.split('\n');

    int i = 0;
    while (i < lines.length) {
      final rawLine = lines[i];
      final lineNo = i + 1;
      final rawPreview = _preview(rawLine);

      // Trim leading/trailing spaces
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) {
        i++;
        continue; // skip blank lines
      }

      // Skip pure comment lines
      if (_isComment(trimmed)) {
        i++;
        continue;
      }

      // Support optional "export " prefix (remove only that token)
      final working = _stripExportPrefix(rawLine);

      // Find first '=' or ':' delimiter outside quotes.
      final delimIndex = _findUnquotedDelimiter(working);
      if (delimIndex < 0) {
        // No delimiter - treat "KEY" as key with empty string value.
        final key = working.trim();
        if (key.isEmpty) {
          i++;
          continue;
        }
        _validateKey(key, lineNo, rawPreview);
        out[key] = '';
        i++;
        continue;
      }

      final rawKey = working.substring(0, delimIndex).trim();
      final rawValuePart = working.substring(delimIndex + 1);

      _validateKey(rawKey, lineNo, rawPreview);

      // Parse value: may be quoted (single/double) possibly spanning multiple lines,
      // or unquoted (single-line).
      final valueResult = _parseValuePossiblyMultiline(rawValuePart, lines, i);

      final parsedValue = valueResult.value;

      out[rawKey] = parsedValue;

      // Advance i: valueResult.consumedAdditionalLines is number of additional lines consumed
      i += 1 + valueResult.consumedAdditionalLines;
    }

    return out;
  }

  // ---- Helpers: keys, delimiters, comments --------------------------------

  bool _isComment(String s) {
    final t = s.trimLeft();
    return t.startsWith('#') || t.startsWith(';');
  }

  String _stripExportPrefix(String line) {
    // Remove only the first 'export' token (case-sensitive) if present at start (after optional leading whitespace).
    final trimmedLeft = line.trimLeft();
    if (trimmedLeft.startsWith('export')) {
      final idx = line.indexOf('export');
      if (idx >= 0) {
        int pos = idx + 6; // skip "export"
        // skip following whitespace
        while (pos < line.length && _isSpace(line.codeUnitAt(pos))) {
          pos++;
        }
        return line.substring(pos);
      }
    }
    return line;
  }

  // Add inside the EnvParser class (private helper)
  bool _isSpace(int c) => c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D;

  /// Returns index of first unquoted '=' or ':' delimiter, or -1 if none.
  int _findUnquotedDelimiter(String s) {
    bool inSingle = false, inDouble = false;
    for (int i = 0; i < s.length; i++) {
      final ch = s.codeUnitAt(i);
      if (ch == 0x22 && !inSingle) {
        inDouble = !inDouble;
      } else if (ch == 0x27 && !inDouble) {
        inSingle = !inSingle;
      } else if (!inSingle && !inDouble && (ch == 0x3D || ch == 0x3A)) {
        // '=' or ':'
        return i;
      } else if (ch == 0x5C) {
        // backslash - skip next char
        i++;
      }
    }
    return -1;
  }

  void _validateKey(String key, int lineNo, String preview) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      throw ParserException('Empty env key at line $lineNo near: $preview');
    }
    // Basic validation: must start with letter or underscore; allow letters, digits, dot, underscore, hyphen
    final namePattern = RegExp(r'^[A-Za-z_][A-Za-z0-9_.-]*$');
    if (!namePattern.hasMatch(trimmed)) {
      throw ParserException('Invalid env key "$trimmed" at line $lineNo near: $preview');
    }
  }

  // ---- Value parsing (handles multi-line quoted values) -------------------

  /// Returns a [_ValueResult] where [consumedAdditionalLines] is the number of
  /// extra lines (beyond the current one) consumed while parsing this value.
  _ValueResult _parseValuePossiblyMultiline(
    String rawValuePart,
    List<String> allLines,
    int currentLineIndex,
  ) {
    // Trim only leading spaces from the remainder
    var working = rawValuePart;
    if (working.isNotEmpty) {
      working = working.replaceFirst(RegExp(r'^\s+'), '');
    }

    if (working.isEmpty) {
      return _ValueResult('', 0);
    }

    final firstChar = working.codeUnitAt(0);
    if (firstChar == 0x22 || firstChar == 0x27) {
      // Quoted value — gather text until matching (unescaped) closing quote.
      final quote = firstChar;
      // Start stream with the part after the opening quote (exclude the opening quote)
      var stream = working.substring(1);
      int extraLinesConsumed = 0;

      while (true) {
        // Scan the stream for an unescaped closing quote
        bool escaped = false;
        for (int pos = 0; pos < stream.length; pos++) {
          final ch = stream.codeUnitAt(pos);
          if (ch == 0x5C && !escaped) {
            escaped = true;
            continue;
          }
          if (ch == quote && !escaped) {
            // Found closing quote at pos
            final content = stream.substring(0, pos);
            final unescaped = _unescapeQuoted(content, quote == 0x22);
            return _ValueResult(unescaped, extraLinesConsumed);
          }
          escaped = false;
        }

        // No closing quote found in current stream -> append next line (if any)
        final nextLineIndex = currentLineIndex + 1 + extraLinesConsumed;
        if (nextLineIndex >= allLines.length) {
          throw ParserException(
              'Unterminated quoted value starting at line ${currentLineIndex + 1}: ${_preview(working)}');
        }
        // Append newline + next line content and continue scanning
        stream = '$stream\n${allLines[nextLineIndex]}';
        extraLinesConsumed++;
      }
    } else {
      // Unquoted value - strip inline comment starting with unescaped '#' or ';'
      var v = _stripInlineCommentFromUnquoted(working);
      v = v.trim();
      return _ValueResult(v, 0);
    }
  }

  // Unescape quoted string contents.
  // If isDoubleQuote is true, support common escapes like \n, \r, \t, \", \\.
  // For single-quoted strings, only allow escaping of single-quote and backslash.
  String _unescapeQuoted(String s, bool isDouble) {
    final out = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final ch = s.codeUnitAt(i);
      if (ch == 0x5C) {
        if (i + 1 >= s.length) break;
        final next = s.codeUnitAt(i + 1);
        i++;
        if (isDouble) {
          if (next == 0x6E) {
            out.write('\n'); // n
          } else if (next == 0x72) {
            out.write('\r'); // r
          } else if (next == 0x74) {
            out.write('\t'); // t
          } else if (next == 0x22) {
            out.write('"'); // "
          } else if (next == 0x27) {
            out.write("'"); // '
          } else if (next == 0x5C) {
            out.write('\\'); // \
          } else {
            out.writeCharCode(next); // unknown escape -> literal char
          }
        } else {
          // single-quoted: allow escaping of single quote and backslash
          if (next == 0x27) {
            out.write("'");
          } else if (next == 0x5C) {
            out.write('\\');
          } else {
            out.writeCharCode(next);
          }
        }
      } else {
        out.writeCharCode(ch);
      }
    }
    return out.toString();
  }

  String _stripInlineCommentFromUnquoted(String s) {
    final out = StringBuffer();
    bool escaped = false;
    for (int i = 0; i < s.length; i++) {
      final ch = s.codeUnitAt(i);
      if (!escaped && (ch == 0x23 || ch == 0x3B)) {
        // '#' or ';' starts a comment
        break;
      }
      if (ch == 0x5C && !escaped) {
        // backslash - next char is escaped; keep next char but drop the backslash
        if (i + 1 < s.length) {
          out.writeCharCode(s.codeUnitAt(i + 1));
          i++; // skip next char because we've consumed it
          escaped = false;
          continue;
        } else {
          // Trailing backslash — keep as-is
          out.writeCharCode(ch);
          continue;
        }
      }
      out.writeCharCode(ch);
      escaped = false;
    }
    return out.toString();
  }

  // ---- Utility: preview / file / asset -----------------------------------

  /// Returns a short preview of a line or string.
  String _preview(String s, [int max = 80]) => s.length <= max ? s : '${s.substring(0, max)}...';

  @override
  Map<String, dynamic> parseAsset(Asset asset) {
    try {
      return super.parseAsset(asset);
    } catch (e) {
      throw ParserException('Failed to parse ENV asset ${asset.getFileName()}: $e');
    }
  }

  @override
  Map<String, dynamic> parseFile(String path) {
    try {
      return super.parseFile(path);
    } catch (e) {
      if (e is ParserException) rethrow;
      throw ParserException('Failed to parse ENV file $path: $e');
    }
  }
}

/// Private helper holding parsed value and how many *additional* lines were consumed.
class _ValueResult {
  final dynamic value;
  final int consumedAdditionalLines;
  _ValueResult(this.value, this.consumedAdditionalLines);
}
