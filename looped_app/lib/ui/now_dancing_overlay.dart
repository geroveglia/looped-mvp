import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/dance_session_manager.dart';
import '../screens/live_dance_screen.dart';
import '../screens/solo_dance_screen.dart';
import 'app_theme.dart';

/// Global floating "Pill" overlay shown when user is actively dancing.
class NowDancingOverlay extends StatelessWidget {
  final Widget child;

  const NowDancingOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<DanceSessionManager>(
      builder: (context, manager, _) {
        return Stack(
          children: [
            child,
            if (manager.isDancing) _buildPill(context, manager),
          ],
        );
      },
    );
  }

  Widget _buildPill(BuildContext context, DanceSessionManager manager) {
    return Positioned(
      bottom: 20, // Lower position for a pill
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.95),
            borderRadius: BorderRadius.circular(50), // Fully rounded pill
            border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              if (!manager.isPaused)
                BoxShadow(
                  color: AppTheme.accent.withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMd, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Activity Indicator
                _buildActivityIndicator(context, manager),
                const SizedBox(width: AppTheme.spacingMd),

                // Stats: Time
                _buildStatItem(
                    Icons.timer, manager.formattedTime, AppTheme.textPrimary),
                const SizedBox(width: AppTheme.spacingMd),

                // Stats: Points/Steps
                _buildStatItem(
                    Icons.flash_on, '${manager.points}', AppTheme.accent),
                const SizedBox(width: AppTheme.spacingMd),

                // Vertical Divider
                Container(
                  height: 24,
                  width: 1,
                  color: AppTheme.surfaceBorder,
                ),
                const SizedBox(width: AppTheme.spacingSm),

                // Controls
                _buildControls(context, manager),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityIndicator(
      BuildContext context, DanceSessionManager manager) {
    return GestureDetector(
      onTap: () => _navigateToSession(context, manager), // Navigate on tap
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: manager.isPaused ? AppTheme.warning : AppTheme.accent,
          shape: BoxShape.circle,
          boxShadow: [
            if (!manager.isPaused)
              BoxShadow(
                color: AppTheme.accent.withOpacity(0.6),
                blurRadius: 8,
                spreadRadius: 2,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTheme.labelLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
            fontFeatures: [const FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildControls(BuildContext context, DanceSessionManager manager) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Play/Pause
        IconButton(
          constraints: const BoxConstraints(), // Tight fit
          padding: const EdgeInsets.all(4),
          icon: Icon(
            manager.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            color: AppTheme.textPrimary,
          ),
          onPressed: () {
            if (manager.isPaused) {
              manager.resumeSession();
            } else {
              manager.pauseSession();
            }
          },
        ),
        const SizedBox(width: 4),
        // Stop
        IconButton(
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.all(4),
          icon: const Icon(Icons.stop_rounded, color: AppTheme.error),
          onPressed: () => _confirmStop(context, manager),
        ),
      ],
    );
  }

  void _navigateToSession(BuildContext context, DanceSessionManager manager) {
    // If we are already on the correct screen, do nothing.
    // This is hard to detect reliably without route tracking, but we can just push.
    if (manager.sessionType == SessionType.solo) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SoloDanceScreen()),
      );
    } else if (manager.eventId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => LiveDanceScreen(eventId: manager.eventId!)),
      );
    }
  }

  Future<void> _confirmStop(
      BuildContext context, DanceSessionManager manager) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('End Session?', style: AppTheme.titleMedium),
        content: const Text('Are you sure you want to stop dancing?',
            style: AppTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: AppTheme.dangerButtonStyle,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Stop'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await manager.stopSession();
    }
  }
}
