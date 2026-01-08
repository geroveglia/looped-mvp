import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/dance_session_manager.dart';
import '../screens/live_dance_screen.dart';

/// Global floating overlay shown when user is actively dancing.
/// Displays event info, points, timer, and control buttons.
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
      bottom: 80, // Above bottom nav
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(_isMinimized ? 8 : 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Colors.greenAccent.withOpacity(0.5), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.greenAccent.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 2,
              )
            ],
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
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.music_note, color: Colors.greenAccent, size: 20),
          const SizedBox(width: 8),
          Text(
            manager.formattedTime,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontFamily: 'Monospace',
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${manager.points} pts',
            style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
          ),
          const Spacer(),
          const Icon(Icons.expand_less, color: Colors.grey, size: 20),
        ],
      ),
    );
  }

  Widget _buildExpanded(BuildContext context, DanceSessionManager manager) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with minimize button
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8, color: Colors.greenAccent),
                  SizedBox(width: 4),
                  Text(
                    'DANCING',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _isMinimized = true),
              child: const Icon(Icons.expand_more, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Event Name
        Text(
          manager.eventName ?? 'Event',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),

        // Stats Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStat('TIME', manager.formattedTime),
            Container(width: 1, height: 30, color: Colors.white24),
            _buildStat('POINTS', '${manager.points}'),
          ],
        ),
        const SizedBox(height: 12),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.arrow_back,
                label: 'Volver',
                color: Colors.blueAccent,
                onTap: () => _navigateToLiveDance(context, manager),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                icon: Icons.stop,
                label: 'Stop',
                color: Colors.orangeAccent,
                onTap: () => _stopSession(context, manager),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                icon: Icons.exit_to_app,
                label: 'Salir',
                color: Colors.redAccent,
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
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFamily: 'Monospace',
          ),
        ),
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToLiveDance(BuildContext context, DanceSessionManager manager) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveDanceScreen(eventId: manager.eventId!),
      ),
    );
  }

  Future<void> _stopSession(
      BuildContext context, DanceSessionManager manager) async {
    try {
      await manager.stopSession();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesión guardada ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _showLeaveConfirmation(
      BuildContext context, DanceSessionManager manager) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('¿Abandonar evento?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Se detendrá tu sesión actual y saldrás del evento.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Abandonar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await manager.leaveEvent();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Has abandonado el evento')),
          );
          // Navigate to home
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}
