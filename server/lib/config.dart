import 'dart:io';

class ServerConfig {
  final int port;
  final String jwtSecret;
  final String encryptionKey;
  final String dbPath;
  final String? smtpHost;
  final int smtpPort;
  final bool smtpSecure;
  final String? smtpUser;
  final String? smtpPass;
  final String emailFrom;
  final String baseUrl;
  final String firebaseWebApiKey;

  ServerConfig({
    this.port = 3000,
    this.jwtSecret = 'tictactoe-jwt-secret-change-in-prod',
    this.encryptionKey = 'mySecretEncKey32CharactersLong!',
    this.dbPath = 'data/tictactoe.db',
    this.smtpHost,
    this.smtpPort = 587,
    this.smtpSecure = false,
    this.smtpUser,
    this.smtpPass,
    this.emailFrom = 'noreply@tictactoe.game',
    this.baseUrl = 'http://localhost:3000',
    this.firebaseWebApiKey = '',
  });

  factory ServerConfig.fromEnv() {
    return ServerConfig.fromMap(Platform.environment);
  }

  factory ServerConfig.fromMap(Map<String, String> env) {
    return ServerConfig(
      port: int.tryParse(env['PORT'] ?? '') ?? 3000,
      jwtSecret: env['JWT_SECRET'] ??
          'tictactoe-jwt-secret-change-in-prod',
      encryptionKey: env['ENCRYPTION_KEY'] ??
          'mySecretEncKey32CharactersLong!',
      dbPath: env['DB_PATH'] ?? 'data/tictactoe.db',
      smtpHost: env['SMTP_HOST'],
      smtpPort: int.tryParse(env['SMTP_PORT'] ?? '') ?? 587,
      smtpSecure: env['SMTP_SECURE'] == 'true',
      smtpUser: env['SMTP_USER'],
      smtpPass: env['SMTP_PASS'],
      emailFrom: env['EMAIL_FROM'] ?? 'noreply@tictactoe.game',
      baseUrl: env['BASE_URL'] ?? 'http://localhost:3000',
      firebaseWebApiKey: env['FIREBASE_WEB_API_KEY'] ?? '',
    );
  }

  bool get smtpConfigured =>
      (smtpHost?.isNotEmpty ?? false) &&
      (smtpUser?.isNotEmpty ?? false) &&
      (smtpPass?.isNotEmpty ?? false);

  String get emailMode => smtpConfigured ? 'smtp' : 'dev-console';
}
