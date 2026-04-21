import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'database.dart';
import 'encryption.dart';
import 'auth_middleware.dart';
import 'config.dart';

class UserRoutes {
  final DatabaseService db;
  late final EncryptionService _encryption;

  UserRoutes(this.db) {
    _encryption = EncryptionService(
        ServerConfig.fromEnv().encryptionKey);
  }

  Router get router {
    final r = Router();
    r.get('/search', AuthMiddleware(ServerConfig.fromEnv()).middleware(_search));
    return r;
  }

  Future<Response> _search(Request request) async {
    try {
      final query = request.url.queryParameters['query']?.trim() ?? '';
      if (query.length < 2) {
        return _json(400, {'error': 'Search query must be at least 2 characters'});
      }

      final userId = request.context['userId'] as String;
      final allUsers = db.queryAll(
          'SELECT id, username_encrypted, email_encrypted FROM users WHERE id != ?',
          [userId]);

      final results = <Map<String, dynamic>>[];
      final queryLower = query.toLowerCase();

      for (final u in allUsers) {
        final username = _encryption.decrypt(u['username_encrypted'] as String);
        final email = _encryption.decrypt(u['email_encrypted'] as String);

        if (username.toLowerCase().contains(queryLower) ||
            email.toLowerCase().contains(queryLower)) {
          results.add({'id': u['id'], 'username': username});
        }
      }

      return _json(200, {'users': results});
    } catch (e) {
      print('Search error: $e');
      return _json(500, {'error': 'Internal server error'});
    }
  }

  Response _json(int statusCode, Map<String, dynamic> body) {
    return Response(statusCode,
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'});
  }
}
