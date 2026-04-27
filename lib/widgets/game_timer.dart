import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GameTimer extends StatefulWidget {
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

  @override
  State<GameTimer> createState() => _GameTimerState();
}

class _GameTimerState extends State<GameTimer> {
  Timer? _ticker;
  late int _displayMs;

  @override
  void initState() {
    super.initState();
    _displayMs = widget.remainingMs;
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant GameTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final drift = (_displayMs - widget.remainingMs).abs();
    if (drift > 1000 ||
        oldWidget.remainingMs != widget.remainingMs ||
        oldWidget.isActive != widget.isActive) {
      _displayMs = widget.remainingMs;
    }
    _syncTicker();
  }

  void _syncTicker() {
    _ticker?.cancel();
    if (!widget.isActive || _displayMs <= 0) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _displayMs = (_displayMs - 1000).clamp(0, 999999999);
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _format(int ms) {
    final totalSeconds = (ms / 1000).ceil().clamp(0, 999999);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isLow = _displayMs < 30000;
    final isCritical = _displayMs < 10000;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: widget.isActive
            ? (isCritical
                ? AppTheme.error.withValues(alpha: 0.3)
                : isLow
                    ? AppTheme.warning.withValues(alpha: 0.2)
                    : AppTheme.primary.withValues(alpha: 0.2))
            : AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: widget.isActive
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
          Text(widget.label,
              style: TextStyle(
                fontSize: 12,
                color: widget.isCurrentUser ? AppTheme.primary : Colors.white54,
                fontWeight:
                    widget.isCurrentUser ? FontWeight.bold : FontWeight.normal,
              )),
          const SizedBox(height: 4),
          Text(
            _format(_displayMs),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: widget.isActive
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
