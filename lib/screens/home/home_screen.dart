import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/game_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/connection_status.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GameProvider>().setupListeners();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final game = context.watch<GameProvider>();

    // Navigate to game screen when a game starts
    if (game.currentGame != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamed(context, '/game');
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tic Tac Toe'),
        actions: [
          const ConnectionStatus(),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.logout();
              if (!context.mounted) return;
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          game.socket.emit('get_pending_invites');
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Welcome
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.grid_3x3_rounded,
                        size: 48, color: AppTheme.primary),
                    const SizedBox(height: 8),
                    Text('Welcome, ${auth.user?.username ?? "Player"}!',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      'Players online: ${game.onlineUserIds.length}',
                      style: const TextStyle(
                        color: AppTheme.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (auth.user?.emailVerified == false)
                      TextButton.icon(
                        icon: const Icon(Icons.warning_amber, color: AppTheme.warning),
                        label: const Text('Verify email',
                            style: TextStyle(color: AppTheme.warning)),
                        onPressed: () =>
                            Navigator.pushNamed(context, '/verify-email'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Quick actions
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    icon: Icons.search,
                    label: 'Find\nOpponent',
                    color: AppTheme.primary,
                    onTap: () => Navigator.pushNamed(context, '/search'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.smart_toy,
                    label: 'Play\nvs Bot',
                    color: AppTheme.secondary,
                    onTap: () => Navigator.pushNamed(context, '/bot-game'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Pending invites
            if (game.pendingInvites.isNotEmpty) ...[
              Text('Incoming Invites (${game.pendingInvites.length})',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...game.pendingInvites.map((inv) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                          backgroundColor: AppTheme.primary,
                          child: Icon(Icons.person, color: Colors.white)),
                      title: Text(inv.fromUsername),
                      subtitle: Text(
                          '${(inv.timeControl / 60000).toInt()} min game'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle,
                                color: AppTheme.success),
                            onPressed: () => game.acceptInvite(inv.id),
                          ),
                          IconButton(
                            icon:
                                const Icon(Icons.cancel, color: AppTheme.error),
                            onPressed: () => game.declineInvite(inv.id),
                          ),
                        ],
                      ),
                    ),
                  )),
              const SizedBox(height: 24),
            ],

            // Error message
            if (game.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Card(
                  color: AppTheme.error.withValues(alpha: 0.2),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(game.error!,
                                style: const TextStyle(color: AppTheme.error))),
                      ],
                    ),
                  ),
                ),
              ),

            // How to play
            const Text('How to Play',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _HelpItem('1.', 'Search for an opponent by username or email'),
                    SizedBox(height: 8),
                    _HelpItem('2.', 'Send a game invite with your preferred time'),
                    SizedBox(height: 8),
                    _HelpItem('3.', 'Take turns placing X or O on the 3x3 grid'),
                    SizedBox(height: 8),
                    _HelpItem('4.',
                        'First to get 3 in a row wins! Watch your timer.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  final String number;
  final String text;
  const _HelpItem(this.number, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(number,
            style: const TextStyle(
                color: AppTheme.primary, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.white70))),
      ],
    );
  }
}
