import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/dance_session_manager.dart';
import '../screens/live_dance_screen.dart';
import '../screens/solo_dance_screen.dart';
import 'app_theme.dart';

/// Global floating "Pill" overlay shown when user is actively dancing.
/// Features a unified, draggable, and smoothly animating design.
class NowDancingOverlay extends StatefulWidget {
  final Widget child;

  const NowDancingOverlay({super.key, required this.child});

  @override
  State<NowDancingOverlay> createState() => _NowDancingOverlayState();
}

class _NowDancingOverlayState extends State<NowDancingOverlay> {
  bool _isMinimized = false;
  Offset? _position;

  @override
  Widget build(BuildContext context) {
    // Initialize position independently of build cycles to avoid resets
    if (_position == null && MediaQuery.of(context).size.width > 0) {
      final size = MediaQuery.of(context).size;
      // Default Position: Center-ish, bottom area (above nav bar)
      _position = Offset(size.width * 0.1, size.height - 180);
    }

    return Consumer<DanceSessionManager>(
      builder: (context, manager, _) {
        return Stack(
          children: [
            widget.child,
            if (manager.isDancing && _position != null)
              _buildDraggablePill(context, manager),
          ],
        );
      },
    );
  }

  Widget _buildDraggablePill(
      BuildContext context, DanceSessionManager manager) {
    return Positioned(
      left: _position!.dx,
      top: _position!.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position = _position! + details.delta;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.fastOutSlowIn, // Smooth "bouncy" feel
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.95),
            borderRadius: BorderRadius.circular(50),
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
          child: AnimatedSize(
            duration: const Duration(milliseconds: 400),
            curve: Curves.fastOutSlowIn,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min, // Hug content
              children: [
                // Left side is always the activity indicator or minimize toggle
                GestureDetector(
                    onTap: () {
                      // If minimized, expanding is handled by the overall tap or specific area?
                      // User request: "achique y agrande".
                      // Let's make the indicator the toggle for minimization if expanded.
                      // And the whole pill the toggle for expansion if minimized?
                      setState(() {
                        _isMinimized = !_isMinimized;
                      });
                    },
                    child: _isMinimized
                        ? _buildActivityIndicator(context, manager,
                            small: true) // Just the dot
                        : const Icon(Icons.close_fullscreen,
                            size: 18,
                            color: AppTheme.textSecondary) // Minimize icon
                    ),

                const SizedBox(width: AppTheme.spacingMd),

                // Content Swapping
                Flexible(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isMinimized
                        ? _buildMinimizedContent(manager)
                        : _buildExpandedContent(context, manager),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMinimizedContent(DanceSessionManager manager) {
    // Key is important for AnimatedSwitcher to know it's a different widget
    return Row(
      key: const ValueKey('minimized'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          manager.formattedTime,
          style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Icon(Icons.flash_on, size: 14, color: AppTheme.accent),
        const SizedBox(width: 2),
        Text(
          '${manager.points}',
          style: AppTheme.labelMedium.copyWith(color: AppTheme.accent),
        ),
      ],
    );
  }

  Widget _buildExpandedContent(
      BuildContext context, DanceSessionManager manager) {
    return Row(
      key: const ValueKey('expanded'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActivityIndicator(context, manager),
        const SizedBox(width: AppTheme.spacingMd),
        _buildStatItem(
            Icons.timer, manager.formattedTime, AppTheme.textPrimary),
        const SizedBox(width: AppTheme.spacingMd),
        _buildStatItem(Icons.flash_on, '${manager.points}', AppTheme.accent),
        const SizedBox(width: AppTheme.spacingMd),
        Container(width: 1, height: 24, color: AppTheme.surfaceBorder),
        const SizedBox(width: AppTheme.spacingSm),
        _buildControls(context, manager),
      ],
    );
  }

  Widget _buildActivityIndicator(
      BuildContext context, DanceSessionManager manager,
      {bool small = false}) {
    Widget indicator = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: small ? 14 : 12,
      height: small ? 14 : 12,
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
    );

    // In the new design, the indicator itself inside expanded view is just visual or Nav link?
    // User wants "click to expand/shrink".
    // If let's keep indicator as Nav Link in Expanded mode.
    // In minimized, the whole pill is the expand trigger usually, or the left icon.
    // My _buildDraggablePill handles the toggle on the left icon.

    if (small) {
      return indicator;
    }

    return GestureDetector(
      onTap: () => _navigateToSession(context, manager),
      child: indicator,
    );
  }

  Widget _buildStatItem(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTheme.labelLarge
              .copyWith(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildControls(BuildContext context, DanceSessionManager manager) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.all(4),
          icon: Icon(
            manager.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            color: AppTheme.textPrimary,
          ),
          onPressed: () {
            if (manager.isPaused)
              manager.resumeSession();
            else
              manager.pauseSession();
          },
        ),
        const SizedBox(width: 4),
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
    if (manager.sessionType == SessionType.solo) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const SoloDanceScreen()));
    } else if (manager.eventId != null) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => LiveDanceScreen(eventId: manager.eventId!)));
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
              child: const Text('Cancel')),
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
