import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'database.dart';
import 'encryption.dart';
import 'auth_middleware.dart';
import 'config.dart';

class GameRoutes {
  final DatabaseService db;
  late final EncryptionService _encryption;
  late final AuthMiddleware _auth;

  GameRoutes(this.db) {
    final config = ServerConfig.fromEnv();
    _encryption = EncryptionService(config.encryptionKey);
    _auth = AuthMiddleware(config);
  }

  Router get router {
    final r = Router();
    r.get('/', _auth.middleware(_getGames));
    r.get('/<id>', _getGameById);
    return r;
  }

  Future<Response> _getGames(Request request) async {
    try {
      final userId = request.context['userId'] as String;
      final games = db.queryAll('''
        SELECT g.*,
          ux.username_encrypted as px_name,
          uo.username_encrypted as po_name
        FROM games g
        LEFT JOIN users ux ON g.player_x = ux.id
        LEFT JOIN users uo ON g.player_o = uo.id
        WHERE g.player_x = ? OR g.player_o = ?
        ORDER BY g.updated_at DESC
      ''', [userId, userId]);

      final result = games.map((g) => _formatGame(g)).toList();
      return _json(200, {'games': result});
    } catch (e) {
      print('Get games error: $e');
      return _json(500, {'error': 'Internal server error'});
    }
  }

  Future<Response> _getGameById(Request request, String id) async {
    try {
      // Manual auth check for parametric route
      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return _json(401, {'error': 'Access token required'});
      }
      final payload = _auth.verifyToken(authHeader.substring(7));
      if (payload == null) {
        return _json(403, {'error': 'Invalid or expired token'});
      }

      final g = db.queryOne('''
        SELECT g.*,
          ux.username_encrypted as px_name,
          uo.username_encrypted as po_name
        FROM games g
        LEFT JOIN users ux ON g.player_x = ux.id
        LEFT JOIN users uo ON g.player_o = uo.id
        WHERE g.id = ?
      ''', [id]);

      if (g == null) return _json(404, {'error': 'Game not found'});
      return _json(200, {'game': _formatGame(g)});
    } catch (e) {
      print('Get game error: $e');
      return _json(500, {'error': 'Internal server error'});
    }
  }

  Map<String, dynamic> _formatGame(Map<String, dynamic> g) {
    return {
      'id': g['id'],
      'playerX': g['player_x'],
      'playerO': g['player_o'],
      'playerXName': g['px_name'] != null
          ? _encryption.decrypt(g['px_name'] as String)
          : 'Unknown',
      'playerOName': g['po_name'] != null
          ? _encryption.decrypt(g['po_name'] as String)
          : 'Unknown',
      'board': jsonDecode(g['board'] as String),
      'currentTurn': g['current_turn'],
      'status': g['status'],
      'winner': g['winner'],
      'timerX': g['timer_x'],
      'timerO': g['timer_o'],
      'timeControl': g['time_control'],
      'lastMoveTime': g['last_move_time'],
      'moves': jsonDecode(g['moves'] as String),
      'paused': g['paused'] == 1,
      'pauseReason': g['pause_reason'],
      'pauseStart': g['pause_start'],
      'restartRequestedBy': g['restart_requested_by'],
      'restartRequestedAt': g['restart_requested_at'],
    };
  }

  Response _json(int statusCode, Map<String, dynamic> body) {
    return Response(statusCode,
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'});
  }
}
