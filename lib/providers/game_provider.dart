import 'dart:async';
import 'package:flutter/material.dart';
import '../models/game.dart';
import '../models/invite.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class GameProvider extends ChangeNotifier {
  final ApiService api;
  final SocketService socket;

  GameModel? _currentGame;
  List<InviteModel> _pendingInvites = [];
  bool _isConnected = false;
  Set<String> _onlineUserIds = {};
  String? _error;
  Timer? _timerTick;

  Map<String, dynamic>? _gameOverInfo;
  Map<String, dynamic>? _restartRequest;
  Map<String, dynamic>? _disconnectInfo;
  bool _listenersSetup = false;
  bool _isReconnecting = false;

  GameProvider({required this.api, required this.socket});

  GameModel? get currentGame => _currentGame;
  List<InviteModel> get pendingInvites => _pendingInvites;
  bool get isConnected => _isConnected;
  Set<String> get onlineUserIds => _onlineUserIds;
  String? get error => _error;
  Map<String, dynamic>? get gameOverInfo => _gameOverInfo;
  Map<String, dynamic>? get restartRequest => _restartRequest;
  Map<String, dynamic>? get disconnectInfo => _disconnectInfo;
  bool get isReconnecting => _isReconnecting;

  void setupListeners() {
    if (_listenersSetup) return;
    _listenersSetup = true;

    socket.addConnectionListener((connected) {
      _isConnected = connected;
      if (connected && _currentGame != null) {
        socket.emit('join_game', {'gameId': _currentGame!.id});
        _reloadCurrentGameState();
        _startTimerTick();
      }
      notifyListeners();
    });
    _isConnected = socket.isConnected;

    socket.on('invite_received', (data) {
      _pendingInvites.add(
          InviteModel.fromJson(data as Map<String, dynamic>));
      notifyListeners();
    });

    socket.on('invite_declined', (data) {
      final d = data as Map<String, dynamic>;
      _error = '${d['byUsername']} declined your invite';
      notifyListeners();
      _autoClearError();
    });

    socket.on('game_started', (data) {
      _currentGame = GameModel.fromJson(data as Map<String, dynamic>);
      _gameOverInfo = null;
      _restartRequest = null;
      _disconnectInfo = null;
      _startTimerTick();
      notifyListeners();
    });

    socket.on('game_state', (data) {
      _currentGame = GameModel.fromJson(data as Map<String, dynamic>);
      notifyListeners();
    });

    socket.on('game_over', (data) {
      _gameOverInfo = Map<String, dynamic>.from(data as Map);
      _stopTimerTick();
      notifyListeners();
    });

    socket.on('move_rejected', (data) {
      final d = data as Map<String, dynamic>;
      _error = 'Move rejected: ${d['reason']}';
      notifyListeners();
      _autoClearError();
    });

    socket.on('restart_requested', (data) {
      _restartRequest = Map<String, dynamic>.from(data as Map);
      notifyListeners();
    });

    socket.on('restart_cancelled', (data) {
      _restartRequest = null;
      notifyListeners();
    });

    socket.on('game_restarted', (data) {
      _restartRequest = null;
      _gameOverInfo = null;
      _disconnectInfo = null;
      _startTimerTick();
      notifyListeners();
    });

    socket.on('opponent_disconnected', (data) {
      _disconnectInfo = Map<String, dynamic>.from(data as Map);
      notifyListeners();
    });

    socket.on('opponent_reconnected', (data) {
      _disconnectInfo = null;
      _error = null;
      notifyListeners();
    });

    socket.on('error', (data) {
      final d = data as Map<String, dynamic>;
      _error = d['message'] as String?;
      _reloadCurrentGameState();
      notifyListeners();
      _autoClearError();
    });

    socket.on('pending_invites', (data) {
      _pendingInvites = (data as List)
          .map((d) => InviteModel.fromJson(d as Map<String, dynamic>))
          .toList();
      notifyListeners();
    });

    socket.on('online_users', (data) {
      final map = data as Map<String, dynamic>;
      final ids = map['userIds'] as List? ?? [];
      _onlineUserIds = ids.map((e) => e.toString()).toSet();
      notifyListeners();
    });

    socket.emit('get_pending_invites');
    socket.emit('get_online_users');
  }

  void sendInvite(String toUserId, int timeControl) {
    socket.emit('send_invite', {
      'toUserId': toUserId,
      'timeControl': timeControl,
    });
  }

  void acceptInvite(String inviteId) {
    socket.emit('accept_invite', {'inviteId': inviteId});
    _pendingInvites.removeWhere((i) => i.id == inviteId);
    notifyListeners();
  }

  void declineInvite(String inviteId) {
    socket.emit('decline_invite', {'inviteId': inviteId});
    _pendingInvites.removeWhere((i) => i.id == inviteId);
    notifyListeners();
  }

  void joinGame(String gameId) {
    socket.emit('join_game', {'gameId': gameId});
    _gameOverInfo = null;
    _restartRequest = null;
    _disconnectInfo = null;
    _startTimerTick();
  }

  void makeMove(int position) {
    if (_currentGame == null) return;
    socket.emit('make_move', {
      'gameId': _currentGame!.id,
      'position': position,
    });
  }

  void requestRestart() {
    if (_currentGame == null) return;
    socket.emit('request_restart', {'gameId': _currentGame!.id});
  }

  void acceptRestart() {
    if (_currentGame == null) return;
    socket.emit('accept_restart', {'gameId': _currentGame!.id});
    _restartRequest = null;
    notifyListeners();
  }

  void declineRestart() {
    if (_currentGame == null) return;
    socket.emit('decline_restart', {'gameId': _currentGame!.id});
    _restartRequest = null;
    notifyListeners();
  }

  void _startTimerTick() {
    _stopTimerTick();
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_currentGame != null &&
          _currentGame!.status == 'playing' &&
          !_currentGame!.paused) {
        socket.emit('check_timer', {'gameId': _currentGame!.id});
      }
    });
  }

  void _stopTimerTick() {
    _timerTick?.cancel();
    _timerTick = null;
  }

  void leaveGame() {
    _currentGame = null;
    _gameOverInfo = null;
    _restartRequest = null;
    _disconnectInfo = null;
    _stopTimerTick();
    notifyListeners();
  }

  Future<void> _reloadCurrentGameState() async {
    final gameId = _currentGame?.id;
    if (gameId == null) return;
    try {
      final game = await api.getGame(gameId);
      _currentGame = GameModel.fromJson(game);
      notifyListeners();
    } catch (_) {
      // Keep current local state when reload fails.
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearGameOver() {
    _gameOverInfo = null;
    notifyListeners();
  }

  Future<void> reconnectNow() async {
    if (_isReconnecting) return;
    _isReconnecting = true;
    _error = null;
    notifyListeners();
    try {
      await socket.reconnectNow();
      if (_currentGame != null) {
        socket.emit('join_game', {'gameId': _currentGame!.id});
        await _reloadCurrentGameState();
        _startTimerTick();
      }
    } catch (_) {
      _error = 'Reconnect failed. Please try again.';
      _autoClearError();
    } finally {
      _isReconnecting = false;
      notifyListeners();
    }
  }

  void _autoClearError() {
    Future.delayed(const Duration(seconds: 4), () {
      if (_error != null) {
        _error = null;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _stopTimerTick();
    super.dispose();
  }
}
