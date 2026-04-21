import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'config.dart';

class EmailService {
  final ServerConfig config;
  SmtpServer? _smtpServer;

  EmailService(this.config) {
    if (config.smtpHost != null && config.smtpHost!.isNotEmpty) {
      _smtpServer = SmtpServer(
        config.smtpHost!,
        port: config.smtpPort,
        ssl: config.smtpSecure,
        username: config.smtpUser,
        password: config.smtpPass,
      );
    }
  }

  Future<void> sendVerificationEmail(String email, String token) async {
    final verifyUrl = '${config.baseUrl}/api/auth/verify-email?token=$token';

    if (_smtpServer == null) {
      print('=== EMAIL (dev mode) ===');
      print('To: $email');
      print('Subject: Verify your TicTacToe account');
      print('Verification code: $token');
      print('Link: $verifyUrl');
      print('========================');
      return;
    }

    final message = Message()
      ..from = Address(config.emailFrom, 'TicTacToe')
      ..recipients.add(email)
      ..subject = 'Verify your TicTacToe account'
      ..html = '''
        <h2>Welcome to TicTacToe!</h2>
        <p>Your verification code is: <strong>$token</strong></p>
        <p>Or click: <a href="$verifyUrl">Verify Email</a></p>
        <p>This code expires in 24 hours.</p>
      ''';

    try {
      await send(message, _smtpServer!);
    } catch (e) {
      print('Failed to send verification email: $e');
    }
  }

  Future<void> sendPasswordResetEmail(String email, String token) async {
    if (_smtpServer == null) {
      print('=== EMAIL (dev mode) ===');
      print('To: $email');
      print('Subject: Reset your TicTacToe password');
      print('Reset code: $token');
      print('========================');
      return;
    }

    final message = Message()
      ..from = Address(config.emailFrom, 'TicTacToe')
      ..recipients.add(email)
      ..subject = 'Reset your TicTacToe password'
      ..html = '''
        <h2>Password Reset</h2>
        <p>Your reset code is: <strong>$token</strong></p>
        <p>This code expires in 1 hour.</p>
        <p>If you didn't request this, ignore this email.</p>
      ''';

    try {
      await send(message, _smtpServer!);
    } catch (e) {
      print('Failed to send reset email: $e');
    }
  }
}
