import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/solo_session.dart';
import '../services/solo_session_manager.dart';
import '../ui/app_theme.dart';

class SoloHistoryScreen extends StatefulWidget {
  const SoloHistoryScreen({super.key});

  @override
  State<SoloHistoryScreen> createState() => _SoloHistoryScreenState();
}

class _SoloHistoryScreenState extends State<SoloHistoryScreen> {
  late Future<List<SoloSession>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture =
        Provider.of<SoloSessionManager>(context, listen: false).getHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Solo Sessions'),
        backgroundColor: AppTheme.background,
      ),
      body: FutureBuilder<List<SoloSession>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.accent));
          }

          if (snapshot.hasError) {
            return Center(
                child: Text('Error: ${snapshot.error}',
                    style: AppTheme.bodyMedium));
          }

          final history = snapshot.data ?? [];
          if (history.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 64, color: AppTheme.textTertiary),
                  const SizedBox(height: AppTheme.spacingMd),
                  Text('No solo sessions yet', style: AppTheme.bodyMedium),
                  const SizedBox(height: AppTheme.spacingSm),
                  Text('Start dancing and build your history!',
                      style: AppTheme.bodySmall),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _historyFuture =
                    Provider.of<SoloSessionManager>(context, listen: false)
                        .getHistory();
              });
            },
            color: AppTheme.accent,
            child: ListView.builder(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final session = history[index];
                return _buildSessionCard(session);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSessionCard(SoloSession session) {
    final dateStr = DateFormat('MMM d, yyyy • HH:mm').format(session.startedAt);
    final duration = session.durationSeconds ?? 0;
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    final durationStr = '${minutes}m ${seconds}s';

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      decoration: AppTheme.cardDecoration,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingSm),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.flash_on, color: AppTheme.accent),
        ),
        title: Text(dateStr, style: AppTheme.titleSmall),
        subtitle: Row(
          children: [
            const Icon(Icons.timer_outlined,
                size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(durationStr, style: AppTheme.bodySmall),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '+${session.points}',
              style: AppTheme.titleMedium.copyWith(color: AppTheme.accent),
            ),
            const Text('pts', style: AppTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
