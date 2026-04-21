import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'config.dart';

class AuthMiddleware {
  final ServerConfig config;

  AuthMiddleware(this.config);

  String generateToken(String userId, String email) {
    final jwt = JWT({'id': userId, 'email': email});
    return jwt.sign(SecretKey(config.jwtSecret),
        expiresIn: const Duration(days: 7));
  }

  Map<String, dynamic>? verifyToken(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(config.jwtSecret));
      return jwt.payload as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Middleware get middleware {
    return (Handler innerHandler) {
      return (Request request) {
        final authHeader = request.headers['authorization'];
        if (authHeader == null || !authHeader.startsWith('Bearer ')) {
          return Response(401,
              body: jsonEncode({'error': 'Access token required'}),
              headers: {'Content-Type': 'application/json'});
        }

        final token = authHeader.substring(7);
        final payload = verifyToken(token);

        if (payload == null) {
          return Response(403,
              body: jsonEncode({'error': 'Invalid or expired token'}),
              headers: {'Content-Type': 'application/json'});
        }

        final updatedRequest = request.change(context: {
          'userId': payload['id'],
          'email': payload['email'],
        });

        return innerHandler(updatedRequest);
      };
    };
  }
}
