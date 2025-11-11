GCP Cloud Logging (9 levels, 0-800)

1. DEFAULT (0) - No assigned severity
2. DEBUG (100) - Debug or trace information
3. INFO (200) - Routine information
4. NOTICE (300) - Normal but significant events
5. WARNING (400) - Warning events
6. ERROR (500) - Error events
7. CRITICAL (600) - Critical events
8. ALERT (700) - Action required immediately
9. EMERGENCY (800) - System unusable

  ---
Sentry / OpenTelemetry (6 levels, 1-24)

1. trace (1-4, default: 1) - Fine-grained debugging
2. debug (5-8, default: 5) - General debugging
3. info (9-12, default: 9) - Informational events
4. warn (13-16, default: 13) - Warnings
5. error (17-20, default: 17) - Errors
6. fatal (21-24, default: 21) - Fatal errors/crashes

  ---
Firebase Crashlytics / Android Log

Android Priority Levels:
1. VERBOSE (2) - Verbose (typically filtered)
2. DEBUG (3) - Debug (typically filtered)
3. INFO (4) - Info (typically filtered)
4. WARN (5) - Warning
5. ERROR (6) - Error
6. ASSERT (7) - Assert/Fatal

Crashlytics Categories:
- Fatal Crashes
- Non-Fatal Exceptions
- Debug Logs

  ---
DataDog (Syslog) (8 levels, 0-7)

1. Emergency (0) - System unusable
2. Alert (1) - Action must be taken immediately
3. Critical (2) - Critical conditions
4. Error (3) - Error conditions
5. Warning (4) - Warning conditions
6. Notice (5) - Normal but significant
7. Informational/Info (6) - Informational messages
8. Debug (7) - Debug-level messages

  ---
New Relic (6 levels)

1. TRACE - Most detailed tracing
2. DEBUG - Diagnostic information
3. INFO - Generally useful information (default)
4. WARNING/WARN - Potentially problematic
5. ERROR - Error conditions
6. FATAL/CRITICAL - System crash

  ---
Elastic / Log4j (7 levels)

1. TRACE (5000) - Most detailed
2. DEBUG (10000) - Debug information
3. INFO (20000) - Informational (default)
4. WARN (30000) - Warning conditions
5. ERROR (40000) - Error conditions
6. FATAL (50000) - Most severe
7. ALL (Integer.MIN_VALUE) - Special: log everything
8. OFF (Integer.MAX_VALUE) - Special: log nothing

  ---
AWS CloudWatch (6 application levels)

1. TRACE - Fine-grained execution path
2. DEBUG - Detailed system debugging
3. INFO - Normal operation (default)
4. WARN - Potential error warnings
5. ERROR - Code execution problems
6. FATAL - Serious errors halting application

System Levels (3):
- DEBUG
- INFO
- WARN

  ---
Splunk (8 levels, most to least verbose)

1. DEBUG (7) - Most verbose
2. INFO (6)
3. NOTICE (5)
4. WARN (4)
5. ERROR (3)
6. CRIT (2) - Critical
7. ALERT (1)
8. FATAL (0) - Least verbose
9. EMERG (0) - Emergency (same as FATAL)

  ---
Syslog Standard (RFC 3164/5424) (8 levels, 0-7)

1. Emergency (0) - System is unusable
2. Alert (1) - Action must be taken immediately
3. Critical (2) - Critical conditions
4. Error (3) - Error conditions
5. Warning (4) - Warning conditions
6. Notice (5) - Normal but significant
7. Informational (6) - Informational messages
8. Debug (7) - Debug-level messages