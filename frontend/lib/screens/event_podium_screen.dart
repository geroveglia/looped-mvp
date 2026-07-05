import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../models/leaderboard_model.dart';
import '../services/api_service.dart';
import '../services/event_service.dart';
import '../ui/app_theme.dart';
import '../ui/ranked_avatar.dart';
import 'session_stats_screen.dart';

/// Final results of an ended event: top-3 podium, your position, and an
/// Instagram-ready share card. This is THE shareable moment of the app.
class EventPodiumScreen extends StatefulWidget {
  final String eventId;
  final String eventName;

  const EventPodiumScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<EventPodiumScreen> createState() => _EventPodiumScreenState();
}

class _EventPodiumScreenState extends State<EventPodiumScreen> {
  final ApiService _api = ApiService();
  final ScreenshotController _screenshotController = ScreenshotController();

  LeaderboardResponse? _data;
  bool _isLoading = true;
  String? _error;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    try {
      final response =
          await _api.get('/events/${widget.eventId}/leaderboard');
      if (mounted) {
        setState(() {
          _data = LeaderboardResponse.fromJson(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _share() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final image = await _screenshotController.capture();
      if (image == null) return;

      final myRank = _data?.myPosition.rank ?? 0;
      final text = myRank > 0
          ? 'Salí #$myRank en ${widget.eventName} 🏆🕺 #LoopedApp'
          : 'Así quedó el podio de ${widget.eventName} 🏆 #LoopedApp';

      await Share.shareXFiles(
        [XFile.fromData(image, name: 'looped_podium.png', mimeType: 'image/png')],
        text: text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error sharing: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _viewMySessionStats() async {
    try {
      final service = Provider.of<EventService>(context, listen: false);
      final sessions = await service.getMyEventSessions(widget.eventId);
      if (!mounted) return;
      if (sessions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No session data found for you in this event.')));
        return;
      }
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SessionStatsScreen(
          stats: sessions.first,
          eventName: widget.eventName,
        ),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text('Final Results',
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.redAccent, size: 48),
                        const SizedBox(height: 16),
                        Text('Error: $_error',
                            style: const TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                            onPressed: _loadResults,
                            child: const Text('Try Again')),
                      ],
                    ),
                  ),
                )
              : _buildResults(),
    );
  }

  Widget _buildResults() {
    final entries = _data?.leaderboard ?? [];
    final my = _data?.myPosition;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        children: [
          // Shareable card (captured by the screenshot controller)
          Screenshot(
            controller: _screenshotController,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppTheme.accent.withOpacity(0.25)),
              ),
              child: Column(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 36)),
                  const SizedBox(height: 8),
                  Text(
                    widget.eventName.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1),
                  ),
                  const SizedBox(height: 4),
                  const Text('FINAL PODIUM',
                      style: TextStyle(
                          color: AppTheme.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2)),
                  const SizedBox(height: 28),
                  if (entries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('Nobody danced at this event',
                          style: TextStyle(color: Colors.grey)),
                    )
                  else
                    _buildPodium(entries),
                  if (my != null && my.rank > 0) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(100),
                        border:
                            Border.all(color: AppTheme.accent.withOpacity(0.3)),
                      ),
                      child: Text(
                        'Tu posición: #${my.rank} · ${_formatNumber(my.points)} pts',
                        style: const TextStyle(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text('Looped — dance. compete. repeat.',
                      style: TextStyle(color: Colors.grey, fontSize: 10)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isSharing ? null : _share,
                    icon: _isSharing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.share, color: Colors.black, size: 20),
                    label: const Text('SHARE',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _viewMySessionStats,
                    icon: const Icon(Icons.bar_chart,
                        color: AppTheme.accent, size: 20),
                    label: const Text('MY STATS',
                        style: TextStyle(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.accent.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100)),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Rest of the top 10
          if (entries.length > 3) ...[
            const SizedBox(height: 32),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('TOP ${entries.length.clamp(0, 10)}',
                  style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
            ),
            const SizedBox(height: 12),
            ...entries.skip(3).take(7).toList().asMap().entries.map((e) {
              final index = e.key + 4;
              final item = e.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF131313),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text('#$index',
                          style: const TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    RankedAvatar(
                        avatarUrl: item.avatarUrl, rank: item.rank, size: 34),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(item.username,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                    ),
                    Text('${_formatNumber(item.points)} pts',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildPodium(List<LeaderboardEntry> entries) {
    final first = entries.isNotEmpty ? entries[0] : null;
    final second = entries.length > 1 ? entries[1] : null;
    final third = entries.length > 2 ? entries[2] : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _podiumSpot(second, '🥈', 64, '2nd', 56)),
        Expanded(child: _podiumSpot(first, '🥇', 84, '1st', 88)),
        Expanded(child: _podiumSpot(third, '🥉', 64, '3rd', 36)),
      ],
    );
  }

  Widget _podiumSpot(LeaderboardEntry? entry, String medal, double avatarSize,
      String label, double pedestalHeight) {
    if (entry == null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(medal, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 6),
        RankedAvatar(
            avatarUrl: entry.avatarUrl, rank: entry.rank, size: avatarSize),
        const SizedBox(height: 8),
        Text(
          entry.username,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        Text('${_formatNumber(entry.points)} pts',
            style: const TextStyle(color: AppTheme.accent, fontSize: 11)),
        const SizedBox(height: 8),
        Container(
          height: pedestalHeight,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.12),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
          ),
          child: Center(
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}
