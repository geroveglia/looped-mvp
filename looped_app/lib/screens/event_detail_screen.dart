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
import 'session_stats_screen.dart';

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

  Future<void> _leaveEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: const Text('Leave Event?', style: AppTheme.titleMedium),
        content: const Text('Are you sure you want to leave?',
            style: AppTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: AppTheme.dangerButtonStyle,
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

  Future<void> _viewMyStats() async {
    final service = Provider.of<EventService>(context, listen: false);
    try {
      final sessions = await service.getMyEventSessions(_event['_id']);
      if (sessions.isNotEmpty && mounted) {
        // Show latest session
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SessionStatsScreen(
                stats: sessions.first, // API returns sorted by start date desc
                eventName: _event['name'])));
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("No dance records found.")));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error fetching stats: $e")));
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

    return Scaffold(
      backgroundColor: AppTheme.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 8, top: 8),
          decoration: const BoxDecoration(
            color: Colors.black45,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppTheme.spacingLg, 100, AppTheme.spacingLg, AppTheme.spacingLg),
        child: Column(
          children: [
            // Hero Section (Icon + Title + Status)
            _buildHeroSection(status),
            const SizedBox(height: AppTheme.spacingXl),

            // Host Controls (if host)
            if (_isHost) ...[
              _buildHostControls(status),
              const SizedBox(height: AppTheme.spacingLg),
            ],

            // Action Buttons (Join/Start/Leave)
            _buildActionButtons(isLive, isWaiting),
            const SizedBox(height: AppTheme.spacingXl),

            // Info Grid
            _buildInfoGrid(),
            const SizedBox(height: AppTheme.spacingXl),

            // Private Event Code
            if (_event['visibility'] == 'private' && _isHost)
              _buildPrivateCodeSection(),

            const SizedBox(height: AppTheme.spacingXl),

            // Leaderboard Section
            const Row(
              children: [
                Icon(Icons.leaderboard, color: AppTheme.accent, size: 20),
                SizedBox(width: 8),
                Text('LEADERBOARD', style: AppTheme.labelLarge),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMd),
            _buildLeaderboardCard(entries),

            // My Position
            if (myPos != null) ...[
              const SizedBox(height: AppTheme.spacingMd),
              _buildMyPositionCard(myPos),
            ],

            const SizedBox(height: 80), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(String status) {
    final iconChar = _event['icon'] ?? '🎵';

    return Column(
      children: [
        // Pulsing / Glowy Icon
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.surfaceLight,
            border:
                Border.all(color: AppTheme.accent.withOpacity(0.5), width: 2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withOpacity(0.2),
                blurRadius: 30,
                spreadRadius: 5,
              )
            ],
            image: iconChar.startsWith('/')
                ? DecorationImage(
                    image: NetworkImage('${ApiService.baseUrl}$iconChar'),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: !iconChar.startsWith('/')
              ? Center(
                  child: Text(iconChar, style: const TextStyle(fontSize: 40)))
              : null,
        ),
        const SizedBox(height: AppTheme.spacingLg),

        Text(
          _event['name'] ?? 'Event Name',
          textAlign: TextAlign.center,
          style: AppTheme.titleLarge.copyWith(fontSize: 28),
        ),
        const SizedBox(height: AppTheme.spacingXs),
        Text(
          _isHost ? 'Hosted by You' : 'Party Event',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        StatusBadge(status: status),
      ],
    );
  }

  Widget _buildHostControls(String status) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.textTertiary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.admin_panel_settings,
                  color: AppTheme.textSecondary, size: 16),
              SizedBox(width: 8),
              Text("HOST CONTROLS", style: AppTheme.labelSmall),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Row(
            children: [
              if (status == 'waiting')
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _changeStatus('active'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent, // Green
                      foregroundColor: AppTheme.background,
                    ),
                    child: const Text('START EVENT'),
                  ),
                ),
              if (status == 'active')
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _changeStatus('ended'),
                    // "End" is now a Soft Green button as requested (all buttons green)
                    // or maybe an outlined green button to differentiate?
                    // Let's use a dark green background with opacity to indicate "Stop" but keep it green family.
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent.withOpacity(0.2),
                      foregroundColor: AppTheme.accent,
                      elevation: 0,
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

  Widget _buildActionButtons(bool isLive, bool isWaiting) {
    return Column(
      children: [
        // Primary Button: Join / Start
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: isLive ? _joinAndStart : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent, // Solid Green
              foregroundColor: AppTheme.background,
              shadowColor: AppTheme.accent.withOpacity(0.4),
              elevation: 8,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
            ),
            child: Text(
              isWaiting
                  ? 'WAITING FOR HOST'
                  : isLive
                      ? 'JOIN DANCE FLOOR'
                      : 'EVENT ENDED',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingMd),

        // Secondary Button: Leave
        // User requested: "Green buttons ... change opacity"
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: _leaveEvent,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.accent
                  .withOpacity(0.7), // Green text, slightly dimmed
              backgroundColor:
                  AppTheme.accent.withOpacity(0.05), // Very faint green bg
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
            ),
            child: const Text('LEAVE EVENT'),
          ),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _viewMyStats,
            icon: const Icon(Icons.bar_chart, size: 18),
            label: const Text('VIEW MY STATS'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textPrimary,
              side: BorderSide(color: AppTheme.textSecondary.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoGrid() {
    final genre = (_event['genre'] ?? 'Other').toString().toUpperCase();
    final venue = _event['venue_name'] ?? _event['city'] ?? 'Unknown';
    final date = DateTime.tryParse(_event['starts_at'] ?? '');
    final dateStr = date != null
        ? "${date.day}/${date.month} • ${date.hour}:${date.minute.toString().padLeft(2, '0')}"
        : "TBD";

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildInfoColumn("GENRE", genre, Icons.music_note),
          Container(width: 1, height: 40, color: AppTheme.surfaceBorder),
          _buildInfoColumn("WHEN", dateStr, Icons.calendar_today),
          Container(width: 1, height: 40, color: AppTheme.surfaceBorder),
          _buildInfoColumn("WHERE", venue, Icons.location_on),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppTheme.textTertiary),
          const SizedBox(height: 8),
          Text(label, style: AppTheme.labelSmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivateCodeSection() {
    final inviteCode = _event['invite_code'] ?? '---';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.lock_outline,
              color: AppTheme.textSecondary, size: 20),
          const SizedBox(height: 4),
          const Text("PRIVATE CODE", style: AppTheme.labelSmall),
          const SizedBox(height: 8),
          SelectableText(
            inviteCode,
            style: AppTheme.titleLarge
                .copyWith(color: AppTheme.accent, letterSpacing: 4),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardCard(List<LeaderboardEntry> entries) {
    if (entries.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        decoration: AppTheme.cardDecoration,
        child: const Column(
          children: [
            Icon(Icons.people_outline, size: 32, color: AppTheme.textTertiary),
            SizedBox(height: 8),
            Text("Dance floor is empty.", style: AppTheme.bodyMedium),
          ],
        ),
      );
    }

    final maxPoints = entries.first.points;

    return Container(
      decoration: AppTheme.cardDecoration,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: entries.take(5).toList().asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isFirst = index == 0;
          return Container(
            color: isFirst ? AppTheme.accent.withOpacity(0.05) : null,
            child: _buildLeaderboardItem(index + 1, item, maxPoints),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLeaderboardItem(
      int rank, LeaderboardEntry entry, int maxPoints) {
    final progress = maxPoints > 0 ? entry.points / maxPoints : 0.0;

    Color rankColor;
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700);
    } else if (rank == 2)
      rankColor = const Color(0xFFC0C0C0);
    else if (rank == 3)
      rankColor = const Color(0xFFCD7F32);
    else
      rankColor = AppTheme.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '#$rank',
              style: TextStyle(
                  color: rankColor, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(entry.username,
                            style: AppTheme.bodyLarge
                                .copyWith(fontWeight: FontWeight.w500))),
                    Text('${entry.points} pts',
                        style: AppTheme.bodySmall
                            .copyWith(color: AppTheme.textSecondary)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: AppTheme.surfaceBorder,
                    valueColor: AlwaysStoppedAnimation(rank == 1
                        ? AppTheme.accent
                        : AppTheme.accent.withOpacity(0.6)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyPositionCard(MyPosition myPos) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.accent.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
                color: AppTheme.accent, shape: BoxShape.circle),
            child: const Icon(Icons.person, color: Colors.black, size: 16),
          ),
          const SizedBox(width: 12),
          const Text("Your Rank",
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppTheme.accent)),
          const Spacer(),
          Text("#${myPos.rank}",
              style: AppTheme.titleLarge.copyWith(color: Colors.white)),
        ],
      ),
    );
  }
}
