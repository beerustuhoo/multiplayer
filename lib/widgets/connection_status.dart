import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';

class ConnectionStatus extends StatelessWidget {
  const ConnectionStatus({super.key});

  @override
  Widget build(BuildContext context) {
    final connected = context.watch<GameProvider>().isConnected;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Tooltip(
        message: connected ? 'Connected' : 'Disconnected',
        child: Icon(
          connected ? Icons.wifi : Icons.wifi_off,
          color: connected ? AppTheme.success : AppTheme.error,
          size: 20,
        ),
      ),
    );
  }
}
