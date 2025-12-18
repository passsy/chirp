/// Example: Interceptors for transforming and filtering logs.
///
/// Run with: dart run bin/interceptors.dart
import 'package:chirp/chirp.dart';

void main() {
  Chirp.root = ChirpLogger()
      .addInterceptor(RedactSecretsInterceptor())
      .addInterceptor(AddHostnameInterceptor())
      .addConsoleWriter();

  // Sensitive data is automatically redacted
  Chirp.info(
    'User login',
    data: {
      'username': 'alice',
      'password': 'super_secret_123', // Will be redacted
      'token': 'jwt_token_here', // Will be redacted
    },
  );

  // Hostname is automatically added to all logs
  Chirp.info('Request processed');
}

/// Redacts sensitive fields from log data.
class RedactSecretsInterceptor implements ChirpInterceptor {
  static const _sensitiveKeys = ['password', 'token', 'secret', 'apiKey'];

  @override
  bool get requiresCallerInfo => false;

  @override
  LogRecord? intercept(LogRecord record) {
    final data = record.data;
    if (data.isEmpty) return record;

    final redacted = Map<String, Object?>.from(data);
    var changed = false;

    for (final key in _sensitiveKeys) {
      if (redacted.containsKey(key)) {
        redacted[key] = '***REDACTED***';
        changed = true;
      }
    }

    if (!changed) return record;

    return record.copyWith(data: redacted);
  }
}

/// Adds hostname to all log records.
class AddHostnameInterceptor implements ChirpInterceptor {
  @override
  bool get requiresCallerInfo => false;

  @override
  LogRecord? intercept(LogRecord record) {
    return record.copyWith(data: {...record.data, 'host': 'server-01'});
  }
}

// Output:
// 14:32:05.123 [info] User login (username: "alice", password: "***REDACTED***", token: "***REDACTED***", host: "server-01")
// 14:32:05.124 [info] Request processed (host: "server-01")
