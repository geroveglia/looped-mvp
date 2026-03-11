import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../ui/app_theme.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _api = ApiService();
  Timer? _searchTimer;
  
  List<dynamic> _leaderboard = [];
  List<dynamic> _friends = [];
  List<dynamic> _feed = [];
  List<dynamic> _searchResults = [];
  bool _isLoadingRankings = true;
  bool _isLoadingFriends = true;
  bool _isLoadingFeed = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRankings();
    _loadFriends();
    _loadFeed();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    try {
      final data = await _api.get('/social/feed');
      setState(() {
        _feed = data;
        _isLoadingFeed = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingFeed = false);
    }
  }

  Future<void> _loadRankings() async {
    try {
      final data = await _api.get('/leaderboards/global');
      setState(() {
        _leaderboard = data;
        _isLoadingRankings = false;
      });
    } catch (e) {
      setState(() => _isLoadingRankings = false);
    }
  }

  Future<void> _loadFriends() async {
    try {
      final data = await _api.get('/social/friends');
      setState(() {
        _friends = data;
        _isLoadingFriends = false;
      });
    } catch (e) {
      setState(() => _isLoadingFriends = false);
    }
  }

  Future<void> _searchUsers(String query) async {
    _searchTimer?.cancel();
    
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
      return;
    }

    _searchTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      
      setState(() => _isSearching = true);
      try {
        final data = await _api.get('/social/search?q=$query');
        if (mounted) {
          setState(() {
            _searchResults = data;
            _isSearching = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSearching = false);
        }
      }
    });
  }

  Future<void> _toggleFollow(String userId) async {
    try {
      await _api.post('/social/follow/$userId', {});
      _loadFriends(); // Refresh friends list
      if (_searchController.text.isNotEmpty) {
        _searchUsers(_searchController.text);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Community', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'ACTIVITY'),
            Tab(text: 'RANKINGS'),
            Tab(text: 'FRIENDS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActivityTab(),
          _buildRankingsTab(),
          _buildFriendsTab(),
        ],
      ),
    );
  }

  Widget _buildActivityTab() {
    if (_isLoadingFeed) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
    }

    if (_feed.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bolt, color: Colors.grey, size: 64),
            const SizedBox(height: 16),
            const Text('No recent activity', style: TextStyle(color: Colors.grey)),
            TextButton(
              onPressed: () => _tabController.animateTo(2),
              child: const Text('Follow people to see their activity', style: TextStyle(color: AppTheme.accent)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFeed,
      color: AppTheme.accent,
      backgroundColor: const Color(0xFF131313),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: _feed.length,
        itemBuilder: (context, index) {
          final item = _feed[index];
          final user = item['user_id'] ?? {};
          final type = item['feed_type'];
          final points = item['points'] ?? 0;
          final duration = (item['duration_sec'] ?? item['duration_seconds'] ?? 0) ~/ 60;
          final event = item['event_id'] ?? {};
          
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131313),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF2A2A2A),
                  backgroundImage: user['avatar_url'] != null ? NetworkImage('${ApiService.baseUrl}${user['avatar_url']}') : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          children: [
                            TextSpan(text: user['username'] ?? 'Someone', style: const TextStyle(fontWeight: FontWeight.bold)),
                            TextSpan(text: type == 'dance' ? ' danced at ' : ' completed a '),
                            TextSpan(
                              text: type == 'dance' ? (event['name'] ?? 'an event') : 'solo session',
                              style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildActivityStat(Icons.bolt, '$points'),
                          const SizedBox(width: 16),
                          _buildActivityStat(Icons.timer, '${duration}m'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActivityStat(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 14),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildRankingsTab() {
    if (_isLoadingRankings) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
    }

    if (_leaderboard.isEmpty) {
      return const Center(child: Text('No rankings yet', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _leaderboard.length,
      itemBuilder: (context, index) {
        final user = _leaderboard[index];
        final rank = index + 1;
        
        if (index < 3) return _buildTopRankCard(user, rank);
        
        return _buildRankTile(user, rank);
      },
    );
  }

  Widget _buildTopRankCard(dynamic user, int rank) {
    Color medalColor = rank == 1 ? Colors.amber : (rank == 2 ? Colors.grey : Colors.brown);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131313),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: medalColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFF2A2A2A),
                backgroundImage: user['avatar_url'] != null ? NetworkImage('${ApiService.baseUrl}${user['avatar_url']}') : null,
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: medalColor, shape: BoxShape.circle),
                child: Text('$rank', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['username'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                Text('Level ${user['level']} Dancer', style: TextStyle(color: AppTheme.accent.withOpacity(0.7), fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${user['xp']} XP', style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 16)),
              const Text('TOTAL', style: TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRankTile(dynamic user, int rank) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: SizedBox(
        width: 60,
        child: Row(
          children: [
            Text('$rank', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF1A1A1A),
              backgroundImage: user['avatar_url'] != null ? NetworkImage('${ApiService.baseUrl}${user['avatar_url']}') : null,
            ),
          ],
        ),
      ),
      title: Text(user['username'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text('LVL ${user['level']}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
      trailing: Text('${user['xp']} XP', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildFriendsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search dancers...',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: AppTheme.accent),
              filled: true,
              fillColor: const Color(0xFF131313),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
            ),
            onChanged: _searchUsers,
          ),
        ),
        Expanded(
          child: _searchController.text.isNotEmpty 
            ? _buildSearchResults()
            : _buildFriendsList(),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
    if (_searchResults.isEmpty) return const Center(child: Text('No users found', style: TextStyle(color: Colors.grey)));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        bool isAlreadyFriend = _friends.any((f) => f['_id'] == user['_id']);

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF131313),
            backgroundImage: user['avatar_url'] != null ? NetworkImage('${ApiService.baseUrl}${user['avatar_url']}') : null,
          ),
          title: Text(user['username'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text('Level ${user['level']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          trailing: ElevatedButton(
            onPressed: () => _toggleFollow(user['_id']),
            style: ElevatedButton.styleFrom(
              backgroundColor: isAlreadyFriend ? Colors.white10 : AppTheme.accent,
              foregroundColor: isAlreadyFriend ? Colors.white : Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Text(isAlreadyFriend ? 'Following' : 'Follow'),
          ),
        );
      },
    );
  }

  Widget _buildFriendsList() {
    if (_isLoadingFriends) return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, color: Colors.grey, size: 64),
            const SizedBox(height: 16),
            const Text('No friends yet', style: TextStyle(color: Colors.grey)),
            TextButton(
              onPressed: () => _tabController.animateTo(0),
              child: const Text('Find some people in Rankings', style: TextStyle(color: AppTheme.accent)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _friends.length,
      itemBuilder: (context, index) {
        final friend = _friends[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF131313),
            backgroundImage: friend['avatar_url'] != null ? NetworkImage('${ApiService.baseUrl}${friend['avatar_url']}') : null,
          ),
          title: Text(friend['username'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text('Level ${friend['level']} Dancer', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: () {
            // Profile view maybe?
          },
        );
      },
    );
  }
}
