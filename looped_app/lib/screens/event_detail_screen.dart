import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/event_service.dart';
import '../services/leaderboard_service.dart';
import '../services/auth_service.dart';
import '../models/leaderboard_model.dart';
import 'live_dance_screen.dart';
import '../ui/animations/fade_slide_route.dart';

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
    // Check if I am host
    // CAREFUL: widget.event['host_user_id'] might be a string or object depending on populate.
    // In list endpoint, usually it's just ID.
    _isHost = _event['host_user_id'] == auth.userId;

    final lbService = Provider.of<LeaderboardService>(context, listen: false);
    lbService.startPolling(_event['_id']);

    // Poll Event Details (Status) every 5s
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
    } catch (e) {
      // ignore
    }
  }

  Future<void> _changeStatus(String newStatus) async {
    try {
      await Provider.of<EventService>(context, listen: false)
          .updateEventStatus(_event['_id'], newStatus);
      await _fetchEventDetails();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
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
    } catch (e) {
      // ignore
    }

    if (mounted) {
      Navigator.of(context)
          .push(
        FadeSlideRoute(
          page: LiveDanceScreen(eventId: _event['_id']),
        ),
      )
          .then((_) {
        Provider.of<LeaderboardService>(context, listen: false)
            .fetchLeaderboard(_event['_id']);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lbService = Provider.of<LeaderboardService>(context);
    final data = lbService.currentData;
    final entries = data?.leaderboard ?? [];
    final myPos = data?.myPosition;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_event['name']),
            Text(_isHost ? "You are Host" : "Participant",
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 1. Status Badge & Host Controls
          _buildStatusHeader(),

          const Divider(color: Colors.white24),

          // 2. Start Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _event['status'] == 'active' ? _joinAndStart : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  disabledBackgroundColor: Colors.grey[800],
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                child: Text(
                    _event['status'] == 'waiting'
                        ? 'WAITING FOR HOST'
                        : _event['status'] == 'ended'
                            ? 'EVENT ENDED'
                            : 'START DANCING',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _event['status'] == 'active'
                            ? Colors.black
                            : Colors.white54)),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 3. Leaderboard Title
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("LEADERBOARD",
                  style: TextStyle(
                      color: Colors.grey,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold)),
            ),
          ),

          // 4. Leaderboard List
          Expanded(
            child: lbService.isLoading && entries.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : entries.isEmpty
                    ? const Center(
                        child: Text("No points yet.",
                            style: TextStyle(color: Colors.white54)))
                    : _buildLeaderboardList(entries),
          ),

          // 5. Sticky Footer
          if (myPos != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF1E1E1E),
              child: Row(
                children: [
                  const Text("YOU",
                      style: TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text("#${myPos.rank}",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 20),
                  Text("${myPos.points} pts",
                      style: const TextStyle(color: Colors.white70)),
                ],
              ),
            )
        ],
      ),
    );
  }

  Widget _buildStatusHeader() {
    final status = _event['status'];
    Color statusColor = Colors.grey;
    String statusText = status.toUpperCase();
    if (status == 'active') {
      statusColor = Colors.greenAccent;
      statusText = "LIVE";
    }
    if (status == 'waiting') {
      statusColor = Colors.orangeAccent;
      statusText = "WAITING";
    }
    if (status == 'ended') {
      statusColor = Colors.redAccent;
      statusText = "ENDED";
    }

    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      color: Colors.white10,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.circle, size: 12, color: statusColor),
              const SizedBox(width: 8),
              Text(statusText,
                  style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2)),
            ],
          ),
          if (_isHost) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (status == 'waiting')
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text("START EVENT"),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () => _changeStatus('active'),
                  ),
                if (status == 'active')
                  ElevatedButton.icon(
                    icon: const Icon(Icons.stop),
                    label: const Text("END EVENT"),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => _changeStatus('ended'),
                  ),
              ],
            )
          ]
        ],
      ),
    );
  }

  Widget _buildLeaderboardList(List<LeaderboardEntry> entries) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80), // Space for sticky footer
      itemCount: entries.length,
      itemBuilder: (ctx, i) {
        final entry = entries[i];
        final rank = i + 1;
        final isTop3 = rank <= 3;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: EdgeInsets.symmetric(
              horizontal: isTop3 ? 12 : 16, vertical: isTop3 ? 6 : 4),
          decoration: BoxDecoration(
            color: isTop3 ? const Color(0xFF2A2A2A) : const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(10),
            border: isTop3
                ? Border.all(color: _getRankColor(rank).withOpacity(0.5))
                : null,
          ),
          child: ListTile(
            contentPadding:
                EdgeInsets.symmetric(horizontal: 16, vertical: isTop3 ? 8 : 0),
            leading: _buildRankBadge(rank),
            title: Text(entry.username,
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: isTop3 ? FontWeight.bold : FontWeight.normal,
                    fontSize: isTop3 ? 18 : 16)),
            trailing: Text("${entry.points} pts",
                style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 16,
                    fontFamily: 'Monospace')),
          ),
        );
      },
    );
  }

  Widget _buildRankBadge(int rank) {
    if (rank > 3) {
      return Container(
        width: 30,
        alignment: Alignment.center,
        child: Text("#$rank", style: const TextStyle(color: Colors.grey)),
      );
    }

    IconData icon;
    Color color;
    if (rank == 1) {
      icon = Icons.emoji_events;
      color = Colors.amber;
    } else if (rank == 2) {
      icon = Icons.emoji_events;
      color = Colors.grey[300]!;
    } else {
      icon = Icons.emoji_events;
      color = Colors.brown[300]!;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return Colors.amber;
    if (rank == 2) return Colors.grey[300]!;
    if (rank == 3) return Colors.brown[300]!;
    return Colors.transparent;
  }
}
