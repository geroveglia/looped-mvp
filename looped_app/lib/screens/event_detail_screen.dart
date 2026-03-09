import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/event_service.dart';
import '../services/leaderboard_service.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/leaderboard_model.dart';
import '../ui/app_theme.dart';
import 'live_dance_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final Map<String, dynamic> event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late Map<String, dynamic> _event;
  Timer? _refreshTimer;
  bool _isHost = false;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    final auth = Provider.of<AuthService>(context, listen: false);
    _isHost = _event['host_user_id'] == auth.userId;

    final lbService = Provider.of<LeaderboardService>(context, listen: false);
    lbService.startPolling(_event['_id']);

    _refreshTimer = Timer.periodic(
        const Duration(seconds: 5), (timer) => _fetchEventDetails());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    final lbService = Provider.of<LeaderboardService>(context, listen: false);
    lbService.stopPolling();
    super.dispose();
  }

  Future<void> _fetchEventDetails() async {
    try {
      final service = Provider.of<EventService>(context, listen: false);
      final updated = await service.getEvent(_event['_id']);
      if (mounted) setState(() => _event = updated);
    } catch (e) {}
  }

  Future<void> _changeStatus(String newStatus) async {
    try {
      await Provider.of<EventService>(context, listen: false)
          .updateEventStatus(_event['_id'], newStatus);
      await _fetchEventDetails();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _joinAndStart() async {
    if (_event['status'] != 'active') {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Event is not active!")));
      return;
    }

    final eventService = Provider.of<EventService>(context, listen: false);
    try {
      await eventService.joinEvent(_event['_id']);
    } catch (e) {}

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LiveDanceScreen(eventId: _event['_id']),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lbService = Provider.of<LeaderboardService>(context);
    final data = lbService.currentData;
    final entries = data?.leaderboard ?? [];

    final status = _event['status'];
    final organizer = _event['organizer'] ?? 'Looped';
    final goalSteps = _event['goal_steps'] ?? 10000;
    final myPoints = data?.myPosition.points ?? 0;
    final progress = (myPoints / goalSteps).clamp(0.0, 1.0);

    final iconChar = _event['icon'] ?? '🎵';
    final isImageUrl = iconChar.startsWith('/');
    final imageUrl = isImageUrl ? '${ApiService.baseUrl}$iconChar' : '';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: isImageUrl
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildPlaceholderBg(iconChar),
                  )
                : _buildPlaceholderBg(iconChar),
          ),
          // Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.7),
                    Colors.black,
                    Colors.black,
                  ],
                  stops: const [0.0, 0.4, 0.7, 1.0],
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildCircleIconButton(
                          Icons.arrow_back, () => Navigator.pop(context)),
                      _buildCircleIconButton(Icons.more_vert, () {}),
                    ],
                  ),
                ),
                // Main Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 100),
                        // Community Challenge Tag
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF003D2B),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Text(
                            'COMMUNITY CHALLENGE',
                            style: TextStyle(
                              color: AppTheme.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Title
                        Text(
                          _event['name'] ?? 'Event Name',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Organizer
                        Text(
                          'Organized by $organizer',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Info Badges Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildInfoBadge('GENRE', _event['genre'] ?? 'Dance',
                                Icons.fitness_center),
                            _buildInfoBadge(
                                'DATE',
                                _formatDate(_event['starts_at']),
                                Icons.calendar_today),
                            _buildInfoBadge(
                                'PLACE',
                                _event['venue_name'] ??
                                    _event['city'] ??
                                    'Global',
                                Icons.location_on),
                          ],
                        ),
                        const SizedBox(height: 32),
                        // Steps Goal Card
                        _buildGoalCard(goalSteps, myPoints, progress),
                        const SizedBox(height: 32),
                        if (_isHost) ...[
                          _buildAdminControls(status),
                          const SizedBox(height: 32),
                        ],
                        // Description Section
                        if (_event['description'] != null &&
                            _event['description']
                                .toString()
                                .trim()
                                .isNotEmpty) ...[
                          const Text('EVENT INFO',
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2)),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131313),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.05)),
                            ),
                            child: Text(
                              _event['description'],
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  height: 1.5),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                        // Quick Actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildQuickAction(Icons.person_add_alt_1, 'Invite'),
                            _buildQuickAction(
                                Icons.notifications_none, 'Reminder'),
                            _buildQuickAction(Icons.share_outlined, 'Share'),
                            _buildQuickAction(Icons.info_outline, 'Info'),
                          ],
                        ),
                        const SizedBox(height: 40),
                        // Leaderboard Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Leaderboard',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold),
                            ),
                            _buildLeaderboardToggle(),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Leaderboard List
                        _buildLeaderboardList(entries),
                        const SizedBox(
                            height: 120), // Spacing for sticky button
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Sticky Bottom Button
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status == 'active')
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: _joinAndStart,
                      icon: const Icon(Icons.bolt, color: Colors.black),
                      label: const Text(
                        'JOIN CHALLENGE',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100)),
                      ),
                    ),
                  ),
                if (status == 'waiting' && _isHost)
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: () => _changeStatus('active'),
                      icon: const Icon(Icons.play_arrow, color: Colors.black),
                      label: const Text(
                        'START EVENT',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100)),
                      ),
                    ),
                  ),
                if (status == 'waiting' && !_isHost)
                  const Text('Waiting for host to start...',
                      style: TextStyle(color: Colors.grey)),
                if (status == 'ended')
                  const Text('Challenge ended',
                      style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderBg(String iconChar) {
    return Container(
      color: const Color(0xFF121212),
      child: Center(
        child: Text(
          iconChar,
          style: const TextStyle(fontSize: 80),
        ),
      ),
    );
  }

  Widget _buildCircleIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildInfoBadge(String label, String value, IconData icon) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.5),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.accent, size: 20),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(int goal, int current, double progress) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF131313),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Steps Goal',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Target for this challenge',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatNumber(goal),
                    style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),
                  const Text('STEPS',
                      style: TextStyle(color: Colors.grey, fontSize: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: const Color(0xFF2C2C2C),
              valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('PROGRESS',
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
              Text(
                '${_formatNumber(current)} / ${_formatNumber(goal)}',
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildAdminControls(String status) {
    // If waiting, the button is now at the bottom. Only show END EVENT here when active.
    if (status != 'active') return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          const Text('ADMIN CONTROLS',
              style: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _changeStatus('ended'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white10,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('END EVENT'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(10)),
            child: const Text('Top 10',
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
          const SizedBox(width: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Friends',
                style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList(List<LeaderboardEntry> entries) {
    if (entries.isEmpty) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text('No participants yet',
                  style: TextStyle(color: Colors.grey))));
    }

    return Column(
      children: entries.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF131313),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: index == 0 ? AppTheme.accent : Colors.grey,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 24,
                backgroundImage:
                    (item.avatarUrl != null && item.avatarUrl!.isNotEmpty)
                        ? NetworkImage('${ApiService.baseUrl}${item.avatarUrl}')
                        : null,
                backgroundColor: Colors.grey.shade800,
                child: (item.avatarUrl == null || item.avatarUrl!.isEmpty)
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.username,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatNumber(item.points)} steps',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (index == 0)
                const Icon(Icons.emoji_events,
                    color: AppTheme.accent, size: 24),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'TBD';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return 'TBD';
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}
