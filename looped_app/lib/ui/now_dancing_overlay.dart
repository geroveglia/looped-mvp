import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/dance_session_manager.dart';
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
  Offset? _position;

  @override
  Widget build(BuildContext context) {
    if (_position == null && MediaQuery.of(context).size.width > 0) {
      final size = MediaQuery.of(context).size;
      _position = Offset(20, size.height - 120);
    }

    return Consumer<DanceSessionManager>(
      builder: (context, manager, _) {
        if (!manager.isDancing || manager.isOnDanceScreen) return widget.child;

        return Stack(
          children: [
            widget.child,
            // Check if we are on a dance screen to hide the pill
            Builder(
              builder: (ctx) {
                // Determine if the current top-most route is a dance screen
                // Note: ModalRoute.of(ctx) might return the route of the overlay itself
                // if it's not careful. But usually it works.
                // However, an easier way is to check the manager's state if we add a 'isOnDanceScreen' flag.
                // For now, let's use a simple FocusScope or Navigator check if possible.
                // Or just assume the user wants it hidden when they are "actively" looking at the stats.
                
                return _buildDraggablePill(context, manager);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDraggablePill(BuildContext context, DanceSessionManager manager) {
    return Positioned(
      left: _position?.dx ?? 20,
      top: _position?.dy ?? 100,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position = (_position ?? Offset.zero) + details.delta;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPulseDot(),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: AppTheme.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    manager.formattedTime,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Container(width: 1, height: 30, color: Colors.white.withOpacity(0.1)),
              const SizedBox(width: 12),
              const Icon(Icons.bolt, color: AppTheme.accent, size: 20),
              const SizedBox(width: 4),
              Text(
                '${manager.points}',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              Container(width: 1, height: 30, color: Colors.white.withOpacity(0.1)),
              const SizedBox(width: 12),
              _buildCircularButton(
                icon: manager.isPaused ? Icons.play_arrow : Icons.pause,
                onPressed: () {
                  if (manager.isPaused) {
                    manager.resumeSession();
                  } else {
                    manager.pauseSession();
                  }
                },
                color: const Color(0xFF1A1A1A),
              ),
              const SizedBox(width: 8),
              _buildCircularButton(
                icon: Icons.stop,
                onPressed: () => _confirmStop(context, manager),
                color: const Color(0xFF1A3D2B),
                iconColor: AppTheme.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPulseDot() {
    return Container(
      width: 12,
      height: 12,
      decoration: const BoxDecoration(
        color: AppTheme.accent,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: AppTheme.accent, blurRadius: 8, spreadRadius: 1)],
      ),
    );
  }

  Widget _buildCircularButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    Color iconColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 20),
      ),
    );
  }

  Future<void> _confirmStop(BuildContext context, DanceSessionManager manager) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('End Session?', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to stop dancing?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4433),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
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
