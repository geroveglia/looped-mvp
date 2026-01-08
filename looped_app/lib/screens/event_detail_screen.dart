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

  Future<void> _leaveEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: Text('Leave Event?', style: AppTheme.titleMedium),
        content:
            Text('Are you sure you want to leave?', style: AppTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_event['name'] ?? 'Event', style: AppTheme.titleMedium),
            Text(
              _isHost ? 'You are Host' : 'Participant',
              style: AppTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            _buildHeaderCard(status),
            const SizedBox(height: AppTheme.spacingLg),

            // Host Controls
            if (_isHost) ...[
              _buildHostControls(status),
              const SizedBox(height: AppTheme.spacingLg),
            ],

            // Action Buttons
            _buildActionButtons(isLive, isWaiting),
            const SizedBox(height: AppTheme.spacingXl),

            // Leaderboard Section
            Text('LEADERBOARD', style: AppTheme.labelLarge),
            const SizedBox(height: AppTheme.spacingMd),

            _buildLeaderboardCard(entries),

            // My Position
            if (myPos != null) ...[
              const SizedBox(height: AppTheme.spacingMd),
              _buildMyPositionCard(myPos),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(String status) {
    final genre = (_event['genre'] ?? 'Other').toString();
    final venue = _event['venue_name'] ?? _event['city'] ?? 'Unknown';
    final date = DateTime.tryParse(_event['starts_at'] ?? '');
    final dateStr = date != null
        ? "${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}"
        : "TBD";
    final iconChar = _event['icon'] ?? '🎵';

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          // Event Image
          _buildEventImage(iconChar),
          const SizedBox(height: AppTheme.spacingMd),

          // Status Badge
          StatusBadge(status: status),
          const SizedBox(height: AppTheme.spacingLg),

          // Info Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoItem(Icons.music_note, genre),
              _buildInfoItem(Icons.calendar_today, dateStr),
              _buildInfoItem(Icons.location_on, venue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventImage(String iconValue) {
    if (iconValue.startsWith('/')) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.surfaceBorder, width: 2),
          image: DecorationImage(
            image: NetworkImage('${ApiService.baseUrl}$iconValue'),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.surfaceLight,
          border: Border.all(color: AppTheme.surfaceBorder, width: 2),
        ),
        child: Center(
          child: Text(iconValue, style: const TextStyle(fontSize: 36)),
        ),
      );
    }
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 20),
        const SizedBox(height: AppTheme.spacingXs),
        Text(
          text,
          style: AppTheme.bodySmall,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildHostControls(String status) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          const Icon(Icons.settings, color: AppTheme.textSecondary, size: 20),
          const SizedBox(width: AppTheme.spacingMd),
          Text('Host Controls', style: AppTheme.titleSmall),
          const Spacer(),
          if (status == 'waiting')
            ElevatedButton(
              onPressed: () => _changeStatus('active'),
              child: const Text('START'),
            ),
          if (status == 'active')
            ElevatedButton(
              style: AppTheme.dangerButtonStyle,
              onPressed: () => _changeStatus('ended'),
              child: const Text('END'),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isLive, bool isWaiting) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: isLive ? _joinAndStart : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              disabledBackgroundColor: AppTheme.surfaceLight,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
            ),
            child: Text(
              isWaiting
                  ? 'WAITING FOR HOST'
                  : isLive
                      ? 'START DANCING'
                      : 'EVENT ENDED',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isLive ? AppTheme.background : AppTheme.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: _leaveEvent,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.error),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
            ),
            child: Text(
              'LEAVE EVENT',
              style: AppTheme.labelLarge.copyWith(color: AppTheme.error),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardCard(List<LeaderboardEntry> entries) {
    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        decoration: AppTheme.cardDecoration,
        child: Center(
          child: Column(
            children: [
              Icon(Icons.leaderboard_outlined,
                  size: 48, color: AppTheme.textTertiary),
              const SizedBox(height: AppTheme.spacingMd),
              Text('No dancers yet', style: AppTheme.bodyMedium),
              Text('Be the first!', style: AppTheme.bodySmall),
            ],
          ),
        ),
      );
    }

    final maxPoints = entries.first.points;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: AppTheme.cardDecoration,
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
        barColor = const Color(0xFFFFD700);
        break;
      case 2:
        barColor = const Color(0xFFC0C0C0);
        break;
      case 3:
        barColor = const Color(0xFFCD7F32);
        break;
      default:
        barColor = AppTheme.accent;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 32,
            child: rank <= 3
                ? Icon(Icons.emoji_events, color: barColor, size: 20)
                : Text('#$rank',
                    style: AppTheme.bodySmall, textAlign: TextAlign.center),
          ),
          const SizedBox(width: AppTheme.spacingMd),

          // Name + Progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.username, style: AppTheme.bodyLarge),
                const SizedBox(height: AppTheme.spacingXs),
                ProgressBar(progress: progress, color: barColor),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacingMd),

          // Points
          Text(
            '${entry.points}',
            style: AppTheme.titleMedium.copyWith(color: barColor),
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
        border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text('YOU',
              style: AppTheme.labelLarge.copyWith(color: AppTheme.accent)),
          const Spacer(),
          Text('#${myPos.rank}', style: AppTheme.titleLarge),
          const SizedBox(width: AppTheme.spacingMd),
          Text('${myPos.points} pts',
              style: AppTheme.titleMedium.copyWith(color: AppTheme.accent)),
        ],
      ),
    );
  }
}
