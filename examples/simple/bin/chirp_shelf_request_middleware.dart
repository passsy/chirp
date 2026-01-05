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

  return (Handler innerHandler) {
    return (Request request) async {
      final requestId = _generateRequestId();
      final stopwatch = Stopwatch()..start();

      final requestLogger = logger!.child(
        name: 'RequestLogger',
        context: {
          'requestId': requestId,
          'request': request,
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

        rethrow;
      }
    };
  };
}

class _AlreadyLoggedRequestStart extends FormatOptions {}

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
