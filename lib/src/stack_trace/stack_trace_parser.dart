import 'package:stack_trace/stack_trace.dart';

import 'trace_frame.dart';
import 'trace_mapping.dart';

/// {@template stack_trace_parser}
/// A comprehensive stack trace parsing utility for JetLeaf applications.
///
/// This parser converts raw Dart stack traces into structured [TraceMapping]
/// instances with detailed frame analysis. It supports multiple stack trace
/// formats including standard Dart VM format, web JavaScript format, and
/// various transformed or minimized stack trace representations.
///
/// StackTraceParser provides robust parsing capabilities that handle:
/// - Standard Dart VM stack traces with hierarchical numbering
/// - Web/JavaScript stack traces with different formatting
/// - Anonymous functions and closure representations
/// - Constructor invocations (new expressions)
/// - File URI extraction and line/column number parsing
/// - Fallback handling for unknown or custom stack trace formats
/// 
/// {@endtemplate}
abstract interface class StackTraceParser {
  /// {@macro stack_trace_parser}
  StackTraceParser._();

  /// {@template StackTraceParser_parse}
  /// Main entry point: parses a Dart StackTrace object into a structured TraceMapping.
  ///
  /// This method serves as the primary interface for converting runtime stack traces
  /// into analyzable structured data. It handles the conversion from Dart's native
  /// StackTrace representation to JetLeaf's structured trace analysis format.
  ///
  /// ## Example Usage
  /// ```dart
  /// void analyzeCurrentStackTrace() {
  ///   try {
  ///     // Some operation that might fail
  ///     riskyOperation();
  ///   } catch (e, stack) {
  ///     final traceMapping = StackTraceParser.parse(stack);
  ///     final caller = traceMapping.getCallingMethod();
  ///     
  ///     if (caller != null) {
  ///       print('Error was called from: ${caller.getMethodName()}');
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// @param stackTrace The Dart StackTrace object to parse
  /// @return A TraceMapping containing structured frame information
  /// {@endtemplate}
  static TraceMapping parse(StackTrace stackTrace) {
    final trace = Trace.from(stackTrace);
    final text = trace.vmTrace.toString();
    return parseStackTrace(text);
  }

  /// {@template stack_trace_utils_getTrace}
  /// Converts a Dart [StackTrace] object into a structured [Trace] instance.
  ///
  /// This method acts as a convenience entry point for obtaining a
  /// [Trace] representation directly from a runtime [StackTrace].
  /// It preserves the original stack hierarchy and provides access
  /// to structured frame-level information for analysis, debugging,
  /// or AOP instrumentation.
  ///
  /// ## Example Usage
  /// ```dart
  /// try {
  ///   riskyOperation();
  /// } catch (e, stack) {
  ///   final trace = StackTraceUtils.getTrace(stack);
  ///   print(trace.frames.first);
  /// }
  /// ```
  ///
  /// @param trace The Dart [StackTrace] to convert.
  /// @return A structured [Trace] instance representing the same stack trace.
  /// {@endtemplate}
  static Trace getTrace(StackTrace trace) => Trace.from(trace);

  /// {@template stack_trace_utils_fromString}
  /// Parses a raw stack trace string into a structured [Trace] instance.
  ///
  /// This method provides a fallback parsing mechanism when only
  /// the string representation of a stack trace is available.
  /// It supports multiple Dart stack trace formats and ensures
  /// consistent structured results for downstream diagnostics
  /// and error reporting.
  ///
  /// ## Example Usage
  /// ```dart
  /// final traceString = '''
  /// #0 MyService.process (package:example/service.dart:23:14)
  /// #1 main (package:example/main.dart:10:3)
  /// ''';
  ///
  /// final trace = StackTraceUtils.fromString(traceString);
  /// print(trace.toString());
  /// ```
  ///
  /// @param trace The raw stack trace string to parse.
  /// @return A structured [Trace] instance created from the parsed string.
  /// {@endtemplate}
  static Trace fromString(String trace) => Trace.parse(trace);

  /// {@template StackTraceParser_parseStackTrace}
  /// Parses a raw stack trace string into a structured TraceMapping.
  ///
  /// This method implements a multi-format parser that can handle various
  /// stack trace representations through a cascade of pattern matching
  /// strategies. It progressively attempts more specific patterns before
  /// falling back to more general parsing approaches.
  ///
  /// Supported formats include:
  /// - Standard Dart: `#0 Class.method (package:uri.dart:line:column)`
  /// - Simplified Dart: `#0 symbol (file:line:column)`
  /// - Location-only: `package:uri.dart:line:column`
  /// - Symbol-only: `symbol (file:line:column)`
  /// - Unknown formats with fallback preservation
  ///
  /// @param stackTrace The raw stack trace string to parse
  /// @return A TraceMapping with all parsed frames in hierarchical order
  /// {@endtemplate}
  static TraceMapping parseStackTrace(String stackTrace) {
    final lines = stackTrace.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final frames = <TraceFrame>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final frame = _parseFrame(line);

      if (frame != null) {
        frames.add(frame);
      } else {
        // Try pattern "#N <symbol> (<fileUri>:line:col)"
        final p1 = RegExp(r'^#(?<idx>\d+)\s+(?<symbol>.+?)\s+\((?<file>[^:()]+):(?<line>\d+):(?<col>\d+)\)$');
        final m1 = p1.firstMatch(line);

        if (m1 != null) {
          final idx = int.tryParse(m1.namedGroup('idx') ?? '') ?? i;
          final symbol = m1.namedGroup('symbol') ?? '';
          final fileUri = m1.namedGroup('file');
          final lineNum = int.tryParse(m1.namedGroup('line') ?? '');
          final colNum = int.tryParse(m1.namedGroup('col') ?? '');
          final parsed = _parseSymbol(symbol);

          frames.add(TraceFrame(
            hierarchy: idx,
            raw: line,
            className: parsed.$1,
            methodName: parsed.$2,
            packageUri: fileUri ?? "",
            lineNumber: lineNum ?? 0,
            column: colNum ?? 0,
          ));
          
          continue;
        }

        // Try pattern "#N <symbol> (<fileUri>:line)" (no column)
        final p1b = RegExp(r'^#(?<idx>\d+)\s+(?<symbol>.+?)\s+\((?<file>[^:()]+):(?<line>\d+)\)$');
        final m1b = p1b.firstMatch(line);
        if (m1b != null) {
          final idx = int.tryParse(m1b.namedGroup('idx') ?? '') ?? i;
          final symbol = m1b.namedGroup('symbol') ?? '';
          final fileUri = m1b.namedGroup('file');
          final lineNum = int.tryParse(m1b.namedGroup('line') ?? '');
          final parsed = _parseSymbol(symbol);
          
          frames.add(TraceFrame(
            hierarchy: idx,
            raw: line,
            className: parsed.$1,
            methodName: parsed.$2,
            packageUri: fileUri ?? "",
            lineNumber: lineNum ?? 0,
            column: 0,
          ));

          continue;
        }

        // Try pattern "package:.../file.dart:line:col" (no leading #)
        final p2 = RegExp(r'^(?<file>[^:()]+):(?<line>\d+):(?<col>\d+)$');
        final m2 = p2.firstMatch(line);
        if (m2 != null) {
          final fileUri = m2.namedGroup('file');
          final lineNum = int.tryParse(m2.namedGroup('line') ?? '');
          final colNum = int.tryParse(m2.namedGroup('col') ?? '');

          frames.add(TraceFrame(
            hierarchy: i,
            raw: line,
            packageUri: fileUri ?? "",
            lineNumber: lineNum ?? 0,
            column: colNum ?? 0,
          ));

          continue;
        }

        // Fallback: symbol-only or unknown format
        // Try to extract symbol and file if there's a trailing " (file:line:col)"
        final p3 = RegExp(r'^(?<symbol>.+?)\s+\((?<file>.+)\)$');
        final m3 = p3.firstMatch(line);
        if (m3 != null) {
          final idx = i;
          final symbol = m3.namedGroup('symbol') ?? '';
          final fileUri = m3.namedGroup('file') ?? '';
          final parsed = _parseSymbol(symbol);

          frames.add(TraceFrame(
            hierarchy: idx,
            raw: line,
            className: parsed.$1,
            methodName: parsed.$2,
            packageUri: fileUri,
            lineNumber: 0,
            column: 0,
          ));

          continue;
        }

        // Last resort: keep raw line
        frames.add(TraceFrame(hierarchy: i, raw: line, packageUri: "", lineNumber: 0, column: 0));
      }
    }

    // Sort frames by index when available (some formats include index)
    frames.sort((a, b) => a.hierarchy.compareTo(b.hierarchy));
    
    return TraceMapping(frames);
  }
  
  /// {@template StackTraceParser_parseFrame}
  /// Parses a standard Dart VM stack trace frame line into a TraceFrame.
  ///
  /// This method handles the most common Dart stack trace format:
  /// `#0 Class.method (package:uri.dart:line:column)`
  ///
  /// It extracts the hierarchical index, class name, method name, package URI,
  /// line number, and column number from properly formatted stack trace lines.
  ///
  /// @param line The stack trace line to parse
  /// @return A parsed TraceFrame if the format matches, null otherwise
  /// {@endtemplate}
  static TraceFrame? _parseFrame(String line) {
    // Parse hierarchy number (e.g., #0, #1, etc.)
    final hierarchyMatch = RegExp(r'^#(\d+)').firstMatch(line);
    if (hierarchyMatch == null) return null;
    
    final hierarchy = int.parse(hierarchyMatch.group(1)!);
    
    // Parse method and class info (e.g., "Advisable.doAdvice", "main", etc.)
    final methodMatch = RegExp(r'#\d+\s+([^(]+)\s+\(').firstMatch(line);
    if (methodMatch == null) return null;
    
    final methodParts = methodMatch.group(1)!.trim().split('.');
    final String className;
    final String? methodName;
    
    if (methodParts.length >= 2) {
      // Class method: "Advisable.doAdvice"
      className = methodParts[0];
      methodName = methodParts[1];
    } else {
      // Top-level function: "main"
      className = '';
      methodName = methodParts[0];
    }
    
    // Parse package URI and location (e.g., "package:jetleaf_aop/src/advisable.dart:11:48")
    final locationMatch = RegExp(r'\((.*?):(\d+):(\d+)\)').firstMatch(line);
    String packageUri = '';
    int lineNumber = 0;
    int column = 0;
    
    if (locationMatch != null) {
      packageUri = locationMatch.group(1)!;
      lineNumber = int.parse(locationMatch.group(2)!);
      column = int.parse(locationMatch.group(3)!);
    }
    
    return TraceFrame(
      hierarchy: hierarchy,
      className: className,
      methodName: methodName,
      packageUri: packageUri,
      lineNumber: lineNumber,
      column: column,
      raw: line
    );
  }

  /// {@template StackTraceParser_parseSymbol}
  /// Parses a symbol string into class and method components.
  ///
  /// This method handles various symbol formats including:
  /// - Class.method: "Advisable.doAdvice" → (Advisable, doAdvice)
  /// - Constructor: "new Advising" → (Advising, new)
  /// - Top-level function: "main" → (null, main)
  /// - Anonymous functions: "_delayEntrypointInvocation.<anonymous closure>" → (null, full symbol)
  /// - Library-qualified: "Library.Class.method" → (Library.Class, method)
  ///
  /// @param symbol The symbol string to parse
  /// @return A tuple containing (className, methodName) with appropriate nullability
  /// {@endtemplate}
  static (String?, String?) _parseSymbol(String symbol) {
    final s = symbol.trim();

    // "new Foo" -> class=Foo, method=new
    final newCtor = RegExp(r'^new\s+([A-Za-z0-9_<>$]+)$');
    final mn = newCtor.firstMatch(s);
    if (mn != null) {
      return (mn.group(1), 'new');
    }

    // "Class.method" or "LibraryPrefix.Class.method" (take last two parts)
    // split by whitespace, then by '.'
    final parts = s.split(RegExp(r'\s+')).last.split('.');
    if (parts.length >= 2) {
      final method = parts.removeLast();
      final className = parts.join('.');
      return (className, method);
    }

    // If symbol contains '<anonymous closure>' or '<fn>', keep as method name
    if (s.contains('<anonymous') || s.contains('closure') || s.contains('<fn>')) {
      return (null, s);
    }

    // single token like "main" -> methodName=main
    return (null, s);
  }
}