import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../services/api_service.dart';
import '../../config/constants.dart';
import '../../theme/app_theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchC = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  String _selectedTimeLabel = '5 min';

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _searchC.text.trim();
    if (q.length < 2) return;
    setState(() => _searching = true);
    try {
      final api = context.read<ApiService>();
      final res = await api.searchUsers(q);
      setState(() {
        _results = res.cast<Map<String, dynamic>>();
        _searching = false;
      });
    } catch (e) {
      setState(() => _searching = false);
    }
  }

  void _sendInvite(String userId, String username) {
    final tc = AppConstants.timeControls[_selectedTimeLabel]!;
    context.read<GameProvider>().sendInvite(userId, tc);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invite sent to $username!')));
  }

  @override
  Widget build(BuildContext context) {
    final onlineIds = context.watch<GameProvider>().onlineUserIds;
    return Scaffold(
      appBar: AppBar(title: const Text('Find Opponent')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchC,
                  decoration: InputDecoration(
                    hintText: 'Search by username or email',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _search,
                    ),
                  ),
                  onSubmitted: (_) => _search(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Time: ',
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(width: 8),
                    ...AppConstants.timeControls.keys.map((label) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: _selectedTimeLabel == label,
                            selectedColor: AppTheme.primary,
                            onSelected: (s) {
                              if (s) setState(() => _selectedTimeLabel = label);
                            },
                          ),
                        )),
                  ],
                ),
              ],
            ),
          ),
          if (_searching)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          Expanded(
            child: _results.isEmpty && !_searching
                ? const Center(
                    child: Text('Search for players to invite',
                        style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, i) {
                      final u = _results[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primary.withValues(alpha: 0.3),
                            child: Text(
                              (u['username'] as String)[0].toUpperCase(),
                              style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(u['username'] as String),
                          subtitle: Text(
                            onlineIds.contains(u['id'] as String)
                                ? 'Online'
                                : 'Offline',
                            style: TextStyle(
                              color: onlineIds.contains(u['id'] as String)
                                  ? AppTheme.success
                                  : Colors.white54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: ElevatedButton.icon(
                            icon: const Icon(Icons.sports_esports, size: 18),
                            label: const Text('Invite'),
                            onPressed: () => _sendInvite(
                                u['id'] as String, u['username'] as String),
                          ),
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
