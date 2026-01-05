import 'dart:io';

import 'package:chirp/chirp.dart';
import 'package:chirp/chirp_spans.dart';
import 'package:shelf/shelf.dart';

extension RequestLogger on Request {
  ChirpLogger get logger {
    final logger = context['request_logger'] as ChirpLogger?;
    return logger!;
  }
}

/// Middleware that creates a request-scoped logger and logs request/response.
///
/// When [gcpProjectId] is provided (or auto-detected from environment),
/// trace context is extracted from the `X-Cloud-Trace-Context` header and
/// added to log entries for correlation in Google Cloud Logging.
///
/// The project ID is auto-detected from these environment variables:
/// - `GOOGLE_CLOUD_PROJECT` (Cloud Run, Cloud Functions)
/// - `GCLOUD_PROJECT` (legacy)
///
/// Set [gcpProjectId] to an empty string to disable auto-detection.
Middleware requestLoggingMiddleware({
  bool logRequestStart = false,
  bool logRequestEnd = true,
  ChirpLogger? logger,
  String? gcpProjectId,
}) {
  if (logger == null) {
    logger = ChirpLogger(name: 'DefaultRequestLogger')
        .addConsoleWriter(formatter: RequestFormatter());
  }

  // Auto-detect GCP project ID from environment if not provided
  final effectiveProjectId = gcpProjectId ?? _getGcpProjectIdFromEnv();

  return (Handler innerHandler) {
    return (Request request) async {
      final requestId = _generateRequestId();
      final stopwatch = Stopwatch()..start();

      // Extract GCP trace context from headers
      final traceContext = effectiveProjectId != null
          ? _extractGcpTraceContext(request, effectiveProjectId)
          : <String, dynamic>{};

      final requestLogger = logger!.child(
        name: 'RequestLogger',
        context: {
          'requestId': requestId,
          'request': request,
          ...traceContext,
        },
      );

      if (logRequestStart) {
        requestLogger.info('request start');
      }
      try {
        request = request.change(context: {
          'request_logger': requestLogger,
        });
        // Run the handler in a zone with the request logger
        final response = await innerHandler(request);

        stopwatch.stop();

        if (logRequestEnd) {
          requestLogger.info('request finish', data: {
            'response': response,
            'durationMs': stopwatch.elapsedMilliseconds,
          }, formatOptions: [
            if (logRequestStart) _AlreadyLoggedRequestStart(),
          ]);
        }

        return response;
      } catch (e, stackTrace) {
        stopwatch.stop();

        requestLogger.error('Request fail with exception',
            error: e, stackTrace: stackTrace);
        requestLogger.error(
          'request error',
          error: e,
          stackTrace: stackTrace,
          data: {'durationMs': stopwatch.elapsedMilliseconds},
        );

        return Response.internalServerError(
          body: 'Internal Server Error',
        );
      }
    };
  };
}

class _AlreadyLoggedRequestStart extends FormatOptions {}

/// Returns the GCP project ID from environment variables, or null if not found.
///
/// Checks these environment variables in order:
/// - `GOOGLE_CLOUD_PROJECT` (Cloud Run, Cloud Functions, App Engine)
/// - `GCLOUD_PROJECT` (legacy)
String? _getGcpProjectIdFromEnv() {
  return Platform.environment['GOOGLE_CLOUD_PROJECT'] ??
      Platform.environment['GCLOUD_PROJECT'];
}

/// Extracts GCP trace context from the `X-Cloud-Trace-Context` header.
///
/// Header format: `TRACE_ID/SPAN_ID;o=TRACE_TRUE`
/// - TRACE_ID: 32-character hex string
/// - SPAN_ID: decimal number (optional)
/// - TRACE_TRUE: 0 or 1 indicating if trace is sampled (optional)
///
/// See: https://cloud.google.com/trace/docs/setup#force-trace
Map<String, dynamic> _extractGcpTraceContext(Request request, String projectId) {
  final header = request.headers['x-cloud-trace-context'];
  if (header == null || header.isEmpty) {
    return {};
  }

  final context = <String, dynamic>{};

  // Parse: TRACE_ID/SPAN_ID;o=TRACE_TRUE
  // Examples:
  //   "105445aa7843bc8bf206b120001000/1;o=1"
  //   "105445aa7843bc8bf206b120001000/1"
  //   "105445aa7843bc8bf206b120001000"
  final parts = header.split(';');
  final tracePart = parts[0];

  final traceSpanParts = tracePart.split('/');
  final traceId = traceSpanParts[0];

  if (traceId.isNotEmpty) {
    context['logging.googleapis.com/trace'] =
        'projects/$projectId/traces/$traceId';
  }

  if (traceSpanParts.length > 1) {
    final spanIdDecimal = traceSpanParts[1];
    // Convert decimal span ID to hex (GCP expects hex in logs)
    final spanIdInt = int.tryParse(spanIdDecimal);
    if (spanIdInt != null) {
      context['logging.googleapis.com/spanId'] =
          spanIdInt.toRadixString(16).padLeft(16, '0');
    }
  }

  // Parse trace sampled flag
  if (parts.length > 1) {
    final optionsPart = parts[1];
    if (optionsPart.startsWith('o=')) {
      final sampled = optionsPart.substring(2) == '1';
      context['logging.googleapis.com/trace_sampled'] = sampled;
    }
  }

  return context;
}

/// Generates a simple request ID.
String _generateRequestId() {
  final timeString = Object().hashCode.toRadixString(36);
  final len = timeString.length;
  if (len <= 5) {
    return timeString.padLeft(5, '0');
  }
  return timeString.substring(len - 5, len);
}

class RequestFormatter extends SpanBasedFormatter {
  @override
  LogSpan buildSpan(LogRecord record) {
    final request = record.data['request'] as Request?;
    final requestId = record.data['requestId'] as String?;
    final requestColor =
        colorForHash(requestId, saturation: ColorSaturation.low);

    final response = record.data['response'] as Response?;
    final durationMs = record.data['durationMs'] as int?;

    if (record.message == 'request start' ||
        record.message == 'request finish' ||
        record.message == 'request error') {
      final spans = <LogSpan>[];

      spans.add(
        AnsiStyled(
          child: Timestamp(record.timestamp),
          foreground: Ansi256.grey50_244,
        ),
      );

      if (requestId != null) {
        spans.add(Whitespace());
        if (response == null && record.error == null) {
          spans.add(
            AnsiStyled(
              child: PlainText('┌ '),
              foreground: requestColor,
              // foreground: Ansi256.grey50_244,
            ),
          );
        } else {
          spans.add(
            AnsiStyled(
              child: PlainText('└ '),
              foreground: requestColor,
              // foreground: Ansi256.grey50_244,
            ),
          );
        }
        spans.add(
          AnsiStyled(
            child: PlainText(requestId),
            foreground: requestColor,
          ),
        );
      }

      final responseColor = () {
        if (response == null) return DefaultColor();
        if (response.statusCode >= 500) return Ansi256.indianRed_167;
        if (response.statusCode >= 400) return Ansi256.darkGoldenrod_136;
        if (response.statusCode >= 300) return DefaultColor();
        return Ansi256.grey50_244;
      }();

      final bool alreadyLoggedRequestStart =
          record.formatOptions?.any((it) => it is _AlreadyLoggedRequestStart) ??
              false;

      if (request != null && !alreadyLoggedRequestStart) {
        spans.add(Whitespace());
        spans.add(AnsiStyled(
          child: PlainText(''.padRight(8 - request.method.length, '─')),
          foreground: Ansi256.grey50_244,
        ));
        spans.add(Whitespace());
        spans.add(PlainText(request.method));
        spans.add(Whitespace());
        spans.add(
          AnsiStyled(
            child: PlainText(request.requestedUri.path),
            foreground: requestColor,
          ),
        );
      }
      if (response != null) {
        if (alreadyLoggedRequestStart) {
          spans.add(Whitespace());
          spans.add(AnsiStyled(
            child: PlainText('────>'),
            foreground: Ansi256.grey50_244,
          ));
          spans.add(Whitespace());
        } else {
          spans.add(Whitespace());
          spans.add(AnsiStyled(
            child: PlainText('→'),
            foreground: Ansi256.grey50_244,
          ));
          spans.add(Whitespace());
        }

        spans.add(
          AnsiStyled(
            child: PlainText('${response.statusCode}'),
            foreground: responseColor,
          ),
        );
      }

      if (durationMs != null) {
        final color = () {
          if (durationMs >= 1000) return Ansi256.indianRed_167;
          if (durationMs >= 500) return Ansi256.darkGoldenrod_136;
          return Ansi256.grey50_244;
        }();

        spans.add(Whitespace());
        final path = request?.requestedUri.path;
        if (path != null) {
          spans.add(
            AnsiStyled(
              child: PlainText(path),
              foreground: requestColor,
            ),
          );
        }
        spans.add(Whitespace());
        spans.add(AnsiStyled(
          child: PlainText('in'),
          foreground: Ansi256.grey50_244,
        ));
        spans.add(Whitespace());
        spans.add(AnsiStyled(
          child: SpanSequence(children: [
            if (durationMs >= 500) PlainText('⚠ '),
            PlainText('${durationMs}ms'),
          ]),
          foreground: color,
        ));
      }

      spans.add(Whitespace());
      final cleanData = {...record.data}
        ..remove('request')
        ..remove('response')
        ..remove('requestId')
        ..remove('durationMs');
      spans.add(
        AnsiStyled(
          child: Surrounded(
            prefix: PlainText('('),
            child: cleanData.isEmpty ? null : InlineData(cleanData),
            suffix: PlainText(')'),
          ),
          foreground: Ansi256.grey50_244,
        ),
      );

      return SpanSequence(children: spans);
    } else {
      final spans = <LogSpan>[];
      spans.add(
        AnsiStyled(
          child: Timestamp(record.timestamp),
          foreground: Ansi256.grey50_244,
        ),
      );
      spans.add(Whitespace());

      {
        final levelColor = () {
          if (record.level >= ChirpLogLevel.error) return Ansi256.indianRed_167;
          if (record.level >= ChirpLogLevel.warning)
            return Ansi256.darkGoldenrod_136;
          if (record.level >= ChirpLogLevel.success) return Ansi256.green3_34;
          return Ansi256.grey50_244;
        }();

        spans.add(
          AnsiStyled(
            child: PlainText('│'),
            // foreground: Ansi256.grey50_244,
            foreground: requestColor,
          ),
        );
        if (requestId != null) {
          spans.add(Whitespace());
          spans.add(
            AnsiStyled(
              child: PlainText(requestId),
              foreground:
                  colorForHash(requestId, saturation: ColorSaturation.low),
            ),
          );
        }
        spans.add(Whitespace());
        spans.add(
          AnsiStyled(
            child: Aligned(
              align: HorizontalAlign.right,
              child: PlainText('${record.level}'),
              width: 9,
            ),
            foreground: levelColor,
          ),
        );
        spans.add(Whitespace());
      }

      spans.add(PlainText(record.message?.toString() ?? 'null'));

      if (record.error != null) {
        spans.add(NewLine());
        spans.add(
          AnsiStyled(
            child: ErrorSpan(record.error),
            foreground: Ansi256.indianRed_167,
          ),
        );
      }
      if (record.stackTrace != null) {
        spans.add(NewLine());
        spans.add(
          AnsiStyled(
            child: StackTraceSpan(record.stackTrace!),
            foreground: Ansi256.indianRed_167,
          ),
        );
      }

      if (record.data.isNotEmpty) {
        final cleanData = {...record.data}
          ..remove('request')
          ..remove('response')
          ..remove('requestId')
          ..remove('durationMs');
        if (cleanData.isNotEmpty) {
          spans.add(Whitespace());
          spans.add(
            AnsiStyled(
              child: Surrounded(
                prefix: PlainText('('),
                child: InlineData(cleanData),
                suffix: PlainText(')'),
              ),
              foreground: Ansi256.grey50_244,
            ),
          );
        }
      }

      return SpanSequence(children: spans);
    }
  }
}
