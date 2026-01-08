import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/event_service.dart';
import '../services/leaderboard_service.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/leaderboard_model.dart';
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
      if (mounted) {
        setState(() => _event = updated);
      }
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

  Future<void> _leaveEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title:
            const Text('Leave Event?', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to leave this event?',
            style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lbService = Provider.of<LeaderboardService>(context);
    final data = lbService.currentData;
    final entries = data?.leaderboard ?? [];
    final myPos = data?.myPosition;

    final status = _event['status'];
    final isLive = status == 'active';
    final isWaiting = status == 'waiting';
    final isEnded = status == 'ended';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_event['name'] ?? 'Event',
                style: const TextStyle(color: Colors.white, fontSize: 18)),
            Text(_isHost ? 'You are Host' : 'Participant',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Badge
            Center(
              child: _buildStatusBadge(status),
            ),
            const SizedBox(height: 24),

            // Info Cards Grid
            _buildInfoCardsGrid(),
            const SizedBox(height: 24),

            // Host Controls
            if (_isHost) ...[
              _buildHostControls(status),
              const SizedBox(height: 24),
            ],

            // Action Buttons
            _buildActionButtons(isLive, isWaiting, isEnded),
            const SizedBox(height: 32),

            // Leaderboard Section
            const Text(
              'LEADERBOARD',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            if (entries.isEmpty)
              _buildEmptyLeaderboard()
            else
              _buildLeaderboard(entries),

            // My Position Footer
            if (myPos != null) ...[
              const SizedBox(height: 16),
              _buildMyPosition(myPos),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case 'active':
        color = Colors.greenAccent;
        text = 'LIVE';
        icon = Icons.circle;
        break;
      case 'waiting':
        color = Colors.orangeAccent;
        text = 'WAITING';
        icon = Icons.hourglass_empty;
        break;
      case 'ended':
        color = Colors.redAccent;
        text = 'ENDED';
        icon = Icons.stop_circle;
        break;
      default:
        color = Colors.grey;
        text = status.toUpperCase();
        icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCardsGrid() {
    final genre = (_event['genre'] ?? 'Other').toString();
    final venue = _event['venue_name'] ?? _event['city'] ?? 'Unknown';
    final date = DateTime.tryParse(_event['starts_at'] ?? '');
    final dateStr = date != null
        ? "${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}"
        : "TBD";
    final iconChar = _event['icon'] ?? '🎵';

    return Column(
      children: [
        // Main event icon/image
        Center(
          child: _buildEventImage(iconChar),
        ),
        const SizedBox(height: 20),

        // Info cards row
        Row(
          children: [
            Expanded(
                child: _buildInfoCard(
                    Icons.music_note, 'Genre', genre, Colors.purpleAccent)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildInfoCard(
                    Icons.calendar_today, 'Date', dateStr, Colors.blueAccent)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildInfoCard(
                    Icons.location_on, 'Venue', venue, Colors.orangeAccent)),
          ],
        ),
      ],
    );
  }

  Widget _buildEventImage(String iconValue) {
    if (iconValue.startsWith('/')) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 3),
          image: DecorationImage(
            image: NetworkImage('${ApiService.baseUrl}$iconValue'),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF2A2A2A),
          border: Border.all(color: Colors.white24, width: 3),
        ),
        child: Center(
          child: Text(iconValue, style: const TextStyle(fontSize: 48)),
        ),
      );
    }
  }

  Widget _buildInfoCard(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 10),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildHostControls(String status) {
    return Row(
      children: [
        if (status == 'waiting')
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow, color: Colors.white),
              label: const Text('START EVENT'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _changeStatus('active'),
            ),
          ),
        if (status == 'active')
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.stop, color: Colors.white),
              label: const Text('END EVENT'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _changeStatus('ended'),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons(bool isLive, bool isWaiting, bool isEnded) {
    return Column(
      children: [
        // Start Dancing Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: isLive ? _joinAndStart : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              disabledBackgroundColor: Colors.grey[800],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
            child: Text(
              isWaiting
                  ? 'WAITING FOR HOST'
                  : isEnded
                      ? 'EVENT ENDED'
                      : 'START DANCING',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isLive ? Colors.black : Colors.white54,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Leave Event Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: _leaveEvent,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text(
              'LEAVE EVENT',
              style: TextStyle(
                fontSize: 14,
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyLeaderboard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Text(
          'No dancers yet.\nBe the first to start!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildLeaderboard(List<LeaderboardEntry> entries) {
    final maxPoints = entries.isEmpty ? 1 : entries.first.points;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: entries.take(5).toList().asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final item = entry.value;
          return _buildLeaderboardItem(rank, item, maxPoints);
        }).toList(),
      ),
    );
  }

  Widget _buildLeaderboardItem(
      int rank, LeaderboardEntry entry, int maxPoints) {
    final progress = maxPoints > 0 ? entry.points / maxPoints : 0.0;

    Color barColor;
    switch (rank) {
      case 1:
        barColor = Colors.amber;
        break;
      case 2:
        barColor = Colors.grey[400]!;
        break;
      case 3:
        barColor = Colors.brown[300]!;
        break;
      default:
        barColor = Colors.greenAccent;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: rank <= 3 ? barColor.withOpacity(0.2) : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: rank <= 3
                  ? Icon(Icons.emoji_events, color: barColor, size: 18)
                  : Text('#$rank',
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          ),
          const SizedBox(width: 12),
          // Name and bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.username,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                // Progress bar
                Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Points
          Text(
            '${entry.points}',
            style: TextStyle(
              color: barColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyPosition(MyPosition myPos) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Text(
            'YOU',
            style: TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            '#${myPos.rank}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '${myPos.points} pts',
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
