import 'package:flutter/material.dart';
import '../ui/app_theme.dart';

class SessionStatsScreen extends StatelessWidget {
  final Map<String, dynamic> stats;
  final String? eventName;

  const SessionStatsScreen({
    super.key,
    required this.stats,
    this.eventName,
  });

  @override
  Widget build(BuildContext context) {
    final points = stats['points'] ?? 0;
    final durationSec = stats['duration_seconds'] ?? stats['duration_sec'] ?? 0;
    final motionStats = stats['motion_stats'] as Map<String, dynamic>?;

    final minutes = (durationSec ~/ 60).toString().padLeft(2, '0');
    final seconds = (durationSec % 60).toString().padLeft(2, '0');
    final durationStr = '$minutes:$seconds';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Session Summary', style: AppTheme.titleSmall),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          children: [
            const SizedBox(height: AppTheme.spacingLg),
            Text(
              eventName ?? 'Solo Session',
              style: AppTheme.displayMedium
                  .copyWith(fontSize: 24, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingXl),

            // Big Points Circle
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.accent, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    points.toString(),
                    style: AppTheme.displayLarge.copyWith(fontSize: 48),
                  ),
                  const Text('POINTS', style: AppTheme.labelMedium),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingXl),

            // Stats Grid
            Row(
              children: [
                Expanded(
                    child:
                        _buildStatCard('DURATION', durationStr, Icons.timer)),
                const SizedBox(width: AppTheme.spacingMd),
                Expanded(
                    child: _buildStatCard('AVG POINTS/SEC',
                        _calculatePPS(points, durationSec), Icons.speed)),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMd),

            // Motion Stats (if available)
            if (motionStats != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('MOTION DETAILS', style: AppTheme.labelSmall),
                    const SizedBox(height: AppTheme.spacingMd),
                    _buildDetailRow(
                        'Max Intensity',
                        motionStats['max_intensity']?.toStringAsFixed(1) ??
                            '-'),
                    const Divider(color: AppTheme.surfaceBorder),
                    _buildDetailRow(
                        'Avg Intensity',
                        motionStats['avg_intensity']?.toStringAsFixed(1) ??
                            '-'),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: AppTheme.primaryButtonStyle.copyWith(
                minimumSize:
                    const MaterialStatePropertyAll(Size(double.infinity, 50)),
              ),
              child: const Text('CONTINUE'),
            ),
          ],
        ),
      ),
    );
  }

  String _calculatePPS(dynamic points, dynamic duration) {
    if (duration == 0) return '0.0';
    return (points / duration).toStringAsFixed(1);
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          Icon(icon, color: AppTheme.accent, size: 28),
          const SizedBox(height: 8),
          Text(value, style: AppTheme.titleLarge),
          const SizedBox(height: 4),
          Text(label, style: AppTheme.labelSmall),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
          Text(value,
              style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
