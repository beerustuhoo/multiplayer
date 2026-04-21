/// Win-check result
class GameResult {
  final String? winner; // 'X', 'O', or 'draw'
  final List<int>? winningLine;

  GameResult({this.winner, this.winningLine});
}

class TicTacToeLogic {
  static const _winLines = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8], // rows
    [0, 3, 6], [1, 4, 7], [2, 5, 8], // columns
    [0, 4, 8], [2, 4, 6],             // diagonals
  ];

  /// Check if there's a winner or draw. Returns null if game is still ongoing.
  static GameResult? checkWinner(List<String> board) {
    for (final line in _winLines) {
      final a = board[line[0]];
      final b = board[line[1]];
      final c = board[line[2]];
      if (a.isNotEmpty && a == b && a == c) {
        return GameResult(winner: a, winningLine: line);
      }
    }

    if (board.every((cell) => cell.isNotEmpty)) {
      return GameResult(winner: 'draw', winningLine: null);
    }

    return null;
  }

  /// Validate a move
  static bool isValidMove(
      List<String> board, int position, String currentTurn, String playerMark) {
    if (position < 0 || position > 8) return false;
    if (board[position].isNotEmpty) return false;
    if (currentTurn != playerMark) return false;
    return true;
  }

  /// Apply a move and return the new board
  static List<String> makeMove(List<String> board, int position, String mark) {
    final newBoard = List<String>.from(board);
    newBoard[position] = mark;
    return newBoard;
  }

  /// Simple AI bot: tries to win, then block, then center, corners, edges
  static int getBotMove(List<String> board, String botMark) {
    final opponentMark = botMark == 'X' ? 'O' : 'X';

    // Try to win
    for (int i = 0; i < 9; i++) {
      if (board[i].isEmpty) {
        final test = List<String>.from(board);
        test[i] = botMark;
        if (checkWinner(test)?.winner == botMark) return i;
      }
    }

    // Block opponent
    for (int i = 0; i < 9; i++) {
      if (board[i].isEmpty) {
        final test = List<String>.from(board);
        test[i] = opponentMark;
        if (checkWinner(test)?.winner == opponentMark) return i;
      }
    }

    // Take center
    if (board[4].isEmpty) return 4;

    // Take a corner
    final corners = [0, 2, 6, 8];
    final availableCorners = corners.where((i) => board[i].isEmpty).toList();
    if (availableCorners.isNotEmpty) {
      availableCorners.shuffle();
      return availableCorners.first;
    }

    // Take any available
    final available = <int>[];
    for (int i = 0; i < 9; i++) {
      if (board[i].isEmpty) available.add(i);
    }
    available.shuffle();
    return available.first;
  }
}
