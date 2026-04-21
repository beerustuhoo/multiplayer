import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'database.dart';
import 'config.dart';
import 'encryption.dart';
import 'auth_middleware.dart';
import 'game_logic.dart';

class _ConnectedUser {
  final String userId;
  final WebSocket socket;
  _ConnectedUser(this.userId, this.socket);
}

class _DisconnectTimer {
  final String playerId;
  final Timer timer;
  final int startTime;
  _DisconnectTimer(this.playerId, this.timer, this.startTime);
}

class WebSocketHandler {
  final DatabaseService db;
  final ServerConfig config;
  late final AuthMiddleware _auth;
  late final EncryptionService _encryption;
  final _uuid = const Uuid();

  final Map<String, _ConnectedUser> _users = {};
  final Map<String, _DisconnectTimer> _disconnectTimers = {};
  final Map<String, Timer> _restartTimers = {};

  WebSocketHandler(this.db, this.config) {
    _auth = AuthMiddleware(config);
    _encryption = EncryptionService(config.encryptionKey);
  }

  Future<void> handleUpgrade(HttpRequest request) async {
    try {
      final socket = await WebSocketTransformer.upgrade(request);
      _handleConnection(socket);
    } catch (e) {
      print('WebSocket upgrade error: $e');
    }
  }

  void _handleConnection(WebSocket socket) {
    String? userId;
    bool authenticated = false;

    socket.listen(
      (data) {
        try {
          final msg = jsonDecode(data as String) as Map<String, dynamic>;
          final type = msg['type'] as String;
          final payload = msg['data'] as Map<String, dynamic>? ?? {};

          if (!authenticated) {
            if (type == 'authenticate') {
              final token = payload['token'] as String?;
              if (token == null) {
                _send(socket, 'error', {'message': 'Token required'});
                return;
              }
              final decoded = _auth.verifyToken(token);
              if (decoded == null) {
                _send(socket, 'error', {'message': 'Invalid token'});
                socket.close();
                return;
              }
              userId = decoded['id'] as String;
              authenticated = true;
              _users[userId!] = _ConnectedUser(userId!, socket);
              _send(socket, 'authenticated', {'userId': userId});
              _sendOnlineUsers(socket);
              _broadcastOnlineUsers();
              _handleReconnection(userId!);
              _sendPendingInvites(userId!, socket);
              print('WS authenticated: $userId');
            }
            return;
          }

          switch (type) {
            case 'send_invite':
              _handleSendInvite(userId!, socket, payload);
            case 'accept_invite':
              _handleAcceptInvite(userId!, socket, payload);
            case 'decline_invite':
              _handleDeclineInvite(userId!, socket, payload);
            case 'get_pending_invites':
              _sendPendingInvites(userId!, socket);
            case 'join_game':
              _handleJoinGame(userId!, socket, payload);
            case 'make_move':
              _handleMakeMove(userId!, socket, payload);
            case 'request_restart':
              _handleRequestRestart(userId!, socket, payload);
            case 'accept_restart':
              _handleAcceptRestart(userId!, socket, payload);
            case 'decline_restart':
              _handleDeclineRestart(userId!, socket, payload);
            case 'check_timer':
              _handleCheckTimer(userId!, socket, payload);
            case 'get_online_users':
              _sendOnlineUsers(socket);
            default:
              _send(socket, 'error', {'message': 'Unknown message type: $type'});
          }
        } catch (e) {
          print('WS message error: $e');
          _send(socket, 'error', {'message': 'Invalid message format'});
        }
      },
      onDone: () {
        if (userId != null) {
          _handleDisconnect(userId!);
        }
      },
      onError: (e) {
        print('WS error for $userId: $e');
        if (userId != null) {
          _handleDisconnect(userId!);
        }
      },
    );
  }

  // ─── INVITES ────────────────────────────────────────────

  void _handleSendInvite(
      String userId, WebSocket socket, Map<String, dynamic> data) {
    final toUserId = data['toUserId'] as String?;
    final timeControl = (data['timeControl'] as num?)?.toInt() ?? 300000;

    if (toUserId == null) {
      _send(socket, 'error', {'message': 'Target user required'});
      return;
    }

    final target = db.queryOne('SELECT id FROM users WHERE id = ?', [toUserId]);
    if (target == null) {
      _send(socket, 'error', {'message': 'User not found'});
      return;
    }

    final existing = db.queryOne(
        "SELECT id FROM invites WHERE from_user = ? AND to_user = ? AND status = 'pending'",
        [userId, toUserId]);
    if (existing != null) {
      _send(socket, 'error', {'message': 'Invite already sent'});
      return;
    }

    final inviteId = _uuid.v4();
    db.execute(
        'INSERT INTO invites (id, from_user, to_user, time_control) VALUES (?, ?, ?, ?)',
        [inviteId, userId, toUserId, timeControl]);

    final sender =
        db.queryOne('SELECT username_encrypted FROM users WHERE id = ?', [userId]);
    final senderName = _encryption.decrypt(sender!['username_encrypted'] as String);

    _sendToUser(toUserId, 'invite_received', {
      'id': inviteId,
      'fromUserId': userId,
      'fromUsername': senderName,
      'timeControl': timeControl,
    });

    _send(socket, 'invite_sent', {'id': inviteId, 'toUserId': toUserId});
  }

  void _handleAcceptInvite(
      String userId, WebSocket socket, Map<String, dynamic> data) {
    final inviteId = data['inviteId'] as String?;
    if (inviteId == null) return;

    final invite = db.queryOne(
        "SELECT * FROM invites WHERE id = ? AND to_user = ? AND status = 'pending'",
        [inviteId, userId]);
    if (invite == null) {
      _send(socket, 'error', {'message': 'Invite not found or already handled'});
      return;
    }

    db.execute("UPDATE invites SET status = 'accepted' WHERE id = ?", [inviteId]);

    final gameId = _uuid.v4();
    final tc = invite['time_control'] as int;
    final now = DateTime.now().millisecondsSinceEpoch;

    db.execute('''
      INSERT INTO games (id, player_x, player_o, timer_x, timer_o, time_control, last_move_time)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    ''', [gameId, invite['from_user'], invite['to_user'], tc, tc, tc, now]);

    final game = _getGameData(gameId);
    if (game == null) return;

    _sendToUser(invite['from_user'] as String, 'game_started', game);
    _sendToUser(userId, 'game_started', game);
  }

  void _handleDeclineInvite(
      String userId, WebSocket socket, Map<String, dynamic> data) {
    final inviteId = data['inviteId'] as String?;
    if (inviteId == null) return;

    final invite = db.queryOne(
        "SELECT * FROM invites WHERE id = ? AND to_user = ? AND status = 'pending'",
        [inviteId, userId]);
    if (invite == null) return;

    db.execute("UPDATE invites SET status = 'declined' WHERE id = ?", [inviteId]);

    final receiver =
        db.queryOne('SELECT username_encrypted FROM users WHERE id = ?', [userId]);
    final name = _encryption.decrypt(receiver!['username_encrypted'] as String);

    _sendToUser(invite['from_user'] as String, 'invite_declined', {
      'inviteId': inviteId,
      'byUsername': name,
    });
  }

  void _sendPendingInvites(String userId, WebSocket socket) {
    final invites = db.queryAll('''
      SELECT i.*, u.username_encrypted as from_name
      FROM invites i
      JOIN users u ON i.from_user = u.id
      WHERE i.to_user = ? AND i.status = 'pending'
      ORDER BY i.created_at DESC
    ''', [userId]);

    final result = invites
        .map((inv) => {
              'id': inv['id'],
              'fromUserId': inv['from_user'],
              'fromUsername':
                  _encryption.decrypt(inv['from_name'] as String),
              'timeControl': inv['time_control'],
            })
        .toList();

    _send(socket, 'pending_invites', result);
  }

  // ─── GAME ──────────────────────────────────────────────

  void _handleJoinGame(
      String userId, WebSocket socket, Map<String, dynamic> data) {
    final gameId = data['gameId'] as String?;
    if (gameId == null) return;

    final game = _getGameData(gameId);
    if (game != null) {
      _send(socket, 'game_state', game);
    }
  }

  void _handleMakeMove(
      String userId, WebSocket socket, Map<String, dynamic> data) {
    final gameId = data['gameId'] as String?;
    final position = (data['position'] as num?)?.toInt();
    if (gameId == null || position == null) return;

    final game =
        db.queryOne('SELECT * FROM games WHERE id = ?', [gameId]);
    if (game == null) {
      _send(socket, 'error', {'message': 'Game not found'});
      return;
    }

    if (game['status'] != 'playing') {
      _send(socket, 'error', {'message': 'Game is not in progress'});
      return;
    }
    if (game['paused'] == 1) {
      _send(socket, 'error', {'message': 'Game is paused'});
      return;
    }
    if (game['restart_requested_by'] != null) {
      _send(socket, 'error', {'message': 'Game locked - restart pending'});
      return;
    }

    String playerMark;
    if (userId == game['player_x']) {
      playerMark = 'X';
    } else if (userId == game['player_o']) {
      playerMark = 'O';
    } else {
      _send(socket, 'error', {'message': 'Not a player in this game'});
      return;
    }

    final board =
        List<String>.from(jsonDecode(game['board'] as String) as List);
    final currentTurn = game['current_turn'] as String;

    if (!TicTacToeLogic.isValidMove(board, position, currentTurn, playerMark)) {
      _send(socket, 'move_rejected',
          {'position': position, 'reason': 'Invalid move'});
      return;
    }

    // Timer calculation
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastMoveTime = game['last_move_time'] as int? ?? now;
    final elapsed = now - lastMoveTime;
    var timerX = game['timer_x'] as int;
    var timerO = game['timer_o'] as int;

    if (currentTurn == 'X') {
      timerX = (timerX - elapsed).clamp(0, timerX);
    } else {
      timerO = (timerO - elapsed).clamp(0, timerO);
    }

    if ((currentTurn == 'X' && timerX <= 0) ||
        (currentTurn == 'O' && timerO <= 0)) {
      final winner =
          currentTurn == 'X' ? game['player_o'] : game['player_x'];
      db.execute(
          'UPDATE games SET status = ?, winner = ?, timer_x = ?, timer_o = ? WHERE id = ?',
          ['timeout', winner, timerX, timerO, gameId]);
      final updated = _getGameData(gameId)!;
      _broadcastToGame(game, 'game_state', updated);
      _broadcastToGame(game, 'game_over', {'reason': 'timeout', 'winner': winner});
      return;
    }

    final newBoard = TicTacToeLogic.makeMove(board, position, playerMark);
    final moves =
        List<Map<String, dynamic>>.from(jsonDecode(game['moves'] as String) as List);
    moves.add({'player': playerMark, 'position': position, 'timestamp': now});

    final nextTurn = currentTurn == 'X' ? 'O' : 'X';
    final result = TicTacToeLogic.checkWinner(newBoard);

    var status = 'playing';
    String? winner;
    if (result != null) {
      if (result.winner == 'draw') {
        status = 'draw';
      } else {
        status = 'won';
        winner = result.winner == 'X' ? game['player_x'] as String : game['player_o'] as String;
      }
    }

    db.execute('''
      UPDATE games SET board = ?, current_turn = ?, status = ?, winner = ?,
        timer_x = ?, timer_o = ?, last_move_time = ?, moves = ?,
        updated_at = datetime('now')
      WHERE id = ?
    ''', [
      jsonEncode(newBoard), nextTurn, status, winner,
      timerX, timerO, now, jsonEncode(moves), gameId,
    ]);

    final updated = _getGameData(gameId)!;
    _broadcastToGame(game, 'game_state', updated);

    if (result != null) {
      _broadcastToGame(game, 'game_over', {
        'reason': result.winner == 'draw' ? 'draw' : 'win',
        'winner': winner,
        'winningLine': result.winningLine,
      });
    }
  }

  // ─── RESTART ───────────────────────────────────────────

  void _handleRequestRestart(
      String userId, WebSocket socket, Map<String, dynamic> data) {
    final gameId = data['gameId'] as String?;
    if (gameId == null) return;

    final game = db.queryOne('SELECT * FROM games WHERE id = ?', [gameId]);
    if (game == null) return;
    if (game['restart_requested_by'] != null) {
      _send(socket, 'error', {'message': 'Restart already requested'});
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    db.execute('''
      UPDATE games SET restart_requested_by = ?, restart_requested_at = ?,
        paused = 1, pause_reason = 'restart_request' WHERE id = ?
    ''', [userId, now, gameId]);

    final requester =
        db.queryOne('SELECT username_encrypted FROM users WHERE id = ?', [userId]);
    final name = _encryption.decrypt(requester!['username_encrypted'] as String);

    _broadcastToGame(game, 'restart_requested', {
      'gameId': gameId,
      'requestedBy': userId,
      'requestedByName': name,
      'requestedAt': now,
    });

    // 30-second timeout
    _restartTimers[gameId]?.cancel();
    _restartTimers[gameId] = Timer(const Duration(seconds: 30), () {
      final current = db.queryOne('SELECT * FROM games WHERE id = ?', [gameId]);
      if (current != null && current['restart_requested_by'] != null) {
        db.execute('''
          UPDATE games SET restart_requested_by = NULL, restart_requested_at = NULL,
            paused = 0, pause_reason = NULL WHERE id = ?
        ''', [gameId]);
        final updated = _getGameData(gameId)!;
        _broadcastToGame(current, 'restart_cancelled',
            {'gameId': gameId, 'reason': 'timeout'});
        _broadcastToGame(current, 'game_state', updated);
      }
      _restartTimers.remove(gameId);
    });
  }

  void _handleAcceptRestart(
      String userId, WebSocket socket, Map<String, dynamic> data) {
    final gameId = data['gameId'] as String?;
    if (gameId == null) return;

    final game = db.queryOne('SELECT * FROM games WHERE id = ?', [gameId]);
    if (game == null || game['restart_requested_by'] == null) return;

    _restartTimers[gameId]?.cancel();
    _restartTimers.remove(gameId);

    final tc = game['time_control'] as int;
    final now = DateTime.now().millisecondsSinceEpoch;

    db.execute('''
      UPDATE games SET
        board = '["","","","","","","","",""]', current_turn = 'X',
        status = 'playing', winner = NULL,
        timer_x = ?, timer_o = ?, last_move_time = ?,
        moves = '[]', paused = 0, pause_reason = NULL,
        restart_requested_by = NULL, restart_requested_at = NULL,
        updated_at = datetime('now')
      WHERE id = ?
    ''', [tc, tc, now, gameId]);

    final updated = _getGameData(gameId)!;
    _broadcastToGame(game, 'game_restarted', {'gameId': gameId});
    _broadcastToGame(game, 'game_state', updated);
  }

  void _handleDeclineRestart(
      String userId, WebSocket socket, Map<String, dynamic> data) {
    final gameId = data['gameId'] as String?;
    if (gameId == null) return;

    _restartTimers[gameId]?.cancel();
    _restartTimers.remove(gameId);

    db.execute('''
      UPDATE games SET restart_requested_by = NULL, restart_requested_at = NULL,
        paused = 0, pause_reason = NULL WHERE id = ?
    ''', [gameId]);

    final game = db.queryOne('SELECT * FROM games WHERE id = ?', [gameId]);
    if (game == null) return;

    final updated = _getGameData(gameId)!;
    _broadcastToGame(game, 'restart_cancelled',
        {'gameId': gameId, 'reason': 'declined'});
    _broadcastToGame(game, 'game_state', updated);
  }

  // ─── TIMERS ────────────────────────────────────────────

  void _handleCheckTimer(
      String userId, WebSocket socket, Map<String, dynamic> data) {
    final gameId = data['gameId'] as String?;
    if (gameId == null) return;

    final game = db.queryOne('SELECT * FROM games WHERE id = ?', [gameId]);
    if (game == null || game['status'] != 'playing' || game['paused'] == 1) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final lastMoveTime = game['last_move_time'] as int? ?? now;
    final elapsed = now - lastMoveTime;
    var timerX = game['timer_x'] as int;
    var timerO = game['timer_o'] as int;
    final currentTurn = game['current_turn'] as String;

    if (currentTurn == 'X') {
      timerX = (timerX - elapsed).clamp(0, timerX);
    } else {
      timerO = (timerO - elapsed).clamp(0, timerO);
    }

    if (timerX <= 0 || timerO <= 0) {
      final winner = timerX <= 0 ? game['player_o'] : game['player_x'];
      db.execute(
          'UPDATE games SET status = ?, winner = ?, timer_x = ?, timer_o = ? WHERE id = ?',
          ['timeout', winner, timerX.clamp(0, 999999999), timerO.clamp(0, 999999999), gameId]);
      final updated = _getGameData(gameId)!;
      _broadcastToGame(game, 'game_state', updated);
      _broadcastToGame(game, 'game_over', {'reason': 'timeout', 'winner': winner});
    }
  }

  // ─── DISCONNECT / RECONNECT ────────────────────────────

  void _handleDisconnect(String userId) {
    print('WS disconnected: $userId');
    _users.remove(userId);
    _broadcastOnlineUsers();

    final activeGames = db.queryAll('''
      SELECT * FROM games
      WHERE (player_x = ? OR player_o = ?) AND status = 'playing'
    ''', [userId, userId]);

    for (final game in activeGames) {
      final gameId = game['id'] as String;
      final opponentId = userId == game['player_x']
          ? game['player_o'] as String
          : game['player_x'] as String;

      final now = DateTime.now().millisecondsSinceEpoch;
      db.execute(
          'UPDATE games SET paused = 1, pause_reason = ?, pause_start = ? WHERE id = ?',
          ['disconnection', now, gameId]);

      _sendToUser(opponentId, 'opponent_disconnected', {
        'gameId': gameId,
        'disconnectedPlayer': userId,
        'pauseStart': now,
        'timeout': 120000,
      });

      _disconnectTimers[gameId]?.timer.cancel();
      _disconnectTimers[gameId] = _DisconnectTimer(
        userId,
        Timer(const Duration(minutes: 2), () {
          final current =
              db.queryOne('SELECT * FROM games WHERE id = ?', [gameId]);
          if (current != null &&
              current['paused'] == 1 &&
              current['pause_reason'] == 'disconnection') {
            db.execute(
                'UPDATE games SET status = ?, winner = ?, paused = 0, pause_reason = NULL WHERE id = ?',
                ['forfeit', opponentId, gameId]);
            final updated = _getGameData(gameId)!;
            _broadcastToGame(current, 'game_state', updated);
            _broadcastToGame(
                current, 'game_over', {'reason': 'forfeit', 'winner': opponentId});
          }
          _disconnectTimers.remove(gameId);
        }),
        now,
      );
    }
  }

  void _handleReconnection(String userId) {
    final pausedGames = db.queryAll('''
      SELECT * FROM games
      WHERE (player_x = ? OR player_o = ?)
        AND paused = 1 AND pause_reason = 'disconnection'
    ''', [userId, userId]);

    for (final game in pausedGames) {
      final gameId = game['id'] as String;

      final dt = _disconnectTimers[gameId];
      if (dt != null && dt.playerId == userId) {
        dt.timer.cancel();
        _disconnectTimers.remove(gameId);
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      db.execute('''
        UPDATE games SET paused = 0, pause_reason = NULL,
          pause_start = NULL, last_move_time = ? WHERE id = ?
      ''', [now, gameId]);

      final updated = _getGameData(gameId)!;
      _broadcastToGame(
          game, 'opponent_reconnected', {'gameId': gameId, 'reconnectedPlayer': userId});
      _broadcastToGame(game, 'game_state', updated);
    }
  }

  // ─── HELPERS ───────────────────────────────────────────

  Map<String, dynamic>? _getGameData(String gameId) {
    final g = db.queryOne('''
      SELECT g.*,
        ux.username_encrypted as px_name,
        uo.username_encrypted as po_name
      FROM games g
      LEFT JOIN users ux ON g.player_x = ux.id
      LEFT JOIN users uo ON g.player_o = uo.id
      WHERE g.id = ?
    ''', [gameId]);

    if (g == null) return null;

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

  void _send(WebSocket socket, String type, dynamic data) {
    try {
      socket.add(jsonEncode({'type': type, 'data': data}));
    } catch (e) {
      print('Send error: $e');
    }
  }

  void _sendToUser(String userId, String type, dynamic data) {
    final user = _users[userId];
    if (user != null) {
      _send(user.socket, type, data);
    }
  }

  void _broadcastToGame(
      Map<String, dynamic> game, String type, dynamic data) {
    _sendToUser(game['player_x'] as String, type, data);
    _sendToUser(game['player_o'] as String, type, data);
  }

  void _sendOnlineUsers(WebSocket socket) {
    _send(socket, 'online_users', {'userIds': _users.keys.toList()});
  }

  void _broadcastOnlineUsers() {
    final payload = {'userIds': _users.keys.toList()};
    for (final connected in _users.values) {
      _send(connected.socket, 'online_users', payload);
    }
  }
}
