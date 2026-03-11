import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import '../ui/app_theme.dart';

class SessionStatsScreen extends StatefulWidget {
  final Map<String, dynamic> stats;
  final String? eventName;

  const SessionStatsScreen({
    super.key,
    required this.stats,
    this.eventName,
  });

  @override
  State<SessionStatsScreen> createState() => _SessionStatsScreenState();
}

class _SessionStatsScreenState extends State<SessionStatsScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSharing = false;

  Future<void> _shareSession() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final image = await _screenshotController.capture();
      if (image != null) {
        final points = widget.stats['points'] ?? 0;
        final event = widget.eventName ?? 'Dance Session';
        final text = 'I just scored $points points in $event! 🎵🕺 #LoopedApp #DanceFitness';

        final xFile = XFile.fromData(
          image,
          name: 'looped_session.png',
          mimeType: 'image/png',
        );
        
        await Share.shareXFiles(
          [xFile],
          text: text,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.stats['points'] ?? 0;
    final durationSec = widget.stats['duration_seconds'] ?? widget.stats['duration_sec'] ?? 0;
    final motionStats = widget.stats['motion_stats'] as Map<String, dynamic>?;

    final minutes = (durationSec ~/ 60).toString().padLeft(2, '0');
    final seconds = (durationSec % 60).toString().padLeft(2, '0');
    final durationStr = '$minutes:$seconds';

    final steps = widget.stats['steps']?.toString() ?? '0';
    final distance = widget.stats['distanceKm']?.toString() ?? '0.00';
    final speed = widget.stats['speedKmh']?.toString() ?? '0.0';
    final pace = widget.stats['pace']?.toString() ?? "0'00\"";
    final elevation = widget.stats['elevation']?.toString() ?? '0';
    final calories = widget.stats['calories']?.toString() ?? '0';

    const int goal = 1500; // Mock goal for UI
    final double progress = (points / goal).clamp(0.0, 1.0);

    // Intensity History Processing
    final List<dynamic> intensityRaw = motionStats?['intensity_history'] ?? [];
    final List<double> intensities = intensityRaw.map((v) => (v as num).toDouble()).toList();
    final String? startTimeStr = motionStats?['start_time'];
    final DateTime startTime = startTimeStr != null 
        ? DateTime.parse(startTimeStr) 
        : DateTime.now().subtract(Duration(seconds: durationSec));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ),
        title: const Text('Session Summary',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          _isSharing 
            ? const Center(child: Padding(padding: EdgeInsets.only(right: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent))))
            : IconButton(
              icon: const Icon(Icons.share, color: Colors.white),
              onPressed: _shareSession,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Screenshot(
                controller: _screenshotController,
                child: Container(
                  color: Colors.black, // Background for screenshot
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      // Looped Logo for Sharing
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.loop, color: AppTheme.accent, size: 24),
                          const SizedBox(width: 10),
                          Text('LOOPED', style: AppTheme.labelLarge.copyWith(color: AppTheme.accent, letterSpacing: 4, fontWeight: FontWeight.w900, fontSize: 18)),
                        ],
                      ),
                      if (widget.eventName != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.eventName!.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      // points circle
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 220,
                            height: 220,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 16,
                              backgroundColor: const Color(0xFF161616),
                              valueColor:
                                  const AlwaysStoppedAnimation(AppTheme.accent),
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('TOTAL POINTS',
                                  style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5)),
                              const SizedBox(height: 8),
                              Text(
                                _formatNumber(points),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text('Goal: ${_formatNumber(goal)}',
                                  style: const TextStyle(
                                      color: AppTheme.accent,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),
                      
                      // Top Stats High-Level
                      Row(
                        children: [
                          Expanded(
                              child: _buildMainStatCard(
                                  'DURATION', durationStr, Icons.timer)),
                          const SizedBox(width: 16),
                          Expanded(
                              child: _buildMainStatCard('AVG POINTS/SEC',
                                  _calculatePPS(points, durationSec), Icons.speed)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Detail Stats Grid
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1.8,
                        children: [
                          _buildDetailStatCard(
                              'DISTANCE', distance, 'km', Icons.map),
                          _buildDetailStatCard('SPEED', speed, 'km/h', Icons.speed),
                          _buildDetailStatCard(
                              'STEPS',
                              _formatNumber(int.tryParse(steps) ?? 0),
                              'steps',
                              Icons.directions_run),
                          _buildDetailStatCard('PACE', pace, 'min/km', Icons.timer),
                          _buildDetailStatCard(
                              'ELEVATION', elevation, 'm', Icons.terrain),
                          _buildDetailStatCard('CALORIES', calories, 'kcal',
                              Icons.local_fire_department),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Motion Stats
                      if (motionStats != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131313),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('MOTION INTENSITY HISTORY',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5)),
                              const SizedBox(height: 24),
                              
                              // Real Histogram based on history
                              intensities.isEmpty
                              ? const Center(child: Text('Not enough data to show history', style: TextStyle(color: Colors.grey, fontSize: 12)))
                              : SizedBox(
                                height: 80,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: intensities.asMap().entries.map((entry) {
                                    final int idx = entry.key;
                                    final double intensity = entry.value;
                                    // Scale intensity (expected 0-10 range roughly)
                                    final double heightFactor = (intensity / 8.0).clamp(0.1, 1.0);
                                    
                                    // Calculate time for this bar
                                    final DateTime barTime = startTime.add(Duration(seconds: idx * 30));
                                    final String timeLabel = "${barTime.hour}:${barTime.minute.toString().padLeft(2, '0')}";

                                    return Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        _buildBar(heightFactor),
                                        const SizedBox(height: 8),
                                        Text(timeLabel, style: const TextStyle(color: Colors.grey, fontSize: 8)),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),

                              const SizedBox(height: 24),
                              _buildMotionDetailRow(
                                  'Max Intensity',
                                  'Level ${(motionStats['max_intensity'] ?? 0).toInt()}',
                                  Icons.trending_up),
                              const SizedBox(height: 16),
                              _buildMotionDetailRow(
                                  'Avg Intensity',
                                  'Level ${(motionStats['avg_intensity'] ?? 0).toInt()}',
                                  Icons.bar_chart),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Sticky Bottom Button (Outside Screenshot)
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32)),
                  elevation: 0,
                ),
                child: const Text(
                  'CONTINUE',
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(double heightFactor) {
    return Container(
      width: 24,
      height: 40 * heightFactor,
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(heightFactor * 0.8 + 0.2),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  String _calculatePPS(dynamic points, dynamic duration) {
    if (duration == 0) return '0.0';
    return (points / duration).toStringAsFixed(1);
  }

  Widget _buildMainStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF131313),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E), shape: BoxShape.circle),
            child: Icon(icon, color: AppTheme.accent, size: 16),
          ),
          const SizedBox(height: 16),
          Text(label,
              style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDetailStatCard(
      String label, String value, String unit, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white60, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMotionDetailRow(String label, String value, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.grey, size: 18),
            const SizedBox(width: 12),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12)),
          child: Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
