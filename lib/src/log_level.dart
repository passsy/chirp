/// Log severity level
///
/// A simple label with numeric severity for sorting and filtering.
/// Writers/formatters are responsible for mapping levels to target systems.
///
/// Standard levels (by severity):
/// - trace (0) - Most detailed information
/// - debug (100) - Debug information
/// - info (200) - Routine information
/// - notice (300) - Normal but significant events
/// - warning (400) - Warning events
/// - error (500) - Error events
/// - critical (600) - Critical events
/// - wtf (1000) - What a Terrible Failure
///
/// Users can create custom levels:
/// ```dart
/// const verbose = ChirpLogLevel('verbose', 50);
/// const notice = ChirpLogLevel('notice', 300);
/// ```
class ChirpLogLevel {
  /// The name/label of this log level
  final String name;

  /// Numeric severity for sorting and filtering.
  /// Higher values indicate higher severity.
  final int severity;

  const ChirpLogLevel(this.name, this.severity);

  /// **Trace** - Most detailed, fine-grained information
  ///
  /// Use for:
  /// - Detailed execution flow (entering/exiting methods)
  /// - Variable values at each step
  /// - Loop iterations
  /// - Very verbose debugging information
  ///
  /// Typically disabled in production due to high volume.
  /// Severity: 0 (lowest)
  static const trace = ChirpLogLevel('trace', 0);

  /// **Debug** - Diagnostic information for troubleshooting
  ///
  /// Use for:
  /// - Function parameters and return values
  /// - State changes during operations
  /// - Branch decisions (which if/else path taken)
  /// - Resource allocation/deallocation
  ///
  /// Usually enabled during development, disabled in production.
  /// Severity: 100
  static const debug = ChirpLogLevel('debug', 100);

  /// **Info** - Routine operational messages
  ///
  /// Use for:
  /// - Application startup/shutdown
  /// - Configuration loaded
  /// - Service started/stopped
  /// - Request received/completed
  /// - User logged in/out
  /// - Job started/finished
  ///
  /// Standard production logging level. Should be meaningful to operators.
  /// Severity: 200 (default)
  static const info = ChirpLogLevel('info', 200);

  /// **Notice** - Normal but significant events
  ///
  /// Use for:
  /// - Important state transitions
  /// - Security events (successful login, permission changes)
  /// - Configuration changes applied
  /// - Significant business events
  /// - Data migrations started/completed
  /// - System mode changes (maintenance mode, read-only mode)
  ///
  /// More significant than info but not a warning. Commonly used in
  /// GCP Cloud Logging, Syslog, and other logging systems.
  /// Severity: 300
  static const notice = ChirpLogLevel('notice', 300);

  /// **Warning** - Potentially problematic situations
  ///
  /// Use for:
  /// - Deprecated feature usage
  /// - Approaching resource limits (80% disk space)
  /// - Recoverable errors (retry succeeded)
  /// - Unexpected but handled situations
  /// - Performance degradation
  /// - Configuration issues that don't prevent operation
  ///
  /// Indicates something that should be investigated but isn't critical.
  /// Severity: 400
  static const warning = ChirpLogLevel('warning', 400);

  /// **Error** - Errors that prevent specific operations
  ///
  /// Use for:
  /// - Failed API requests
  /// - Database query failures
  /// - File not found
  /// - Validation errors
  /// - Exceptions that were caught and handled
  /// - Operations that failed but app continues
  ///
  /// Indicates a problem occurred but the application can continue.
  /// Severity: 500
  static const error = ChirpLogLevel('error', 500);

  /// **Critical** - Severe errors affecting core functionality
  ///
  /// Use for:
  /// - Database connection lost
  /// - Core service unavailable
  /// - Data corruption detected
  /// - Security breach detected
  /// - System resource exhaustion
  /// - Critical business process failure
  ///
  /// Requires immediate attention. May affect multiple users/operations.
  /// Severity: 600
  static const critical = ChirpLogLevel('critical', 600);

  /// **WTF** (What a Terrible Failure) - Impossible situations
  ///
  /// Use for:
  /// - Situations that should be logically impossible
  /// - Invariant violations
  /// - Corrupt state detected
  /// - "This should never happen" conditions
  /// - Critical assertions failed
  ///
  /// Example: User has negative age, non-null value is null, 2+2≠4
  ///
  /// Inspired by Android's Log.wtf(). Indicates a programmer error or
  /// serious system corruption. Should trigger alerts and investigation.
  /// Severity: 1000 (highest)
  static const wtf = ChirpLogLevel('wtf', 1000);

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChirpLogLevel &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          severity == other.severity;

  @override
  int get hashCode => Object.hash(name, severity);
}
