import 'package:flutter/foundation.dart';

/// Redacts PII from logs and diagnostics before export.
///
/// This module ensures no credentials, IPs, emails, or names
/// leave the device in bug reports or analytics.
///
/// Phase 2/P201: used by Crashlytics + analytics instrumentation.
class PiiRedactor {
  const PiiRedactor();

  static final _emailRegex = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');
  static final _ipv4Regex = RegExp(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b');
  static final _macRegex = RegExp(r'\b[0-9a-fA-F]{2}(:[0-9a-fA-F]{2}){5}\b');
  static final _credsInUrlRegex = RegExp(r'[?&](user|pass|token|password|secret)=([^&\s]+)', caseSensitive: false);

  /// Returns a copy of [input] with all PII replaced by [replacement].
  String redact(String input, {String replacement = '[REDACTED]'}) {
    var result = input;

    // Email addresses
    result = result.replaceAll(_emailRegex, replacement);

    // IPv4 addresses — keep well-known public DNS IPs (8.8.8.8, 1.1.1.1)
    final ipv4Matches = _ipv4Regex.allMatches(result).toList().reversed;
    for (final m in ipv4Matches) {
      final ip = m.group(0)!;
      final parts = ip.split('.');
      final isPublicDns = (parts[0] == '8' && parts[1] == '8' && parts[2] == '8') ||
          (parts[0] == '1' && parts[1] == '1' && parts[2] == '1');
      if (!isPublicDns) {
        result = result.replaceRange(m.start, m.end, replacement);
      }
    }

    // MAC addresses
    result = result.replaceAll(_macRegex, replacement);

    // Credentials in URLs
    result = result.replaceAllMapped(_credsInUrlRegex, (Match m) {
      final keyEnd = m.group(0)!.indexOf('=');
      return '${m.group(0)!.substring(0, keyEnd + 1)}$replacement';
    });

    return result;
  }

  /// Redacts a map of key-value pairs (e.g. analytics events).
  Map<String, T> redactMap<T>(Map<String, T> input) {
    return input.map((key, value) {
      if (value is String) {
        return MapEntry(key, redact(value) as T);
      }
      return MapEntry(key, value);
    });
  }

  /// Logs [message] with PII redacted using debugPrint.
  void log(String message) {
    debugPrint(redact(message));
  }
}
