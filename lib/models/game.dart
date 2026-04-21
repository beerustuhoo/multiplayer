class GameMove {
  final String player;
  final int position;
  final int timestamp;

  GameMove({required this.player, required this.position, required this.timestamp});

  factory GameMove.fromJson(Map<String, dynamic> json) {
    return GameMove(
      player: json['player'] as String,
      position: (json['position'] as num).toInt(),
      timestamp: (json['timestamp'] as num).toInt(),
    );
  }
}

class GameModel {
  final String id;
  final String playerX;
  final String playerO;
  final String playerXName;
  final String playerOName;
  final List<String> board;
  final String currentTurn;
  final String status;
  final String? winner;
  final int timerX;
  final int timerO;
  final int timeControl;
  final int? lastMoveTime;
  final List<GameMove> moves;
  final bool paused;
  final String? pauseReason;
  final int? pauseStart;
  final String? restartRequestedBy;
  final int? restartRequestedAt;

  GameModel({
    required this.id,
    required this.playerX,
    required this.playerO,
    required this.playerXName,
    required this.playerOName,
    required this.board,
    required this.currentTurn,
    required this.status,
    this.winner,
    required this.timerX,
    required this.timerO,
    required this.timeControl,
    this.lastMoveTime,
    required this.moves,
    required this.paused,
    this.pauseReason,
    this.pauseStart,
    this.restartRequestedBy,
    this.restartRequestedAt,
  });

  factory GameModel.fromJson(Map<String, dynamic> json) {
    return GameModel(
      id: json['id'] as String,
      playerX: json['playerX'] as String,
      playerO: json['playerO'] as String,
      playerXName: (json['playerXName'] as String?) ?? 'Player X',
      playerOName: (json['playerOName'] as String?) ?? 'Player O',
      board: List<String>.from(json['board'] as List),
      currentTurn: json['currentTurn'] as String,
      status: json['status'] as String,
      winner: json['winner'] as String?,
      timerX: (json['timerX'] as num).toInt(),
      timerO: (json['timerO'] as num).toInt(),
      timeControl: (json['timeControl'] as num).toInt(),
      lastMoveTime: (json['lastMoveTime'] as num?)?.toInt(),
      moves: (json['moves'] as List)
          .map((m) => GameMove.fromJson(m as Map<String, dynamic>))
          .toList(),
      paused: json['paused'] as bool? ?? false,
      pauseReason: json['pauseReason'] as String?,
      pauseStart: (json['pauseStart'] as num?)?.toInt(),
      restartRequestedBy: json['restartRequestedBy'] as String?,
      restartRequestedAt: (json['restartRequestedAt'] as num?)?.toInt(),
    );
  }

  bool get isFinished => status != 'playing';
}
