/// Central app configuration. Override apiBaseUrl per build/environment.
class AppConfig {
  /// Use 10.0.2.2 for the Android emulator to reach the host machine.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );
}
