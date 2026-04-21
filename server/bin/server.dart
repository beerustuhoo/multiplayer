import 'dart:io';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:tictactoe_server/database.dart';
import 'package:tictactoe_server/auth_routes.dart';
import 'package:tictactoe_server/user_routes.dart';
import 'package:tictactoe_server/game_routes.dart';
import 'package:tictactoe_server/websocket_handler.dart';
import 'package:tictactoe_server/config.dart';

void main(List<String> args) async {
  final mergedEnv = _loadEnv();
  final config = ServerConfig.fromMap(mergedEnv);
  final db = DatabaseService(config.dbPath);
  db.initialize();

  final wsHandler = WebSocketHandler(db, config);

  final router = Router();

  final authRoutes = AuthRoutes(db, config);
  final userRoutes = UserRoutes(db);
  final gameRoutes = GameRoutes(db);

  router.mount('/api/auth/', authRoutes.router.call);
  router.mount('/api/users/', userRoutes.router.call);
  router.mount('/api/games/', gameRoutes.router.call);
  router.get('/api/health', (shelf.Request request) {
    return shelf.Response.ok(
        '{"status":"ok","emailMode":"${config.emailMode}"}',
        headers: {'Content-Type': 'application/json'});
  });

  shelf.Handler handler = const shelf.Pipeline()
      .addMiddleware(shelf.logRequests())
      .addMiddleware(_corsMiddleware())
      .addHandler(router.call);

  final server = await HttpServer.bind('0.0.0.0', config.port);
  print('Server running on port ${config.port}');
  print('Email mode: ${config.emailMode}');
  if (!config.smtpConfigured) {
    print('SMTP not configured. Verification/reset codes will print to console.');
  }

  await for (final request in server) {
    if (request.uri.path == '/ws' &&
        WebSocketTransformer.isUpgradeRequest(request)) {
      wsHandler.handleUpgrade(request);
    } else {
      shelf_io.handleRequest(request, handler);
    }
  }
}

Map<String, String> _loadEnv() {
  final merged = Map<String, String>.from(Platform.environment);
  final envFile = File('.env');
  if (!envFile.existsSync()) return merged;
  final lines = envFile.readAsLinesSync();
  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final sep = line.indexOf('=');
    if (sep <= 0) continue;
    final key = line.substring(0, sep).trim();
    final value = line.substring(sep + 1).trim();
    if (key.isNotEmpty) {
      merged.putIfAbsent(key, () => value);
    }
  }
  return merged;
}

shelf.Middleware _corsMiddleware() {
  return (shelf.Handler innerHandler) {
    return (shelf.Request request) async {
      if (request.method == 'OPTIONS') {
        return shelf.Response.ok('', headers: _corsHeaders);
      }
      final response = await innerHandler(request);
      return response.change(headers: _corsHeaders);
    };
  };
}

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
};
