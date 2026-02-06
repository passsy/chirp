// ignore_for_file: avoid_dynamic_calls

import 'dart:convert';

import 'package:chirp/chirp.dart';

/// Google Cloud Platform (GCP) compatible JSON formatter.
///
/// Formats logs as single-line JSON according to the structure expected by
/// Google Cloud Logging's structured logging format. Output to stdout/stderr
/// is automatically parsed by Cloud Run, Cloud Functions, GKE, and other
/// GCP services with the Cloud Logging agent.
///
/// ## Features
///
/// - Maps Chirp log levels to GCP LogSeverity
/// - Supports GCP special fields (sourceLocation, trace, labels, etc.)
/// - Formats errors and stack traces for Google Error Reporting
/// - Automatic source location extraction from caller stack trace
///
/// ## Basic Usage
///
/// ```dart
/// Chirp.root = ChirpLogger()
///   .addConsoleWriter(formatter: GcpMessageFormatter());
///
/// Chirp.info('Server started', data: {'port': 8080});
/// // Output: {"severity":"INFO","message":"Server started","port":8080,...}
/// ```
///
/// ## Error Reporting Integration
///
/// Stack traces are automatically appended to the message field for
/// Google Error Reporting to pick them up:
///
/// ```dart
/// try {
///   throw Exception('Something went wrong');
/// } catch (e, stackTrace) {
///   Chirp.error('Operation failed', error: e, stackTrace: stackTrace);
/// }
/// ```
///
/// References:
/// - https://cloud.google.com/logging/docs/structured-logging
/// - https://cloud.google.com/logging/docs/reference/v2/rest/v2/LogEntry
/// - https://cloud.google.com/logging/docs/agent/logging/configuration#special-fields
/// - https://cloud.google.com/error-reporting/docs/formatting-error-messages
class GcpMessageFormatter extends ChirpFormatter {
  /// GCP project ID for trace correlation.
  ///
  /// Required for trace links to work in Cloud Logging. When set, trace IDs
  /// are formatted as `projects/[projectId]/traces/[traceId]`.
  final String? projectId;

  /// Whether to include source location in log entries.
  ///
  /// When true (default), adds `logging.googleapis.com/sourceLocation` with
  /// `file`, `line`, and `function` fields extracted from the caller stack trace.
  final bool includeSourceLocation;

  /// Whether to report errors to Google Error Reporting.
  ///
  /// When true (default), errors and stack traces are formatted in a way that
  /// Google Error Reporting can parse:
  /// - Stack traces are appended to the `message` field
  /// - For ERROR/CRITICAL without stack traces, adds `@type` field
  ///
  /// See: https://cloud.google.com/error-reporting/docs/formatting-error-messages
  final bool enableErrorReporting;

  /// Service name for Error Reporting context.
  final String? serviceName;

  /// Service version for Error Reporting context.
  final String? serviceVersion;

  /// Controls which timestamp(s) to include in log entries.
  ///
  /// - [TimeDisplay.clock]: Include only `timestamp` (from injectable clock)
  /// - [TimeDisplay.wallClock]: Include only `wallClock` (real system time)
  /// - [TimeDisplay.both] or [TimeDisplay.auto]: Include both timestamps
  /// - [TimeDisplay.off]: Include no timestamps
  final TimeDisplay timeDisplay;

  /// Creates a GCP-compatible JSON message formatter.
  GcpMessageFormatter({
    this.projectId,
    this.includeSourceLocation = true,
    this.enableErrorReporting = true,
    this.serviceName,
    this.serviceVersion,
    this.timeDisplay = TimeDisplay.auto,
  }) : super();

  @override
  bool get requiresCallerInfo => includeSourceLocation;

  @override
  void format(LogRecord record, MessageBuffer buffer) {
    final data = record.data;
    final map = <String, dynamic>{};

    // === Required fields ===
    map['severity'] = _gcpSeverity(record.level);

    // === Message with optional stack trace for Error Reporting ===
    // Error Reporting requires stack traces to be in the message field
    // See: https://cloud.google.com/error-reporting/docs/formatting-error-messages
    final messageBuffer = StringBuffer();
    if (record.message != null) {
      messageBuffer.write(record.message);
    }

    // Append error and stack trace to message for Error Reporting
    if (record.error != null) {
      if (messageBuffer.isNotEmpty) messageBuffer.write('\n');
      messageBuffer.write(record.error);
    }
    if (record.stackTrace != null) {
      if (messageBuffer.isNotEmpty) messageBuffer.write('\n');
      messageBuffer.write(record.stackTrace);
    }

    map['message'] = messageBuffer.toString();

    // === Timestamp (ISO8601 with timezone) ===
    switch (timeDisplay) {
      case TimeDisplay.clock:
        map['timestamp'] = record.timestamp.toUtc().toIso8601String();
      case TimeDisplay.wallClock:
        map['timestamp'] = record.wallClock.toUtc().toIso8601String();
      case TimeDisplay.both:
      case TimeDisplay.auto:
        map['timestamp'] = record.wallClock.toUtc().toIso8601String();
        map['clockTime'] = record.timestamp.toUtc().toIso8601String();
      case TimeDisplay.off:
        break;
    }

    // === Source Location ===
    // https://cloud.google.com/logging/docs/agent/logging/configuration#special-fields
    if (includeSourceLocation && record.caller != null) {
      final callerInfo =
          getCallerInfo(record.caller!, skipFrames: record.skipFrames ?? 0);
      if (callerInfo != null) {
        map['logging.googleapis.com/sourceLocation'] = {
          'file': callerInfo.packageRelativePath,
          'line': callerInfo.line.toString(),
          'function': callerInfo.callerMethod,
        };
      }
    }

    // === Labels ===
    // https://cloud.google.com/logging/docs/agent/logging/configuration#special-fields
    final labels = <String, String>{};
    if (record.loggerName != null) {
      labels['logger'] = record.loggerName!;
    }

    // Class (from instance or caller)
    final className = () {
      if (record.instance != null) {
        return record.instance.runtimeType.toString();
      }
      if (includeSourceLocation && record.caller != null) {
        final callerInfo =
            getCallerInfo(record.caller!, skipFrames: record.skipFrames ?? 0);
        return callerInfo?.callerClassName;
      }
      return null;
    }();
    if (className != null) {
      labels['class'] = className;
    }

    // Instance (ClassName@hash, only when instance object is present)
    if (record.instance != null && record.instanceHash != null) {
      final hashHex = record.instanceHash!.toRadixString(16).padLeft(8, '0');
      final hash =
          hashHex.length > 8 ? hashHex.substring(hashHex.length - 8) : hashHex;
      labels['instance'] = '$className@$hash';
    }

    if (labels.isNotEmpty) {
      map['logging.googleapis.com/labels'] = labels;
    }

    // === Error Reporting @type field ===
    // For ERROR+ logs without stack traces, add @type to ensure Error Reporting processes them
    // https://cloud.google.com/error-reporting/docs/formatting-error-messages
    if (enableErrorReporting &&
        _shouldReportError(record.level) &&
        record.stackTrace == null) {
      map['@type'] =
          'type.googleapis.com/google.devtools.clouderrorreporting.v1beta1.ReportedErrorEvent';

      // Add serviceContext only when serviceName is configured
      // https://cloud.google.com/error-reporting/reference/rest/v1beta1/ServiceContext
      if (serviceName != null) {
        map['serviceContext'] = {
          'service': serviceName,
          if (serviceVersion != null) 'version': serviceVersion,
        };
      }

      // Add reportLocation if we have caller info but no stack trace
      if (includeSourceLocation && record.caller != null) {
        final callerInfo =
            getCallerInfo(record.caller!, skipFrames: record.skipFrames ?? 0);
        if (callerInfo != null) {
          map['context'] = {
            'reportLocation': {
              'filePath': callerInfo.packageRelativePath,
              'lineNumber': callerInfo.line,
              'functionName': callerInfo.callerMethod,
            },
          };
        }
      }
    }

    // === httpRequest field (GCP special field) ===
    // https://cloud.google.com/logging/docs/reference/v2/rest/v2/LogEntry#HttpRequest
    final httpRequest = _buildHttpRequest(data);
    if (httpRequest != null) {
      map['httpRequest'] = httpRequest;
    }

    // === Custom data fields ===
    // Merge data fields at root level (GCP jsonPayload)
    for (final kv in data.entries) {
      // Don't overwrite core fields (severity, message, timestamp)
      if (_coreFields.contains(kv.key)) continue;
      // Skip request/response objects that were converted to httpRequest
      if (kv.key == 'request' && _isShelfRequest(kv.value)) continue;
      if (kv.key == 'response' && _isShelfResponse(kv.value)) continue;
      // User-provided logging.googleapis.com/* fields override formatter defaults
      map[kv.key] = kv.value;
    }

    // Output as single-line JSON (required for Cloud Logging agent)
    buffer.write(jsonEncode(map, toEncodable: _toEncodable));
  }
}

/// Core fields that should never be overwritten by user data.
const _coreFields = {'severity', 'message', 'timestamp'};

/// Converts non-JSON-serializable objects to strings.
///
/// Called by [jsonEncode] when encountering objects that don't have a
/// `toJson()` method. Falls back to `toString()` to ensure logging never
/// fails due to non-serializable data.
Object? _toEncodable(Object? object) {
  return object?.toString();
}

/// Maps a ChirpLogLevel to GCP-compatible severity string.
///
/// GCP LogSeverity specification:
/// https://cloud.google.com/logging/docs/reference/v2/rest/v2/LogEntry#LogSeverity
String _gcpSeverity(ChirpLogLevel level) {
  if (level.severity >= 800) return 'EMERGENCY';
  if (level.severity >= 700) return 'ALERT';
  if (level.severity >= 600) return 'CRITICAL';
  if (level.severity >= 500) return 'ERROR';
  if (level.severity >= 400) return 'WARNING';
  if (level.severity >= 300) return 'NOTICE';
  if (level.severity >= 200) return 'INFO';
  if (level.severity >= 100) return 'DEBUG';
  return 'DEFAULT';
}

/// Checks if the severity level should trigger Error Reporting.
bool _shouldReportError(ChirpLogLevel level) {
  return level.severity >= ChirpLogLevel.error.severity;
}

/// Builds the GCP httpRequest field from shelf Request/Response objects in data.
///
/// Uses duck typing to detect shelf objects without requiring the shelf package
/// as a dependency. Looks for 'request' and 'response' keys in data and extracts
/// HTTP metadata into the GCP httpRequest format.
///
/// See: https://cloud.google.com/logging/docs/reference/v2/rest/v2/LogEntry#HttpRequest
Map<String, dynamic>? _buildHttpRequest(Map<String, dynamic> data) {
  final request = data['request'];
  final response = data['response'];

  if (!_isShelfRequest(request) && !_isShelfResponse(response)) {
    return null;
  }

  final httpRequest = <String, dynamic>{};

  // Extract from request (duck typing)
  if (_isShelfRequest(request)) {
    final dynamic req = request;
    httpRequest['requestMethod'] = req.method as String;
    final Uri requestedUri = req.requestedUri as Uri;
    httpRequest['requestUrl'] = requestedUri.toString();

    // Protocol version (shelf uses '1.0' or '1.1')
    final String? protocolVersion = req.protocolVersion as String?;
    if (protocolVersion != null) {
      httpRequest['protocol'] = 'HTTP/$protocolVersion';
    }

    // Content length from request
    final int? contentLength = req.contentLength as int?;
    if (contentLength != null && contentLength > 0) {
      httpRequest['requestSize'] = contentLength.toString();
    }

    // Headers - extract userAgent and referer (the only header fields in httpRequest)
    final dynamic headers = req.headers;
    if (headers != null) {
      final String? userAgent = headers['user-agent'] as String?;
      if (userAgent != null) {
        httpRequest['userAgent'] = userAgent;
      }
      final String? referer = headers['referer'] as String?;
      if (referer != null) {
        httpRequest['referer'] = referer;
      }
      // remoteIp is often in x-forwarded-for header
      final String? forwardedFor = headers['x-forwarded-for'] as String?;
      if (forwardedFor != null) {
        // Take the first IP if there are multiple
        httpRequest['remoteIp'] = forwardedFor.split(',').first.trim();
      }
    }
  }

  // Extract from response (duck typing)
  if (_isShelfResponse(response)) {
    final dynamic resp = response;
    httpRequest['status'] = resp.statusCode as int;

    // Content length from response
    final int? contentLength = resp.contentLength as int?;
    if (contentLength != null && contentLength > 0) {
      httpRequest['responseSize'] = contentLength.toString();
    }
  }

  // Extract latency if provided as 'durationMs' in data
  final durationMs = data['durationMs'];
  if (durationMs is int) {
    // GCP expects duration as string like "0.123s"
    httpRequest['latency'] = '${durationMs / 1000}s';
  }

  return httpRequest.isEmpty ? null : httpRequest;
}

/// Checks if an object looks like a shelf Request using duck typing.
///
/// Checks for the presence of typical shelf Request properties:
/// - method (String)
/// - requestedUri (Uri)
/// - headers (Map-like)
bool _isShelfRequest(Object? obj) {
  if (obj == null) return false;
  try {
    final dynamic d = obj;
    // Check for essential Request properties
    final method = d.method;
    final uri = d.requestedUri;
    return method is String && uri is Uri;
  } catch (_) {
    return false;
  }
}

/// Checks if an object looks like a shelf Response using duck typing.
///
/// Checks for the presence of typical shelf Response properties:
/// - statusCode (int)
bool _isShelfResponse(Object? obj) {
  if (obj == null) return false;
  try {
    final dynamic d = obj;
    // Check for essential Response properties
    final statusCode = d.statusCode;
    return statusCode is int;
  } catch (_) {
    return false;
  }
}
