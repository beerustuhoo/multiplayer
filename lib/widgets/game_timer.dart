import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GameTimer extends StatelessWidget {
  final int remainingMs;
  final bool isActive;
  final String label;
  final bool isCurrentUser;

  const GameTimer({
    super.key,
    required this.remainingMs,
    required this.isActive,
    required this.label,
    this.isCurrentUser = false,
  });

  String _format(int ms) {
    final totalSeconds = (ms / 1000).ceil().clamp(0, 999999);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isLow = remainingMs < 30000;
    final isCritical = remainingMs < 10000;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isActive
            ? (isCritical
                ? AppTheme.error.withValues(alpha: 0.3)
                : isLow
                    ? AppTheme.warning.withValues(alpha: 0.2)
                    : AppTheme.primary.withValues(alpha: 0.2))
            : AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(
                color: isCritical
                    ? AppTheme.error
                    : isLow
                        ? AppTheme.warning
                        : AppTheme.primary,
                width: 2)
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 12,
                color: isCurrentUser ? AppTheme.primary : Colors.white54,
                fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
              )),
          const SizedBox(height: 4),
          Text(
            _format(remainingMs),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: isActive
                  ? (isCritical
                      ? AppTheme.error
                      : isLow
                          ? AppTheme.warning
                          : Colors.white)
                  : Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}
