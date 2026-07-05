import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../ui/app_theme.dart';

class OrganizerDashboardScreen extends StatefulWidget {
  final String eventId;

  const OrganizerDashboardScreen({super.key, required this.eventId});

  @override
  State<OrganizerDashboardScreen> createState() => _OrganizerDashboardScreenState();
}

class _OrganizerDashboardScreenState extends State<OrganizerDashboardScreen> {
  final ApiService _api = ApiService();
  Timer? _pollingTimer;
  Map<String, dynamic>? _analytics;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
    // Poll analytics every 10 seconds — host-only screen, stays well under
    // the server rate limit during long events
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchAnalytics(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAnalytics({bool silent = false}) async {
    try {
      final data = await _api.get('/events/${widget.eventId}/analytics');
      if (mounted) {
        setState(() {
          _analytics = data;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateEventStatus(String nextStatus) async {
    setState(() => _isLoading = true);
    try {
      await _api.patch('/events/${widget.eventId}/status', {'status': nextStatus});
      await _fetchAnalytics();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Estado del evento: ${nextStatus.toUpperCase()}')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _analytics == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }

    if (_error != null && _analytics == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppTheme.error, size: 64),
                const SizedBox(height: 16),
                Text('Error: $_error', style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => _fetchAnalytics(),
                  child: const Text('Reintentar'),
                )
              ],
            ),
          ),
        ),
      );
    }

    final data = _analytics!;
    final status = data['status'] ?? 'waiting';
    final activeCount = data['active_dancers'] ?? 0;
    final totalDancers = data['total_dancers'] ?? 0;
    final totalPoints = data['total_points'] ?? 0;
    final avgIntensity = data['avg_intensity'] ?? 0.0;
    final suspiciousCount = data['suspicious_count'] ?? 0;
    
    final activeList = (data['active_list'] as List?) ?? [];
    final flaggedList = (data['flagged'] as List?) ?? [];

    Color statusColor = Colors.orangeAccent;
    if (status == 'active') statusColor = AppTheme.success;
    if (status == 'ended') statusColor = AppTheme.error;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (data['name'] ?? 'PANEL DEL EVENTO').toString().toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Text(
              'LIVE DJ / ORGANIZER DASHBOARD',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () => _fetchAnalytics(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // -------------------------------------------------------------
              // STATUS & CONTROLS CARD
              // -------------------------------------------------------------
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('CONTROL DEL EVENTO', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              if (status == 'active') ...[
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                status.toUpperCase(),
                                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        if (status == 'waiting')
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: () => _updateEventStatus('active'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.success.withOpacity(0.15),
                                  foregroundColor: AppTheme.success,
                                  side: BorderSide(color: AppTheme.success.withOpacity(0.3), width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                                ),
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('INICIAR EVENTO', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          )
                        else if (status == 'active')
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: () => _updateEventStatus('ended'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.error.withOpacity(0.15),
                                  foregroundColor: AppTheme.error,
                                  side: BorderSide(color: AppTheme.error.withOpacity(0.3), width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                                ),
                                icon: const Icon(Icons.stop_rounded),
                                label: const Text('FINALIZAR EVENTO', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          )
                        else
                          const Expanded(
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.all(12.0),
                                child: Text('Este evento finalizó y ya no se puede controlar.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontStyle: FontStyle.italic)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // -------------------------------------------------------------
              // KEY STATS GRID
              // -------------------------------------------------------------
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'BAILARINES ACTIVOS',
                      '$activeCount / $totalDancers',
                      Icons.directions_run,
                      activeCount > 0 ? AppTheme.accent : AppTheme.textSecondary,
                      subtext: 'Bailando / Anotados',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      'PUNTOS TOTALES',
                      totalPoints.toString(),
                      Icons.bolt,
                      Colors.amber,
                      subtext: 'Pasos acumulados del evento',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'INTENSIDAD PROM.',
                      'Nivel $avgIntensity',
                      Icons.equalizer,
                      AppTheme.success,
                      subtext: 'Dinámica de baile activa',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      'ANTI-CHEAT ALERTS',
                      suspiciousCount.toString(),
                      Icons.warning_amber_rounded,
                      suspiciousCount > 0 ? AppTheme.error : AppTheme.textSecondary,
                      subtext: 'Sesiones marcadas',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // -------------------------------------------------------------
              // ACTIVE DANCERS LIST
              // -------------------------------------------------------------
              const Text(
                'BAILANDO AHORA',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              const SizedBox(height: 12),
              if (activeList.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Text('Nadie está bailando en este momento.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontStyle: FontStyle.italic)),
                  ),
                )
              else
                ...activeList.map((dancer) {
                  final username = dancer['username'] ?? 'Bailarín';
                  final points = dancer['points'] ?? 0;
                  final intensity = dancer['intensity'] ?? 0.0;
                  final level = dancer['level'] ?? 1;
                  final avatar = dancer['avatar_url'];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.03)),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.surfaceMuted,
                        backgroundImage: avatar != null && avatar.toString().isNotEmpty ? NetworkImage(ApiService.mediaUrl(avatar)) : null,
                      ),
                      title: Text(username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Row(
                        children: [
                          Text('Nv $level', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                          const SizedBox(width: 8),
                          Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.white30, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text('Intensidad: Nv ${intensity.toStringAsFixed(1)}', style: const TextStyle(color: AppTheme.success, fontSize: 11)),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text('$points pts', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  );
                }).toList(),

              const SizedBox(height: 32),

              // -------------------------------------------------------------
              // FLAGGED / SUSPICIOUS LIST
              // -------------------------------------------------------------
              Row(
                children: [
                  const Icon(Icons.warning, color: AppTheme.error, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'ALERTAS DE MOVIMIENTO SOSPECHOSO',
                    style: TextStyle(color: AppTheme.error, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (flaggedList.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Text('No se detectaron trampas ni movimiento mecánico.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ),
                )
              else
                ...flaggedList.map((flag) {
                  final username = flag['username'] ?? 'User';
                  final points = flag['points'] ?? 0;
                  final score = flag['suspicion_score'] ?? 0;
                  final ended = flag['ended'] ?? false;
                  final avatar = flag['avatar_url'];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.error.withOpacity(0.15)),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.surfaceMuted,
                        backgroundImage: avatar != null && avatar.toString().isNotEmpty ? NetworkImage(ApiService.mediaUrl(avatar)) : null,
                      ),
                      title: Text(username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        'Nivel de sospecha: $score/100 · ${ended ? "Finalizada" : "En vivo"}',
                        style: const TextStyle(color: AppTheme.error, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$points pts', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color, {required String subtext}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: const TextStyle(color: Colors.white30, fontSize: 9),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
