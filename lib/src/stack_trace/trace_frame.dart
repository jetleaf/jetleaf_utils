import 'package:jetleaf_lang/lang.dart';

/// {@template TraceFrameConstants}
/// Constants used by TraceFrame for default values and unknown identifiers.
/// 
/// These constants provide consistent default values for trace frame properties
/// when the actual information cannot be determined from stack trace parsing.
/// They ensure that TraceFrame instances always have valid values even when
/// dealing with incomplete or malformed stack trace data.
/// {@endtemplate}
const String _UNKNOWN_CLASS_NAME = "<unknown class>";
const String _UNKNOWN_METHOD_NAME = "<unknown method>";
const int _DEFAULT_HIERARCHY = -1;

/// {@template trace_frame}
/// Represents a single structured entry in a JetLeaf stack trace.
///
/// A [TraceFrame] models an individual call frame captured during
/// runtime introspection, such as when an exception occurs or when
/// JetLeaf’s reflective AOP layer is used to trace execution.
/// 
/// Represents a single frame in a stack trace with structured parsing and analysis.
///
/// This class provides a structured representation of stack trace frames with
/// comprehensive metadata extraction and analysis capabilities. It parses raw
/// stack trace lines into meaningful components (class, method, package URI,
/// line numbers) and provides utility methods for frame analysis and filtering.
///
/// TraceFrame is essential for JetLeaf's diagnostic, logging, and debugging
/// infrastructure, enabling sophisticated stack trace analysis and presentation
/// across different execution environments and stack trace formats.
///
/// Each frame contains structured metadata extracted from the raw
/// Dart stack trace, including:
/// - Hierarchical depth within the call stack.
/// - The class and method context of the call.
/// - Source file location (package URI, line, column).
/// - Original raw text of the trace line.
///
/// This class is an essential part of JetLeaf’s runtime diagnostics
/// and reflection facilities. It allows accurate mapping between
/// user code, proxy-generated calls, and framework-level interceptors.
///
/// ## Example
/// ```dart
/// final frame = TraceFrame(
///   hierarchy: 2,
///   className: 'MyService',
///   methodName: 'processRequest',
///   packageUri: 'package:example/service.dart',
///   lineNumber: 45,
///   column: 12,
///   raw: '#2 MyService.processRequest (package:example/service.dart:45:12)',
/// );
///
/// print(frame);
/// // #2 MyService.processRequest (package:example/service.dart:45:12)
/// ```
/// {@endtemplate}
final class TraceFrame {
  /// The hierarchical position of this frame in the stack trace.
  /// 
  /// Represents the depth of this frame in the call stack, with 0 typically
  /// being the top-most frame (most recent call). A value of [_DEFAULT_HIERARCHY]
  /// indicates the hierarchy information is not available.
  final int hierarchy;

  /// The name of the class containing this stack frame.
  /// 
  /// For instance methods, this represents the class that contains the method.
  /// For top-level functions or static methods, this may be null or contain
  /// [_UNKNOWN_CLASS_NAME] if the class context cannot be determined.
  final String _className;

  /// The name of the method or function represented by this stack frame.
  /// 
  /// This captures the method name, function name, or constructor name
  /// that was executing at this point in the call stack.
  final String _methodName;

  /// The package URI or file path containing this stack frame.
  /// 
  /// This typically follows Dart's package URI format (package:example/file.dart)
  /// or file path format for local files. It identifies the source location
  /// of the code executing in this frame.
  final String packageUri;

  /// The line number in the source file where this frame was executing.
  /// 
  /// This provides precise location information for debugging and error
  /// reporting. A value of 0 indicates the line number is not available.
  final int lineNumber;

  /// The column number in the source file where this frame was executing.
  /// 
  /// This provides additional precision for error location within a line.
  /// A value of 0 indicates the column information is not available.
  final int column;

  /// The raw text of the stack trace line that was parsed to create this frame.
  /// 
  /// Preserves the original stack trace representation for debugging and
  /// compatibility with external tools that expect raw stack trace format.
  final String raw;
  
  /// {@macro trace_frame}
  /// Creates a new TraceFrame with complete structured stack frame information.
  ///
  /// This constructor requires all essential stack frame components and provides
  /// sensible defaults for optional components through named parameters.
  ///
  /// @param hierarchy The position of this frame in the call stack hierarchy
  /// @param className The name of the class containing the method (optional)
  /// @param methodName The name of the method or function (optional)
  /// @param packageUri The package URI or file path of the source code
  /// @param lineNumber The line number in the source file
  /// @param column The column number in the source file
  /// @param raw The original raw stack trace line text
  const TraceFrame({
    required this.hierarchy,
    String? className,
    String? methodName,
    required this.packageUri,
    required this.lineNumber,
    required this.column,
    required this.raw
  }) : _className = className ?? _UNKNOWN_CLASS_NAME, _methodName = methodName ?? _UNKNOWN_METHOD_NAME;
  
  /// {@template TraceFrame_empty}
  /// Creates an empty TraceFrame from raw stack trace text.
  ///
  /// This constructor creates a minimal TraceFrame when only the raw stack
  /// trace line is available and structured parsing is not possible or
  /// has failed. The resulting frame will have default values for all
  /// structured components.
  ///
  /// @param raw The original raw stack trace line text
  /// {@endtemplate}
  const TraceFrame.empty(this.raw)
    : hierarchy = _DEFAULT_HIERARCHY,
      _className = _UNKNOWN_CLASS_NAME,
      _methodName = _UNKNOWN_METHOD_NAME,
      packageUri = '',
      lineNumber = 0,
      column = 0;
  
  /// {@template TraceFrame_getClassName}
  /// Retrieves the class name for this stack frame, if available.
  ///
  /// This method returns the class name when it represents a valid,
  /// known class context. Returns null for top-level functions, static
  /// methods without class context, or when the class name cannot be
  /// determined from the stack trace.
  ///
  /// @return The class name if available and known, null otherwise
  /// {@endtemplate}
  String? getClassName() => _className.equals(_UNKNOWN_CLASS_NAME) ? null : _className;

  /// {@template TraceFrame_getMethodName}
  /// Retrieves the method name for this stack frame, if available.
  ///
  /// This method returns the method name when it represents a valid,
  /// known method or function. Returns null when the method name cannot
  /// be determined from the stack trace or represents an unknown context.
  ///
  /// @return The method name if available and known, null otherwise
  /// {@endtemplate}
  String? getMethodName() => _methodName.equals(_UNKNOWN_METHOD_NAME) ? null : _methodName;

  /// {@template TraceFrame_isTopLevelFunction}
  /// Determines whether this frame represents a top-level function.
  ///
  /// Top-level functions are identified by the absence of a class context
  /// in the stack frame. This is useful for distinguishing between
  /// instance methods, static methods, and top-level function calls
  /// when analyzing call patterns and execution contexts.
  ///
  /// @return true if this frame represents a top-level function, false otherwise
  /// {@endtemplate}
  bool isTopLevelFunction() => _className.isEmpty || _className.equals(_UNKNOWN_CLASS_NAME);

  /// {@template TraceFrame_getFileName}
  /// Extracts the base filename from the package URI without package prefix.
  ///
  /// This method processes the package URI to extract just the filename
  /// component, making it more suitable for display in user interfaces
  /// and log messages where package prefixes may be redundant.
  ///
  /// ## Example
  /// ```dart
  /// // For package URI 'package:example/service/advisable.dart'
  /// // Returns 'advisable.dart'
  /// final fileName = frame.getFileName();
  /// ```
  ///
  /// @return The base filename if available, null if package URI is empty
  /// {@endtemplate}
  String? getFileName() {
    if (packageUri.isEmpty) {
      return null;
    }

    final idx = packageUri.lastIndexOf('/');
    return idx >= 0 ? packageUri.substring(idx + 1) : packageUri;
  }
  
  /// {@template TraceFrame_toString}
  /// Returns a formatted string representation of this stack frame.
  ///
  /// The string representation follows standard stack trace formatting
  /// conventions while providing structured information in a human-readable
  /// format. It includes hierarchy, class/method context, and source location
  /// information when available.
  ///
  /// ## Example Output
  /// ```dart
  /// #2 MyService.processRequest (package:example/service.dart:45:12)
  /// #1 main (package:example/main.dart:10:5)
  /// #0 <unknown method> (package:unknown/source.dart:0:0)
  /// ```
  ///
  /// @return Formatted string representation of the stack frame
  /// {@endtemplate}
  @override
  String toString() {
    final builder = StringBuilder();

    if (hierarchy.notEquals(_DEFAULT_HIERARCHY)) {
      builder.append("#$hierarchy ");
    }

    if (getClassName() != null && getMethodName() != null) {
      builder.append("${getClassName()}.${getMethodName()} ");
    } else if (getClassName() != null && getMethodName() == null) {
      builder.append("${getClassName()} ");
    } else if (getClassName() == null && getMethodName() != null) {
      builder.append("${getMethodName()} ");
    }

    builder.append("($packageUri:$lineNumber:$column)");

    return builder.toString();
  }
}