import 'package:flutter_test/flutter_test.dart';
import 'package:cloudstream_app/diagnostics/pii_redaction.dart';

void main() {
  const redactor = PiiRedactor();

  group('PiiRedactor', () {
    test('redacts email addresses', () {
      const input = 'Contact: josh@example.com';
      const expected = 'Contact: [REDACTED]';
      expect(redactor.redact(input), expected);
    });

    test('redacts multiple emails', () {
      const input = 'From: a@b.com to: c@d.org';
      expect(redactor.redact(input), 'From: [REDACTED] to: [REDACTED]');
    });

    test('redacts IPv4 addresses', () {
      const input = 'Server: 192.168.1.100';
      expect(redactor.redact(input), 'Server: [REDACTED]');
    });

    test('does not redact public DNS IPs (8.8.8.8)', () {
      const input = 'DNS: 8.8.8.8';
      expect(redactor.redact(input), 'DNS: 8.8.8.8');
    });

    test('does not redact 1.1.1.1', () {
      const input = 'DNS: 1.1.1.1';
      expect(redactor.redact(input), 'DNS: 1.1.1.1');
    });

    test('redacts credentials in URL query params', () {
      const input = 'GET /api?user=admin&pass=supersecret&token=abc123';
      final result = redactor.redact(input);
      expect(result.contains('supersecret'), false);
      expect(result.contains('pass=supersecret'), false);
      expect(result.contains('token=abc123'), false);
      expect(result.contains('[REDACTED]'), true);
    });

    test('redacts MAC addresses', () {
      const input = 'MAC: aa:bb:cc:dd:ee:ff';
      expect(redactor.redact(input), 'MAC: [REDACTED]');
    });

    test('redactMap applies to string values', () {
      final input = <String, Object>{'url': 'http://user:pass@192.168.1.1/api', 'count': 42};
      final result = redactor.redactMap<Object>(input);
      expect(result['url'], contains('[REDACTED]'));
      expect(result['count'], 42);
    });

    test('returns input unchanged when no PII present', () {
      const input = 'Hello world 123';
      expect(redactor.redact(input), input);
    });
  });
}
