import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/game_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/game_board.dart';
import '../../widgets/game_timer.dart';
import '../../widgets/move_history_panel.dart';
import '../../widgets/connection_status.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _historyOpen = false;

  Future<void> _exitGameToHome() async {
    context.read<GameProvider>().leaveGame();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  int _computeRemainingMs(
      int storedTimer, String currentTurn, String thisMark, int? lastMoveTime) {
    if (currentTurn != thisMark || lastMoveTime == null) return storedTimer;
    final elapsed = DateTime.now().millisecondsSinceEpoch - lastMoveTime;
    return (storedTimer - elapsed).clamp(0, storedTimer);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final game = context.watch<GameProvider>();
    final g = game.currentGame;

    if (g == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Game')),
        body: const Center(child: Text('No active game')),
      );
    }

    final userId = auth.user?.id ?? '';
    final isPlayerX = userId == g.playerX;
    final myMark = isPlayerX ? 'X' : 'O';
    final isMyTurn = g.currentTurn == myMark;
    final canMove = g.status == 'playing' && !g.paused && isMyTurn;

    final myName = isPlayerX ? g.playerXName : g.playerOName;
    final oppName = isPlayerX ? g.playerOName : g.playerXName;
    final myStoredTimer = isPlayerX ? g.timerX : g.timerO;
    final oppStoredTimer = isPlayerX ? g.timerO : g.timerX;
    final oppMark = isPlayerX ? 'O' : 'X';

    final myTimer = _computeRemainingMs(
        myStoredTimer, g.currentTurn, myMark, g.lastMoveTime);
    final oppTimer = _computeRemainingMs(
        oppStoredTimer, g.currentTurn, oppMark, g.lastMoveTime);

    List<int>? winLine;
    if (game.gameOverInfo != null) {
      final wl = game.gameOverInfo!['winningLine'];
      if (wl != null) winLine = List<int>.from(wl as List);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _exitGameToHome();
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Game'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _exitGameToHome,
        ),
        actions: [
          const ConnectionStatus(),
          IconButton(
            icon: Icon(_historyOpen ? Icons.grid_3x3 : Icons.history),
            tooltip: _historyOpen ? 'Show board' : 'Move history',
            onPressed: () => setState(() => _historyOpen = !_historyOpen),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'restart') game.requestRestart();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'restart', child: Text('Request Restart')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Opponent timer (top)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: GameTimer(
                    remainingMs: oppTimer,
                    isActive: g.currentTurn == oppMark && g.status == 'playing',
                    label: '$oppName ($oppMark)',
                  ),
                ),
              ],
            ),
          ),

          // Turn indicator
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _buildStatusBanner(g, game, isMyTurn, myMark),
          ),

          // Board or history
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _historyOpen
                  ? MoveHistoryPanel(
                      moves: g.moves,
                      playerXName: g.playerXName,
                      playerOName: g.playerOName,
                    )
                  : Center(
                      child: GameBoard(
                        board: g.board,
                        winningLine: winLine,
                        enabled: canMove,
                        onCellTap: canMove ? (pos) => game.makeMove(pos) : null,
                      ),
                    ),
            ),
          ),

          // My timer (bottom)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: GameTimer(
                    remainingMs: myTimer,
                    isActive: g.currentTurn == myMark && g.status == 'playing',
                    label: '$myName ($myMark) - You',
                    isCurrentUser: true,
                  ),
                ),
              ],
            ),
          ),

          // Error
          if (game.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: AppTheme.error.withValues(alpha: 0.2),
              child: Text(game.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.error)),
            ),
        ],
      ),

      // Restart request dialog
      bottomSheet: _buildBottomOverlay(game, userId),
      ),
    );
  }

  Widget _buildStatusBanner(
      dynamic g, GameProvider game, bool isMyTurn, String myMark) {
    if (game.gameOverInfo != null) {
      final reason = game.gameOverInfo!['reason'] as String?;
      final winner = game.gameOverInfo!['winner'] as String?;
      final userId = context.read<AuthProvider>().user?.id;
      String msg;
      Color color;
      if (reason == 'draw') {
        msg = "It's a draw!";
        color = AppTheme.warning;
      } else if (winner == userId) {
        msg = 'You win!';
        color = AppTheme.success;
      } else {
        final r = reason == 'timeout'
            ? ' (timeout)'
            : reason == 'forfeit'
                ? ' (opponent disconnected)'
                : '';
        msg = 'You lose$r';
        color = AppTheme.error;
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(msg,
            style:
                TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      );
    }

    if (g.paused) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.warning.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Game Paused',
            style: TextStyle(
                color: AppTheme.warning,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
      );
    }

    if (!game.isConnected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: AppTheme.error, size: 18),
            const SizedBox(width: 8),
            const Text(
              'Connection lost',
              style: TextStyle(
                color: AppTheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: game.isReconnecting ? null : () => game.reconnectNow(),
              child: Text(game.isReconnecting ? 'Reconnecting...' : 'Reconnect'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: (isMyTurn ? AppTheme.primary : Colors.white24).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isMyTurn ? 'Your turn ($myMark)' : "Opponent's turn",
        style: TextStyle(
          color: isMyTurn ? AppTheme.primary : Colors.white54,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget? _buildBottomOverlay(GameProvider game, String userId) {
    // Restart request
    if (game.restartRequest != null) {
      final requestedBy = game.restartRequest!['requestedBy'] as String;
      final requestedByName = game.restartRequest!['requestedByName'] as String?;
      final requestedAt = game.restartRequest!['requestedAt'] as int;
      final isMine = requestedBy == userId;

      return _RestartOverlay(
        isMine: isMine,
        requestedByName: requestedByName ?? 'Opponent',
        requestedAt: requestedAt,
        onAccept: isMine ? null : () => game.acceptRestart(),
        onDecline: isMine ? null : () => game.declineRestart(),
      );
    }

    // Opponent disconnected
    if (game.disconnectInfo != null) {
      final pauseStart = game.disconnectInfo!['pauseStart'] as int;
      return _DisconnectOverlay(pauseStart: pauseStart);
    }

    return null;
  }
}

class _RestartOverlay extends StatefulWidget {
  final bool isMine;
  final String requestedByName;
  final int requestedAt;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  const _RestartOverlay({
    required this.isMine,
    required this.requestedByName,
    required this.requestedAt,
    this.onAccept,
    this.onDecline,
  });

  @override
  State<_RestartOverlay> createState() => _RestartOverlayState();
}

class _RestartOverlayState extends State<_RestartOverlay> {
  late Timer _timer;
  int _remaining = 30;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
  }

  void _updateRemaining() {
    final elapsed =
        (DateTime.now().millisecondsSinceEpoch - widget.requestedAt) ~/ 1000;
    setState(() => _remaining = (30 - elapsed).clamp(0, 30));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.restart_alt,
              color: AppTheme.warning, size: 32),
          const SizedBox(height: 8),
          Text(
            widget.isMine
                ? 'Waiting for opponent to accept restart...'
                : '${widget.requestedByName} wants to restart',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('${_remaining}s remaining',
              style: const TextStyle(color: AppTheme.warning, fontSize: 14)),
          if (!widget.isMine) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: widget.onAccept,
                  child: const Text('Accept'),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: widget.onDecline,
                  child: const Text('Decline'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DisconnectOverlay extends StatefulWidget {
  final int pauseStart;
  const _DisconnectOverlay({required this.pauseStart});

  @override
  State<_DisconnectOverlay> createState() => _DisconnectOverlayState();
}

class _DisconnectOverlayState extends State<_DisconnectOverlay> {
  late Timer _timer;
  int _remaining = 120;

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  void _update() {
    final elapsed =
        (DateTime.now().millisecondsSinceEpoch - widget.pauseStart) ~/ 1000;
    setState(() => _remaining = (120 - elapsed).clamp(0, 120));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mins = _remaining ~/ 60;
    final secs = _remaining % 60;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, color: AppTheme.error, size: 32),
          const SizedBox(height: 8),
          const Text('Opponent Disconnected',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            'Waiting for reconnection: ${mins}m ${secs.toString().padLeft(2, '0')}s',
            style: const TextStyle(color: AppTheme.warning),
          ),
          const SizedBox(height: 4),
          const Text(
            'You win if opponent does not return in time.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
