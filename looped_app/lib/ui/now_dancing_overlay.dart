import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/dance_session_manager.dart';
import '../screens/live_dance_screen.dart';
import 'app_theme.dart';

/// Global floating overlay shown when user is actively dancing.
class NowDancingOverlay extends StatefulWidget {
  final Widget child;

  const NowDancingOverlay({super.key, required this.child});

  @override
  State<NowDancingOverlay> createState() => _NowDancingOverlayState();
}

class _NowDancingOverlayState extends State<NowDancingOverlay> {
  bool _isMinimized = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<DanceSessionManager>(
      builder: (context, manager, _) {
        return Stack(
          children: [
            widget.child,
            if (manager.isDancing) _buildOverlay(context, manager),
          ],
        );
      },
    );
  }

  Widget _buildOverlay(BuildContext context, DanceSessionManager manager) {
    return Positioned(
      bottom: 90,
      left: AppTheme.spacingMd,
      right: AppTheme.spacingMd,
      child: Material(
        color: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(
              _isMinimized ? AppTheme.spacingSm : AppTheme.spacingMd),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
            boxShadow: AppTheme.elevatedShadow,
          ),
          child: _isMinimized
              ? _buildMinimized(context, manager)
              : _buildExpanded(context, manager),
        ),
      ),
    );
  }

  Widget _buildMinimized(BuildContext context, DanceSessionManager manager) {
    return GestureDetector(
      onTap: () => setState(() => _isMinimized = false),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppTheme.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppTheme.spacingSm),
          Text(manager.formattedTime, style: AppTheme.titleMedium),
          const SizedBox(width: AppTheme.spacingMd),
          Text('${manager.points} pts',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.accent)),
          const Spacer(),
          const Icon(Icons.expand_less,
              color: AppTheme.textSecondary, size: 20),
        ],
      ),
    );
  }

  Widget _buildExpanded(BuildContext context, DanceSessionManager manager) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingSm,
                vertical: AppTheme.spacingXs,
              ),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingXs),
                  Text('DANCING',
                      style:
                          AppTheme.labelSmall.copyWith(color: AppTheme.accent)),
                ],
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _isMinimized = true),
              child:
                  const Icon(Icons.expand_more, color: AppTheme.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMd),

        // Stats row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStat('TIME', manager.formattedTime),
            Container(width: 1, height: 32, color: AppTheme.surfaceBorder),
            _buildStat('POINTS', '${manager.points}'),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMd),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.arrow_back,
                label: 'Return',
                color: AppTheme.info,
                onTap: () => _navigateToLiveDance(context, manager),
              ),
            ),
            const SizedBox(width: AppTheme.spacingSm),
            Expanded(
              child: _buildActionButton(
                icon: Icons.stop,
                label: 'Stop',
                color: AppTheme.warning,
                onTap: () => _stopSession(context, manager),
              ),
            ),
            const SizedBox(width: AppTheme.spacingSm),
            Expanded(
              child: _buildActionButton(
                icon: Icons.exit_to_app,
                label: 'Leave',
                color: AppTheme.error,
                onTap: () => _showLeaveConfirmation(context, manager),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: AppTheme.labelSmall),
        const SizedBox(height: AppTheme.spacingXs),
        Text(value, style: AppTheme.titleLarge),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: AppTheme.spacingXs),
            Text(label, style: AppTheme.labelSmall.copyWith(color: color)),
          ],
        ),
      ),
    );
  }

  void _navigateToLiveDance(BuildContext context, DanceSessionManager manager) {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => LiveDanceScreen(eventId: manager.eventId!)),
    );
  }

  Future<void> _stopSession(
      BuildContext context, DanceSessionManager manager) async {
    try {
      await manager.stopSession();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session saved ✓')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showLeaveConfirmation(
      BuildContext context, DanceSessionManager manager) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: Text('Leave Event?', style: AppTheme.titleMedium),
        content: Text(
            'Your session will be stopped and you will leave the event.',
            style: AppTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: AppTheme.dangerButtonStyle,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await manager.leaveEvent();
        if (context.mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}
