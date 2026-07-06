import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../services/event_service.dart';
import '../services/leaderboard_service.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/dance_session_manager.dart';
import '../models/leaderboard_model.dart';
import '../ui/app_theme.dart';
import '../ui/ranked_avatar.dart';
import 'live_dance_screen.dart';
import 'event_podium_screen.dart';
import '../services/notification_service.dart';
import 'package:share_plus/share_plus.dart';
import 'organizer_dashboard_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final Map<String, dynamic> event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late Map<String, dynamic> _event;
  Timer? _refreshTimer;
  bool _isHost = false;
  bool _showFriendsLB = false;
  List<LeaderboardEntry> _friendsEntries = [];
  bool _loadingFriends = false;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    final auth = Provider.of<AuthService>(context, listen: false);
    _isHost = _event['host_user_id'] == auth.userId;

    Future.microtask(() {
      if (mounted) {
        final lbService = Provider.of<LeaderboardService>(context, listen: false);
        lbService.startPolling(_event['_id']);
      }
    });

    // Event metadata (status, counts) changes rarely — 30s is enough and
    // keeps request volume low alongside the leaderboard polling.
    _refreshTimer = Timer.periodic(
        const Duration(seconds: 30), (timer) => _fetchEventDetails());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    final lbService = Provider.of<LeaderboardService>(context, listen: false);
    lbService.stopPolling();
    super.dispose();
  }

  Future<void> _fetchEventDetails() async {
    try {
      final service = Provider.of<EventService>(context, listen: false);
      final updated = await service.getEvent(_event['_id']);
      if (mounted) setState(() => _event = updated);
    } catch (e) {}
  }

  Future<void> _fetchFriendsLeaderboard() async {
    if (_loadingFriends) return;
    setState(() => _loadingFriends = true);
    try {
      final api = ApiService();
      final data = await api.get('/leaderboards/event/${_event['_id']}/friends');
      if (mounted) {
        setState(() {
          _friendsEntries = (data as List)
              .map((e) => LeaderboardEntry.fromJson(e))
              .toList();
          _loadingFriends = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingFriends = false);
    }
  }

  Future<void> _changeStatus(String newStatus) async {
    try {
      await Provider.of<EventService>(context, listen: false)
          .updateEventStatus(_event['_id'], newStatus);
      await _fetchEventDetails();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _joinAndStart() async {
    if (_event['status'] != 'active') {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('El evento todavía no está activo')));
      return;
    }

    // Geofencing Check for Public Events
    if (_event['visibility'] == 'public') {
      final bool isInRange = await _checkGeofence();
      if (!isInRange) return;
    }

    if (!mounted) return;
    final eventService = Provider.of<EventService>(context, listen: false);
    final manager = Provider.of<DanceSessionManager>(context, listen: false);

    // If a session is already running, either reopen it (same event)
    // or ask the user to finish it first (different event / solo).
    if (manager.isDancing) {
      if (manager.sessionType == SessionType.event &&
          manager.eventId == _event['_id']) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LiveDanceScreen(eventId: _event['_id']),
          ),
        );
      } else {
        _showError(
            "Ya tenés una sesión activa (${manager.eventName ?? 'Solo'}). Terminala antes de unirte a este evento.");
      }
      return;
    }

    try {
      await eventService.joinEvent(_event['_id']);
    } catch (e) {}

    final started = await manager.startSession(
      type: SessionType.event,
      eventId: _event['_id'],
      eventName: _event['name'],
    );

    if (!mounted) return;

    if (!started) {
      _showError(
          'No se pudo iniciar la sesión: el evento no está activo o no sos miembro.');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveDanceScreen(eventId: _event['_id']),
      ),
    );
  }

  Future<bool> _checkGeofence() async {
    try {
      // 1. Check Permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Permiso de ubicación denegado.');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError('Permiso de ubicación denegado. Activalo en los ajustes del sistema.');
        return false;
      }

      // 2. Get Location
      final Position position = await Geolocator.getCurrentPosition();
      
      // 3. Calculate Distance
      final eventLoc = _event['location'];
      if (eventLoc == null || eventLoc['coordinates'] == null) return true; // No location set, skip check
      
      final List<dynamic> coords = eventLoc['coordinates'];
      if (coords.length < 2) return true;

      // coordinates[0] is longitude, [1] is latitude in GeoJSON
      final double eventLon = coords[0].toDouble();
      final double eventLat = coords[1].toDouble();
      final double radius = (_event['geofence_radius'] ?? 500).toDouble();

      final double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        eventLat,
        eventLon,
      );

      if (distance > radius) {
        _showDistanceError(distance, radius);
        return false;
      }

      return true;
    } catch (e) {
      _showError('Error al verificar la ubicación: $e');
      return false;
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppTheme.error,
    ));
  }

  void _showDistanceError(double distance, double radius) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceLight,
        title: const Text('Fuera de rango', style: TextStyle(color: Colors.white)),
        content: Text(
          'Estás a ${distance.toStringAsFixed(0)}m del lugar. Tenés que estar a menos de ${radius.toStringAsFixed(0)}m para unirte.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK", style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
  }

  bool get _isPrivateEvent => _event['visibility'] == 'private';

  String? get _inviteCode {
    final code = _event['invite_code'];
    if (code == null || code.toString().isEmpty) return null;
    return code.toString();
  }

  void _shareEvent() {
    final name = _event['name'] ?? 'Challenge';
    final code = _inviteCode;
    Share.share(
      "¡Sumate al desafío '$name' en Looped! 🕺💃\n"
      "${code != null ? 'Usá el código $code para unirte.' : 'Buscalo en la app y unite.'}\n"
      "Descargá la app y empezá a moverte 🚀",
      subject: 'Sumate a este desafío de Looped',
    );
  }

  void _inviteFriends() {
    final name = _event['name'] ?? 'Challenge';
    final code = _inviteCode;
    Share.share(
      "¡Te invito al desafío '$name' en Looped! 🏆\n"
      "${code != null ? 'Ingresá el código $code en la app para sumarte.' : 'Buscalo en la app y sumate.'}",
      subject: 'Te invitaron a un desafío de Looped',
    );
  }

  void _copyInviteCode() {
    final code = _inviteCode;
    if (code == null) return;
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código copiado')),
    );
  }

  void _showInfoModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              "Detalles del evento",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow("Organizador", _event['organizer'] ?? 'Looped'),
                    _buildDetailRow("Género", _event['genre'] ?? 'Dance'),
                    _buildDetailRow("Estado", _event['status']?.toUpperCase() ?? 'WAITING'),
                    _buildDetailRow("Participantes", "${_event['participants_count'] ?? 0}"),
                    const SizedBox(height: 24),
                    const Text("Descripción",
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                    const SizedBox(height: 12),
                    Text(
                      _event['description'] ?? 'Sin descripción.',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 16, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lbService = Provider.of<LeaderboardService>(context);
    final data = lbService.currentData;
    final entries = data?.leaderboard ?? [];

    final status = _event['status'];
    final organizer = _event['organizer'] ?? 'Looped';
    final goalSteps = _event['goal_steps'] ?? 10000;
    final myPoints = data?.myPosition.points ?? 0;
    final progress = (myPoints / goalSteps).clamp(0.0, 1.0);

    final iconChar = _event['icon'] ?? '🎵';
    // '/uploads/...' (local) or 'https://...' (Cloudinary); anything else is an emoji
    final isImageUrl = iconChar.toString().startsWith('/') ||
        iconChar.toString().startsWith('http');
    final imageUrl = isImageUrl ? ApiService.mediaUrl(iconChar.toString()) : '';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: isImageUrl
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildPlaceholderBg(iconChar),
                  )
                : _buildPlaceholderBg(iconChar),
          ),
          // Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.7),
                    Colors.black,
                    Colors.black,
                  ],
                  stops: const [0.0, 0.4, 0.7, 1.0],
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildCircleIconButton(
                          Icons.arrow_back, () => Navigator.pop(context)),
                      _buildCircleIconButton(Icons.more_vert, () {}),
                    ],
                  ),
                ),
                // Main Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 100),
                        // Community Challenge / Private Event Tag
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isPrivateEvent) ...[
                                const Icon(Icons.lock,
                                    color: AppTheme.accent, size: 12),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                _isPrivateEvent
                                    ? 'EVENTO PRIVADO'
                                    : 'DESAFÍO COMUNITARIO',
                                style: const TextStyle(
                                  color: AppTheme.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Title
                        Text(
                          _event['name'] ?? 'Event Name',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Organizer
                        Text(
                          'Organizado por $organizer',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Info Badges Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildInfoBadge('GÉNERO', _event['genre'] ?? 'Dance',
                                Icons.fitness_center),
                            _buildInfoBadge(
                                'FECHA',
                                _formatDate(_event['starts_at']),
                                Icons.calendar_today),
                            _buildInfoBadge(
                                'LUGAR',
                                _event['venue_name'] ??
                                    _event['city'] ??
                                    'Global',
                                Icons.location_on),
                          ],
                        ),
                        const SizedBox(height: 32),
                        // Invite Code Card (private events: members share it)
                        if (_isPrivateEvent && _inviteCode != null) ...[
                          _buildInviteCodeCard(),
                          const SizedBox(height: 32),
                        ],
                        // Steps Goal Card
                        _buildGoalCard(goalSteps, myPoints, progress),
                        const SizedBox(height: 32),
                        if (_isHost) ...[
                          _buildAdminControls(status),
                          const SizedBox(height: 32),
                        ],
                        // Description Section
                        if (_event['description'] != null &&
                            _event['description']
                                .toString()
                                .trim()
                                .isNotEmpty) ...[
                          const Text('SOBRE EL EVENTO',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2)),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.05)),
                            ),
                            child: Text(
                              _event['description'],
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  height: 1.5),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                        // Quick Actions
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildQuickAction(Icons.person_add_alt_1, 'Invitar', onTap: _inviteFriends),
                              _buildQuickAction(
                                  Icons.notifications_none, 'Recordar',
                                  onTap: () async {
                                    if (_event['starts_at'] == null) return;
                                    final startTime = DateTime.parse(_event['starts_at']);
                                    if (startTime.isBefore(DateTime.now())) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('¡Este evento ya empezó!'))
                                      );
                                      return;
                                    }
                                    await NotificationService().scheduleNotification(
                                      id: _event['_id'].hashCode,
                                      title: '¡Tu evento está por empezar! 🕺',
                                      body: '¡${_event['name']} empieza ahora!',
                                      scheduledDate: startTime,
                                    );
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('¡Recordatorio creado!'))
                                      );
                                    }
                                  }),
                              _buildQuickAction(Icons.share_outlined, 'Compartir', onTap: _shareEvent),
                              _buildQuickAction(Icons.info_outline, 'Info', onTap: _showInfoModal),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        // Leaderboard Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Ranking',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold),
                            ),
                            _buildLeaderboardToggle(),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Leaderboard List
                        if (_showFriendsLB && _loadingFriends)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(color: AppTheme.accent),
                            ),
                          )
                        else
                          _buildLeaderboardList(_showFriendsLB ? _friendsEntries : entries),
                        const SizedBox(
                            height: 120), // Spacing for sticky button
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Sticky Bottom Button
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status == 'active')
                  CtaButton(
                    label: 'UNIRME AL EVENTO',
                    icon: Icons.bolt,
                    height: 60,
                    onPressed: _joinAndStart,
                  ),
                if (status == 'waiting' && _isHost)
                  CtaButton(
                    label: 'INICIAR EVENTO',
                    icon: Icons.play_arrow,
                    height: 60,
                    onPressed: () => _changeStatus('active'),
                  ),
                if (status == 'waiting' && !_isHost)
                  const Text('Esperando a que el organizador lo inicie...',
                      style: TextStyle(color: AppTheme.textSecondary)),
                if (status == 'ended')
                  CtaButton(
                    label: 'VER RESULTADOS',
                    icon: Icons.emoji_events,
                    height: 60,
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => EventPodiumScreen(
                          eventId: _event['_id'],
                          eventName: _event['name'] ?? 'Event',
                        ),
                      ));
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderBg(String iconChar) {
    return Container(
      color: AppTheme.surface,
      child: Center(
        child: Text(
          iconChar,
          style: const TextStyle(fontSize: 80),
        ),
      ),
    );
  }

  Widget _buildCircleIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildInfoBadge(String label, String value, IconData icon) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight.withOpacity(0.5),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.accent, size: 20),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInviteCodeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.accent.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.vpn_key_outlined, color: AppTheme.accent, size: 16),
              SizedBox(width: 8),
              Text('CÓDIGO DE INVITACIÓN',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _inviteCode!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                  ),
                ),
              ),
              _buildCircleIconButton(Icons.copy, _copyInviteCode),
              const SizedBox(width: 8),
              _buildCircleIconButton(Icons.share, _inviteFriends),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Compartilo con tus amigos para que se unan al evento',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(int goal, int current, double progress) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Objetivo de pasos',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('La meta de este desafío',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatNumber(goal),
                    style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),
                  const Text('PASOS',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: AppTheme.surfaceMuted,
              valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('PROGRESO',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
              Text(
                '${_formatNumber(current)} / ${_formatNumber(goal)}',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, {VoidCallback? onTap, Color color = Colors.white70}) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminControls(String status) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.admin_panel_settings, color: AppTheme.accent, size: 20),
              SizedBox(width: 8),
              Text('PANEL DEL ORGANIZADOR',
                  style: TextStyle(
                      color: AppTheme.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Sos el organizador de este evento. Accedé al panel en vivo para ver bailarines activos, el estado anti-trampas y administrar el evento.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          CtaButton(
            label: 'ABRIR PANEL EN VIVO',
            icon: Icons.dashboard_outlined,
            height: 50,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OrganizerDashboardScreen(eventId: _event['_id']),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => _showFriendsLB = false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                  color: !_showFriendsLB ? AppTheme.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(10)),
              child: Text('Top 10',
                  style: TextStyle(
                      color: !_showFriendsLB ? Colors.black : AppTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              setState(() => _showFriendsLB = true);
              _fetchFriendsLeaderboard();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                  color: _showFriendsLB ? AppTheme.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(10)),
              child: Text('Amigos',
                  style: TextStyle(
                      color: _showFriendsLB ? Colors.black : AppTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList(List<LeaderboardEntry> entries) {
    if (entries.isEmpty) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text('Todavía no hay participantes',
                  style: TextStyle(color: AppTheme.textSecondary))));
    }

    return Column(
      children: entries.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: index == 0 ? AppTheme.accent : AppTheme.textSecondary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              RankedAvatar(
                avatarUrl: item.avatarUrl,
                rank: item.rank,
                size: 42,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.username,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatNumber(item.points)} pasos',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (index == 0)
                const Icon(Icons.emoji_events,
                    color: AppTheme.accent, size: 24),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'TBD';
    final date = DateTime.tryParse(dateStr)?.toLocal();
    if (date == null) return 'TBD';
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}
