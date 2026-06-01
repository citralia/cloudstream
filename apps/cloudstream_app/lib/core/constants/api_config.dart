/// API configuration.
///
/// In production, the base URL points to the deployed FastAPI backend.
/// For local development without a backend, pass null to use
/// demo mode with fixture data.
class ApiConfig {
  ApiConfig._();

  /// Base URL of the CloudStream FastAPI backend.
  /// e.g. "http://100.112.53.35:8000"
  /// Set to empty string to use demo mode.
  static const String baseUrl = String.fromEnvironment(
    'CLOUDSTREAM_API_URL',
    defaultValue: 'http://100.112.53.35:8001',
  );

  /// Request timeout in seconds.
  static const int timeoutSeconds = 30;

  /// Whether demo mode is active (no backend required).
  static bool get isDemoMode => baseUrl.isEmpty;
}
