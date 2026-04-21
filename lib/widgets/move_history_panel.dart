import 'package:flutter/material.dart';
import '../models/game.dart';
import '../theme/app_theme.dart';

class MoveHistoryPanel extends StatelessWidget {
  final List<GameMove> moves;
  final String playerXName;
  final String playerOName;

  const MoveHistoryPanel({
    super.key,
    required this.moves,
    required this.playerXName,
    required this.playerOName,
  });

  String _posLabel(int pos) {
    const labels = ['1', '2', '3', '4', '5', '6', '7', '8', '9'];
    return labels[pos];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Text('Move History',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          const Divider(height: 1),
          if (moves.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text('No moves yet',
                    style: TextStyle(color: Colors.white38, fontSize: 13)),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: moves.length,
                itemBuilder: (context, i) {
                  final m = moves[i];
                  final isX = m.player == 'X';
                  final name = isX ? playerXName : playerOName;
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text('${i + 1}.',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 12)),
                        ),
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isX
                                ? AppTheme.xColor.withValues(alpha: 0.2)
                                : AppTheme.oColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(m.player,
                              style: TextStyle(
                                  color:
                                      isX ? AppTheme.xColor : AppTheme.oColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('$name → cell ${_posLabel(m.position)}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white70)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
