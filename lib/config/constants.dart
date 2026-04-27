class AppConstants {
  /// Optional production base URL.
  /// Example: --dart-define=SERVER_BASE_URL=https://your-app.onrender.com
  static const String _serverBaseUrl = String.fromEnvironment(
    'SERVER_BASE_URL',
    defaultValue: '',
  );

  /// Local fallback defaults.
  /// Android emulator → 10.0.2.2 maps to host localhost.
  static const String serverHost = '10.0.2.2';
  static const int serverPort = 3000;

  static bool get _hasCustomBaseUrl => _serverBaseUrl.trim().isNotEmpty;

  static String get serverUrl {
    if (_hasCustomBaseUrl) {
      return _serverBaseUrl.trim().replaceAll(RegExp(r'/$'), '');
    }
    return 'http://$serverHost:$serverPort';
  }

  static String get wsUrl {
    if (_hasCustomBaseUrl) {
      final normalized = Uri.parse(serverUrl);
      final wsScheme = normalized.scheme == 'https' ? 'wss' : 'ws';
      return normalized.replace(scheme: wsScheme, path: '/ws').toString();
    }
    return 'ws://$serverHost:$serverPort/ws';
  }

  static String get apiUrl => '$serverUrl/api';

  static const Map<String, int> timeControls = {
    '5 min': 300000,
    '10 min': 600000,
    '15 min': 900000,
  };
}
