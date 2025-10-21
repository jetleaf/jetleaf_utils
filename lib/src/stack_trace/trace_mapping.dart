import 'trace_frame.dart';

/// {@template trace_mapping}
/// A structured representation of a complete stack trace with analysis capabilities.
///
/// This class wraps a collection of [TraceFrame] instances and provides
/// comprehensive methods for stack trace analysis, filtering, and navigation.
/// It enables sophisticated stack trace processing for debugging, logging,
/// and diagnostic scenarios in JetLeaf applications.
///
/// TraceMapping supports common stack trace operations such as caller
/// identification, frame filtering by package or method, and hierarchical
/// navigation through the call stack. It serves as the foundation for
/// JetLeaf's advanced diagnostic and monitoring features.
///
/// ## Example
/// ```dart
/// void inspectStack() {
///   final stackTrace = StackTrace.current;
///   final mapping = TraceMapping.fromStackTrace(stackTrace);
///
///   print('Top frame: ${mapping.frameAt(0)}');
///   print('Caller: ${mapping.getCallingMethod()}');
///   print('All frames:\n${mapping}');
/// }
/// ```
///
/// This class is part of JetLeaf’s **reflective trace analysis subsystem**,
/// supporting introspection of AOP proxies, runtime weaving, and
/// advanced diagnostic features.
/// 
/// {@endtemplate}
final class TraceMapping {
  /// The collection of stack trace frames in hierarchical order.
  /// 
  /// Frames are stored in call order, with index 0 typically representing
  /// the most recent call (the method that generated the stack trace) and
  /// higher indices representing progressively earlier calls in the stack.
  final List<TraceFrame> _frames;
  
  /// {@macro trace_mapping}
  ///
  /// Creates a new TraceMapping from a list of parsed stack trace frames.
  ///
  /// @param frames The list of TraceFrame instances representing the complete stack trace
  TraceMapping(this._frames);
  
  /// {@template TraceMapping_getCallingMethod}
  /// Retrieves the frame representing the immediate caller of the current method.
  ///
  /// This method skips the current method frame (typically at index 0) and
  /// returns the frame that called the current method. This is particularly
  /// useful for security checks, audit logging, and context propagation
  /// where you need to know which code invoked the current operation.
  ///
  /// ## Example Usage
  /// ```dart
  /// void logCallerContext() {
  ///   final stackTrace = StackTrace.current;
  ///   final traceMapping = TraceMapping.fromStackTrace(stackTrace);
  ///   final caller = traceMapping.getCallingMethod();
  ///   
  ///   if (caller != null) {
  ///     logger.info('Method called from: ${caller.getMethodName()} in ${caller.packageUri}');
  ///   }
  /// }
  /// ```
  ///
  /// @return The caller frame if available, null if this is the top of stack
  /// {@endtemplate}
  TraceFrame? getCallingMethod() {
    if (_frames.length > 1) {
      return _frames[1]; // #1 is usually the caller
    }
    return null;
  }

  /// {@template TraceMapping_frameAt}
  /// Retrieves the stack frame at the specified hierarchical index.
  ///
  /// This method provides direct access to frames by their position in the
  /// call stack. Index 0 represents the current method (most recent call),
  /// while higher indices represent progressively earlier calls.
  ///
  /// ## Example Usage
  /// ```dart
  /// void analyzeSpecificFrame() {
  ///   final traceMapping = TraceMapping.fromStackTrace(StackTrace.current);
  ///   final currentFrame = traceMapping.frameAt(0); // Current method
  ///   final callerFrame = traceMapping.frameAt(1);  // Immediate caller
  ///   final rootFrame = traceMapping.frameAt(_frames.length - 1); // Root call
  /// }
  /// ```
  ///
  /// @param index The hierarchical position of the frame to retrieve
  /// @return The frame at the specified index, or null if index is out of bounds
  /// {@endtemplate}
  TraceFrame? frameAt(int index) => (index >= 0 && index < _frames.length) ? _frames[index] : null;

  /// {@template TraceMapping_isEmpty}
  /// Determines whether this trace mapping contains any frames.
  ///
  /// An empty trace mapping typically indicates that stack trace parsing
  /// failed or that the original stack trace was empty. This can be useful
  /// for error handling and fallback behavior in diagnostic scenarios.
  ///
  /// @return true if no frames are available, false otherwise
  /// {@endtemplate}
  bool isEmpty() => _frames.isEmpty;

  /// {@template TraceMapping_getAllFrames}
  /// Retrieves all frames in this trace mapping as an unmodifiable list.
  ///
  /// This method provides complete access to the parsed stack trace while
  /// ensuring the integrity of the original frame collection. The returned
  /// list maintains the hierarchical order of the call stack.
  ///
  /// ## Example Usage
  /// ```dart
  /// void processCompleteStackTrace() {
  ///   final traceMapping = TraceMapping.fromStackTrace(StackTrace.current);
  ///   final allFrames = traceMapping.getAllFrames();
  ///   
  ///   for (final frame in allFrames) {
  ///     if (frame.getMethodName() != null) {
  ///       _analyzeFrame(frame);
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// @return Unmodifiable list of all trace frames in hierarchical order
  /// {@endtemplate}
  List<TraceFrame> getAllFrames() => List<TraceFrame>.unmodifiable(_frames);
  
  /// {@template TraceMapping_findByMethodName}
  /// Finds the first frame with the specified method name.
  ///
  /// This method searches through the stack trace frames in hierarchical
  /// order (most recent first) and returns the first frame that matches
  /// the specified method name. This is useful for locating specific
  /// method invocations within a complex call stack.
  ///
  /// ## Example Usage
  /// ```dart
  /// void findSpecificMethod() {
  ///   final traceMapping = TraceMapping.fromStackTrace(StackTrace.current);
  ///   final validationFrame = traceMapping.findByMethodName('validateInput');
  ///   
  ///   if (validationFrame != null) {
  ///     logger.info('Validation occurred at: ${validationFrame.packageUri}:${validationFrame.lineNumber}');
  ///   }
  /// }
  /// ```
  ///
  /// @param methodName The method name to search for in the stack trace
  /// @return The first matching frame, or an empty frame if no match found
  /// {@endtemplate}
  TraceFrame? findByMethodName(String methodName) {
    return _frames.firstWhere(
      (frame) => frame.getMethodName() == methodName, 
      orElse: () => TraceFrame.empty("")
    );
  }
  
  /// {@template TraceMapping_getFramesFromPackage}
  /// Retrieves all frames originating from the specified package.
  ///
  /// This method filters the stack trace to include only frames from
  /// the specified package, enabling package-specific analysis and
  /// isolation of application code from library/framework code.
  ///
  /// ## Example Usage
  /// ```dart
  /// void isolateApplicationFrames() {
  ///   final traceMapping = TraceMapping.fromStackTrace(StackTrace.current);
  ///   final appFrames = traceMapping.getFramesFromPackage('package:myapp');
  ///   final serviceFrames = traceMapping.getFramesFromPackage('package:myapp/service');
  ///   
  ///   logger.info('Application call depth: ${appFrames.length}');
  ///   logger.info('Service call depth: ${serviceFrames.length}');
  /// }
  /// ```
  ///
  /// @param package The package identifier to filter frames by
  /// @return List of frames from the specified package, empty if none found
  /// {@endtemplate}
  List<TraceFrame> getFramesFromPackage(String package) {
    return _frames.where((frame) => frame.packageUri.contains(package)).toList();
  }
  
  /// {@template TraceMapping_toString}
  /// Returns a formatted string representation of the complete stack trace.
  ///
  /// The string representation follows standard stack trace formatting
  /// conventions, with each frame on a separate line and proper hierarchical
  /// numbering. This format is compatible with most logging systems and
  /// debugging tools that expect traditional stack trace output.
  ///
  /// ## Example Output
  /// ```dart
  /// #0 MyService.processRequest (package:example/service.dart:45:12)
  /// #1 ApiController.handleRequest (package:example/api.dart:89:7)
  /// #2 main (package:example/main.dart:10:5)
  /// ```
  ///
  /// @return Formatted multi-line string representation of the stack trace
  /// {@endtemplate}
  @override
  String toString() {
    return _frames.map((f) => f.toString()).join('\n');
  }
}