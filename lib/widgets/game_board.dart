import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GameBoard extends StatelessWidget {
  final List<String> board;
  final List<int>? winningLine;
  final bool enabled;
  final void Function(int position)? onCellTap;

  const GameBoard({
    super.key,
    required this.board,
    this.winningLine,
    this.enabled = true,
    this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: 9,
          itemBuilder: (context, index) {
            final cell = board[index];
            final isWinCell = winningLine?.contains(index) ?? false;

            return GestureDetector(
              onTap: enabled && cell.isEmpty ? () => onCellTap?.call(index) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: isWinCell
                      ? (cell == 'X'
                          ? AppTheme.xColor.withValues(alpha: 0.3)
                          : AppTheme.oColor.withValues(alpha: 0.3))
                      : AppTheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: isWinCell
                      ? Border.all(
                          color: cell == 'X' ? AppTheme.xColor : AppTheme.oColor,
                          width: 3)
                      : null,
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: cell.isEmpty
                        ? const SizedBox.shrink()
                        : Text(
                            cell,
                            key: ValueKey('$index-$cell'),
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color:
                                  cell == 'X' ? AppTheme.xColor : AppTheme.oColor,
                            ),
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
