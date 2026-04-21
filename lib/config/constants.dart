class AppConstants {
  /// Change to your server's IP address.
  /// Android emulator → 10.0.2.2 maps to host localhost.
  /// iOS simulator → 127.0.0.1 works.
  /// Physical device → use your computer's LAN IP.
  static const String serverHost = '10.0.2.2';
  static const int serverPort = 3000;
  static String get serverUrl => 'http://$serverHost:$serverPort';
  static String get wsUrl => 'ws://$serverHost:$serverPort/ws';
  static String get apiUrl => '$serverUrl/api';

  static const Map<String, int> timeControls = {
    '5 min': 300000,
    '10 min': 600000,
    '15 min': 900000,
  };
}
