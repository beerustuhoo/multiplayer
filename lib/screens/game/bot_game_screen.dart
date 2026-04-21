import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/game_board.dart';
import '../../widgets/game_timer.dart';
import '../../widgets/move_history_panel.dart';
import '../../models/game.dart';

class BotGameScreen extends StatefulWidget {
  const BotGameScreen({super.key});

  @override
  State<BotGameScreen> createState() => _BotGameScreenState();
}

class _BotGameScreenState extends State<BotGameScreen> {
  List<String> _board = List.filled(9, '');
  String _currentTurn = 'X'; // Player is X, bot is O
  String _status = 'playing';
  List<int>? _winLine;
  List<GameMove> _moves = [];
  bool _historyOpen = false;
  int _playerTimer = 300000;
  int _botTimer = 300000;
  int _timeControl = 300000;
  int _lastMoveTime = DateTime.now().millisecondsSinceEpoch;
  Timer? _timerTick;
  String? _winner;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timerTick?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timerTick?.cancel();
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_status != 'playing') return;
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsed = now - _lastMoveTime;
      setState(() {
        if (_currentTurn == 'X') {
          _playerTimer = (_timeControl > 0)
              ? (_playerTimer - elapsed).clamp(0, _timeControl)
              : _playerTimer;
        } else {
          _botTimer = (_timeControl > 0)
              ? (_botTimer - elapsed).clamp(0, _timeControl)
              : _botTimer;
        }
        _lastMoveTime = now;

        if (_playerTimer <= 0) {
          _status = 'timeout';
          _winner = 'Bot';
          _timerTick?.cancel();
        } else if (_botTimer <= 0) {
          _status = 'timeout';
          _winner = 'You';
          _timerTick?.cancel();
        }
      });
    });
  }

  void _makeMove(int pos) {
    if (_status != 'playing' || _board[pos].isNotEmpty || _currentTurn != 'X') {
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _board[pos] = 'X';
      _moves.add(GameMove(player: 'X', position: pos, timestamp: now));
      final elapsed = now - _lastMoveTime;
      _playerTimer = (_playerTimer - elapsed).clamp(0, _timeControl);
      _lastMoveTime = now;
    });

    final result = _checkWinner();
    if (result != null) {
      setState(() {
        _status = result == 'draw' ? 'draw' : 'won';
        _winner = result == 'draw' ? null : (result == 'X' ? 'You' : 'Bot');
      });
      _timerTick?.cancel();
      return;
    }

    setState(() => _currentTurn = 'O');

    // Bot moves after short delay
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted || _status != 'playing') return;
      final botPos = _getBotMove();
      if (botPos == null) return;
      final botNow = DateTime.now().millisecondsSinceEpoch;
      setState(() {
        _board[botPos] = 'O';
        _moves.add(GameMove(player: 'O', position: botPos, timestamp: botNow));
        final elapsed = botNow - _lastMoveTime;
        _botTimer = (_botTimer - elapsed).clamp(0, _timeControl);
        _lastMoveTime = botNow;
        _currentTurn = 'X';
      });
      final r2 = _checkWinner();
      if (r2 != null) {
        setState(() {
          _status = r2 == 'draw' ? 'draw' : 'won';
          _winner = r2 == 'draw' ? null : (r2 == 'X' ? 'You' : 'Bot');
        });
        _timerTick?.cancel();
      }
    });
  }

  String? _checkWinner() {
    const lines = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8],
      [0, 3, 6], [1, 4, 7], [2, 5, 8],
      [0, 4, 8], [2, 4, 6],
    ];
    for (final line in lines) {
      final a = _board[line[0]], b = _board[line[1]], c = _board[line[2]];
      if (a.isNotEmpty && a == b && a == c) {
        _winLine = line;
        return a;
      }
    }
    if (_board.every((c) => c.isNotEmpty)) return 'draw';
    return null;
  }

  int? _getBotMove() {
    const botMark = 'O';
    const playerMark = 'X';

    // Win
    for (int i = 0; i < 9; i++) {
      if (_board[i].isEmpty) {
        final t = List<String>.from(_board)..[i] = botMark;
        if (_wouldWin(t, botMark)) return i;
      }
    }
    // Block
    for (int i = 0; i < 9; i++) {
      if (_board[i].isEmpty) {
        final t = List<String>.from(_board)..[i] = playerMark;
        if (_wouldWin(t, playerMark)) return i;
      }
    }
    // Center
    if (_board[4].isEmpty) return 4;
    // Corner
    final corners = [0, 2, 6, 8].where((i) => _board[i].isEmpty).toList();
    if (corners.isNotEmpty) {
      corners.shuffle(Random());
      return corners.first;
    }
    // Any
    final avail = List.generate(9, (i) => i).where((i) => _board[i].isEmpty).toList();
    if (avail.isEmpty) return null;
    avail.shuffle(Random());
    return avail.first;
  }

  bool _wouldWin(List<String> board, String mark) {
    const lines = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8],
      [0, 3, 6], [1, 4, 7], [2, 5, 8],
      [0, 4, 8], [2, 4, 6],
    ];
    for (final l in lines) {
      if (board[l[0]] == mark && board[l[1]] == mark && board[l[2]] == mark) {
        return true;
      }
    }
    return false;
  }

  void _restart() {
    _timerTick?.cancel();
    setState(() {
      _board = List.filled(9, '');
      _currentTurn = 'X';
      _status = 'playing';
      _winLine = null;
      _moves = [];
      _winner = null;
      _playerTimer = _timeControl;
      _botTimer = _timeControl;
      _lastMoveTime = DateTime.now().millisecondsSinceEpoch;
    });
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('vs Bot'),
        actions: [
          IconButton(
            icon: Icon(_historyOpen ? Icons.grid_3x3 : Icons.history),
            onPressed: () => setState(() => _historyOpen = !_historyOpen),
          ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.timer),
            onSelected: (v) {
              setState(() => _timeControl = v);
              _restart();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 300000, child: Text('5 min')),
              const PopupMenuItem(value: 600000, child: Text('10 min')),
              const PopupMenuItem(value: 900000, child: Text('15 min')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: GameTimer(
              remainingMs: _botTimer,
              isActive: _currentTurn == 'O' && _status == 'playing',
              label: 'Bot (O)',
            ),
          ),

          // Status
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _buildStatus(),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _historyOpen
                  ? MoveHistoryPanel(
                      moves: _moves,
                      playerXName: 'You',
                      playerOName: 'Bot',
                    )
                  : Center(
                      child: GameBoard(
                        board: _board,
                        winningLine: _winLine,
                        enabled:
                            _status == 'playing' && _currentTurn == 'X',
                        onCellTap: _makeMove,
                      ),
                    ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: GameTimer(
              remainingMs: _playerTimer,
              isActive: _currentTurn == 'X' && _status == 'playing',
              label: 'You (X)',
              isCurrentUser: true,
            ),
          ),

          if (_status != 'playing')
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.restart_alt),
                label: const Text('Play Again'),
                onPressed: _restart,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatus() {
    if (_status == 'draw') {
      return _statusBanner("It's a draw!", AppTheme.warning);
    }
    if (_status != 'playing') {
      if (_winner == 'You') {
        return _statusBanner('You win!', AppTheme.success);
      }
      return _statusBanner('Bot wins!', AppTheme.error);
    }
    if (_currentTurn == 'X') {
      return _statusBanner('Your turn (X)', AppTheme.primary);
    }
    return _statusBanner('Bot thinking...', Colors.white54);
  }

  Widget _statusBanner(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style:
              TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }
}
