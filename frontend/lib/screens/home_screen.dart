import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/event_service.dart';
import '../services/api_service.dart';
import '../services/dance_session_manager.dart';
import '../services/notification_service.dart';
import '../ui/app_theme.dart';
import 'event_detail_screen.dart';
import 'profile_screen.dart';
import 'solo_dance_screen.dart';
import 'social_screen.dart';
import 'create_event_screen.dart';
import 'solo_history_screen.dart';
import '../services/rank_service.dart';
import '../models/rank_model.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String? _selectedGenre;
  DateTime? _selectedDate;
  String? _selectedLocation;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  UserRank? _rankData;
  final TextEditingController _myEventsSearchController = TextEditingController();
  String? _myEventsGenre;

  final List<String> _genres = [
    'Techno',
    'House',
    'Fitness',
    'Pop',
    'Reggaeton',
    'HipHop',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final eventService = Provider.of<EventService>(context, listen: false);
      eventService.fetchEvents();
      eventService.fetchMyEvents();
      _loadRankData();
    });
  }

  Future<void> _loadRankData() async {
    try {
      final rankService = RankService();
      final rank = await rankService.fetchMyRank();
      if (mounted) {
        setState(() {
          _rankData = rank;
        });
      }
    } catch (e) {
      // Handle error quietly
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _myEventsSearchController.dispose();
    super.dispose();
  }

  void _showJoinByCodeDialog() {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: const Text('Unirse a evento privado', style: AppTheme.titleMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ingresá el código que te compartió el organizador', style: AppTheme.bodyMedium),
            const SizedBox(height: AppTheme.spacingMd),
            TextField(
              controller: codeController,
              textCapitalization: TextCapitalization.characters,
              style: AppTheme.titleLarge.copyWith(letterSpacing: 4),
              textAlign: TextAlign.center,
              maxLength: 6,
              decoration: InputDecoration(
                hintText: 'ABC123',
                hintStyle: AppTheme.bodyMedium,
                filled: true,
                fillColor: AppTheme.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.isEmpty) return;
              Navigator.of(ctx).pop();
              try {
                final eventService = Provider.of<EventService>(context, listen: false);
                final result = await eventService.joinByCode(code);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Te uniste al evento!')));
                  if (result['event'] != null) {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventDetailScreen(event: result['event'])));
                  }
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('UNIRME'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeFeed();
      case 1:
        return _buildMyEventsPage();
      case 2:
        return const SoloDanceScreen();
      case 3:
        return const SocialScreen();
      case 4:
        return const ProfileScreen();
      default:
        return _buildHomeFeed();
    }
  }
  Widget _buildHomeFeed() {
    final eventService = Provider.of<EventService>(context);
    final events = eventService.events.cast<Map<String, dynamic>>();
    
    // Sort all events by date first
    final sortedEvents = List<Map<String, dynamic>>.from(events);
    sortedEvents.sort((a, b) {
      final aDate = a['starts_at'] != null ? DateTime.parse(a['starts_at']) : DateTime.now();
      final bDate = b['starts_at'] != null ? DateTime.parse(b['starts_at']) : DateTime.now();
      return aDate.compareTo(bDate);
    });

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final query = _searchController.text.toLowerCase();
    final filtered = sortedEvents.where((e) {
      final isPublic = e['visibility'] != 'private';
      if (!isPublic) return false;

      final matchesGenre = _selectedGenre == null || 
          e['genre']?.toString().toLowerCase() == _selectedGenre!.toLowerCase();
          
      // Match Location Date
      late bool matchesDate;
      if (_selectedDate == null) {
        matchesDate = true;
      } else {
        if (e['starts_at'] == null) {
          matchesDate = false;
        } else {
          // Local date: an 11pm party parsed in UTC would match the wrong day
          final eDate = DateTime.parse(e['starts_at']).toLocal();
          matchesDate = eDate.year == _selectedDate!.year &&
                        eDate.month == _selectedDate!.month &&
                        eDate.day == _selectedDate!.day;
        }
      }
      
      // Match Location
      late bool matchesLocation;
      if (_selectedLocation == null) {
        matchesLocation = true;
      } else {
        matchesLocation = (e['city'] ?? '').toString().toLowerCase() == _selectedLocation!.toLowerCase();
      }

      final matchesSearch = query.isEmpty || 
          (e['name'] ?? '').toString().toLowerCase().contains(query) ||
          (e['venue_name'] ?? '').toString().toLowerCase().contains(query) ||
          (e['organizer'] ?? '').toString().toLowerCase().contains(query);
          
      return matchesGenre && matchesDate && matchesLocation && matchesSearch;
    }).toList();

    // Categorize
    // 1. Trending: Top 3 by participants_count
    final trendingList = List<Map<String, dynamic>>.from(filtered);
    trendingList.sort((a, b) => (b['participants_count'] ?? 0).compareTo(a['participants_count'] ?? 0));
    final trending = trendingList.take(3).toList();
    final trendingIds = trending.map((e) => e['_id']).toSet();

    // 2. Group by Date (Remaining)
    final Map<String, List<Map<String, dynamic>>> groupedByDate = {};
    for (var e in filtered) {
      if (trendingIds.contains(e['_id'])) continue;
      
      String dateKey;
      if (e['starts_at'] == null) {
        dateKey = 'HOY';
      } else {
        // Group by LOCAL calendar day, not UTC (evening events shift a day otherwise)
        final start = DateTime.parse(e['starts_at']).toLocal();
        final startDate = DateTime(start.year, start.month, start.day);
        if (startDate.isAtSameMomentAs(today)) {
          dateKey = 'HOY';
        } else if (startDate.isAtSameMomentAs(today.add(const Duration(days: 1)))) {
          dateKey = 'MAÑANA';
        } else {
          // Format as "MARCH 15" etc.
          final months = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'];
          dateKey = '${months[startDate.month - 1]} ${startDate.day}';
        }
      }
      groupedByDate.putIfAbsent(dateKey, () => []).add(e);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          Provider.of<EventService>(context, listen: false).fetchEvents(),
          _loadRankData(),
        ]);
      },
      color: AppTheme.accent,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(_isSearching ? Icons.close : Icons.search,
                      color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _isSearching = !_isSearching;
                      if (!_isSearching) _searchController.clear();
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined,
                      color: Colors.white),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined,
                      color: Colors.white),
                  onPressed: () => _showNotificationsSheet(context),
                ),
              ],
            ),
            if (_isSearching) _buildSearchBar(),
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickAction(
                    icon: Icons.add_circle_outline,
                    label: 'Crear evento',
                    color: AppTheme.accent,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CreateEventScreen()),
                    ),
                  ),
                  _buildQuickAction(
                    icon: Icons.qr_code,
                    label: 'Código de invitación',
                    onTap: _showJoinByCodeDialog,
                  ),
                  _buildQuickAction(
                    icon: Icons.history,
                    label: 'Historial',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SoloHistoryScreen()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildDailyActivityCard(),
            const SizedBox(height: 16),
            _buildCategorySelector(),
            const SizedBox(height: 24),
            
            if (trending.isNotEmpty) ...[
              _buildSectionHeader(
                'En tendencia',
                showViewAll: true,
                onViewAll: () {
                  setState(() {
                    _selectedGenre = null;
                    _selectedDate = null;
                    _selectedLocation = null;
                    _searchController.clear();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Filtros limpiados: mostrando todos los eventos'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              ...trending.map((e) => _buildEventCard(e, isLive: e['starts_at'] != null && DateTime.parse(e['starts_at']).isBefore(now) && (e['ends_at'] == null || DateTime.parse(e['ends_at']).isAfter(now)))),
              const SizedBox(height: 16),
            ],

            ...groupedByDate.entries.map((entry) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(entry.key),
                const SizedBox(height: 16),
                ...entry.value.map((e) => _buildEventCard(e, isFuture: entry.key != 'HOY')),
                const SizedBox(height: 16),
              ],
            )),
            
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white70,
  }) {
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

  Future<void> _showNotificationsSheet(BuildContext context) async {
    final notifService = NotificationService();
    final pending = await notifService.getPendingNotifications();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Recordatorios programados',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (pending.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.notifications_off_outlined, color: AppTheme.textSecondary, size: 48),
                        SizedBox(height: 12),
                        Text('Sin recordatorios programados',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                        SizedBox(height: 4),
                        Text('Tocá "Recordar" en un evento para crear uno',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: pending.length,
                    separatorBuilder: (_, __) => const Divider(color: AppTheme.surfaceMuted, height: 1),
                    itemBuilder: (ctx, i) {
                      final n = pending[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.event, color: AppTheme.accent, size: 20),
                        ),
                        title: Text(n.title ?? 'Recordatorio',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(n.body ?? '',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 18),
                          onPressed: () async {
                            await notifService.cancelNotification(n.id);
                            if (ctx.mounted) Navigator.pop(ctx);
                            // Re-open to refresh list
                            if (context.mounted) _showNotificationsSheet(context);
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, {bool showViewAll = false, VoidCallback? onViewAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        if (showViewAll)
          TextButton(
            onPressed: onViewAll ?? () {},
            child: const Text('Ver todos', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Buscar eventos...',
          hintStyle: const TextStyle(color: AppTheme.textSecondary),
          prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
          filled: true,
          fillColor: AppTheme.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppTheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (ctx) {
            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24).copyWith(
                      bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Filtros', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 24),
                        
                        // Genre
                        const Text('Género', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: List.generate(_genres.length + 1, (index) {
                            final isAll = index == 0;
                            final genre = isAll ? 'Todos' : _genres[index - 1];
                            final isSelected = isAll ? _selectedGenre == null : _selectedGenre == genre;
                            
                            return GestureDetector(
                              onTap: () {
                                setModalState(() => _selectedGenre = isAll ? null : genre);
                                setState(() => _selectedGenre = isAll ? null : genre);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.accent : AppTheme.surfaceLight,
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  genre,
                                  style: TextStyle(
                                    color: isSelected ? Colors.black : Colors.white70,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 24),

                        // Date
                        const Text('Fecha', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: _selectedDate ?? DateTime.now(),
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setModalState(() => _selectedDate = picked);
                              setState(() => _selectedDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedDate != null ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}' : 'Cualquier fecha',
                                  style: TextStyle(color: _selectedDate != null ? Colors.white : AppTheme.textSecondary, fontSize: 16),
                                ),
                                if (_selectedDate != null)
                                  GestureDetector(
                                    onTap: () {
                                      setModalState(() => _selectedDate = null);
                                      setState(() => _selectedDate = null);
                                    },
                                    child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                                  )
                                else
                                  const Icon(Icons.calendar_today, color: AppTheme.textSecondary, size: 20),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Location
                        const Text('Ubicación (ciudad)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                        const SizedBox(height: 12),
                        TextField(
                          onChanged: (val) {
                            final formatted = val.trim().isEmpty ? null : val.trim();
                            setModalState(() => _selectedLocation = formatted);
                            setState(() => _selectedLocation = formatted);
                          },
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Cualquier ciudad (ej: Buenos Aires)',
                            hintStyle: const TextStyle(color: AppTheme.textSecondary),
                            filled: true,
                            fillColor: AppTheme.surfaceLight,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            suffixIcon: _selectedLocation != null 
                              ? IconButton(
                                  icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                                  onPressed: () {
                                    // Hack to clear textField visually via state would require a controller,
                                    // but we can at least clear the filter value.
                                    setModalState(() => _selectedLocation = null);
                                    setState(() => _selectedLocation = null);
                                  },
                                )
                              : const Icon(Icons.location_on, color: AppTheme.textSecondary, size: 20),
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          ),
                          child: const Text('Aplicar filtros', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ],
                    ),
                  ),
                );
              }
            );
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: (_selectedGenre != null || _selectedDate != null || _selectedLocation != null) ? AppTheme.accent : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list, color: (_selectedGenre != null || _selectedDate != null || _selectedLocation != null) ? Colors.black : AppTheme.accent, size: 18),
            const SizedBox(width: 8),
            Text(
              (_selectedGenre != null || _selectedDate != null || _selectedLocation != null) ? 'Filtros activos' : 'Filtros',
              style: TextStyle(
                color: (_selectedGenre != null || _selectedDate != null || _selectedLocation != null) ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, color: (_selectedGenre != null || _selectedDate != null || _selectedLocation != null) ? Colors.black54 : AppTheme.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyActivityCard() {
    // Rank data
    final monthlyPoints = _rankData?.monthlyPoints ?? 0;
    final rankProgress = _rankData?.nextRankProgress ?? 0.0;
    final rankPercentage = (rankProgress * 100).toInt();
    final nextRankName = _rankData?.nextRankName;
    final pointsToNext = _rankData?.pointsToNextRank;
    final rankColor = _rankData != null ? _rankData!.rankColor : AppTheme.accent;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // MONTHLY / RANK SECTION
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('PROGRESO MENSUAL', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              Text('$rankPercentage%', style: TextStyle(color: rankColor.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                monthlyPoints.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},'),
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 6),
              const Text('pts este mes', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const Spacer(),
              Text(_rankData?.rankEmoji ?? '👻', style: const TextStyle(fontSize: 20)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rankProgress,
              backgroundColor: AppTheme.surfaceMuted,
              valueColor: AlwaysStoppedAnimation(rankColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 16),
          if (nextRankName != null && pointsToNext != null)
            Text(
              '¡Casi llegás a $nextRankName! Faltan ${pointsToNext.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} pts.',
              style: TextStyle(color: rankColor, fontSize: 12, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic),
            )
          else if (_rankData?.rank == 'immortal')
            const Text(
              '⚡ El Inmortal: Sos parte de la leyenda.',
              style: TextStyle(color: Color(0xFFFF00FF), fontSize: 12, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
            )
          else
            const Text(
              '¡Sigue así para subir de rango!',
              style: TextStyle(color: AppTheme.accent, fontSize: 12, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event, {bool isLive = false, bool isFuture = false}) {
    final iconChar = event['icon'] ?? '🎵';
    // '/uploads/...' (local) or 'https://...' (Cloudinary); anything else is an emoji
    final isImageUrl = iconChar.toString().startsWith('/') ||
        iconChar.toString().startsWith('http');
    final imageUrl = isImageUrl ? ApiService.mediaUrl(iconChar.toString()) : '';
    
    String countdownStr = '—';
    if (event['starts_at'] != null) {
      final start = DateTime.parse(event['starts_at']);
      final now = DateTime.now();
      if (start.isAfter(now)) {
        final diff = start.difference(now);
        if (diff.inHours > 0) {
          countdownStr = '${diff.inHours}h ${diff.inMinutes % 60}m';
        } else {
          countdownStr = '${diff.inMinutes}m';
        }
      } else {
        countdownStr = 'EN CURSO';
      }
    }

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventDetailScreen(event: event))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image part
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: SizedBox(
                height: 160,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (isImageUrl) 
                      Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: AppTheme.surfaceLight, child: Center(child: Text(iconChar, style: const TextStyle(fontSize: 48)))))
                    else
                      Container(color: AppTheme.surfaceLight, child: Center(child: Text(iconChar, style: const TextStyle(fontSize: 48)))),
                    
                    // Badges
                    Positioned(
                      top: 12,
                      left: 12,
                      child: isLive 
                          ? _buildBadge('EN VIVO', AppTheme.error)
                          : (isFuture ? _buildBadge('PRÓXIMO', AppTheme.accent.withOpacity(0.15), textColor: AppTheme.accent) : const SizedBox.shrink()),
                    ),
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          isLive 
                            ? '${event['active_dancers_count'] ?? 0} bailando' 
                            : '${event['participants_count'] ?? 0} anotados', 
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Text part
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event['name'] ?? 'Event Name', 
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(isLive ? Icons.location_on : Icons.videocam, color: AppTheme.textSecondary, size: 14),
                            const SizedBox(width: 4),
                            Expanded(child: Text(event['venue_name'] ?? 'Sesión virtual', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12), maxLines: 1)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (isLive) ...[
                              if (event['active_dancers_avatars'] != null && (event['active_dancers_avatars'] as List).isNotEmpty) ...[
                                ...((event['active_dancers_avatars'] as List).asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final avatarUrl = entry.value as String?;
                                  final hasImage = avatarUrl != null && avatarUrl.isNotEmpty;
                                  
                                  Widget avatarWidget = Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: AppTheme.surface,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.black, width: 1.5),
                                    ),
                                    child: hasImage
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.network(
                                              avatarUrl.startsWith('http') 
                                                  ? avatarUrl 
                                                  : '${ApiService.baseUrl}$avatarUrl',
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 12, color: Colors.white60),
                                            ),
                                          )
                                        : const Icon(Icons.person, size: 12, color: Colors.white60),
                                  );

                                  if (idx > 0) {
                                    return Transform.translate(
                                      offset: Offset(-8.0 * idx, 0),
                                      child: avatarWidget,
                                    );
                                  }
                                  return avatarWidget;
                                }).toList()),
                                if ((event['active_dancers_count'] ?? 0) > (event['active_dancers_avatars'] as List).length)
                                  Transform.translate(
                                    offset: Offset(-8.0 * (event['active_dancers_avatars'] as List).length, 0),
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceMuted,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.black, width: 1.5),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '+${(event['active_dancers_count'] ?? 0) - (event['active_dancers_avatars'] as List).length}',
                                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ),
                              ] else ...[
                                Container(width: 24, height: 24, decoration: const BoxDecoration(color: AppTheme.textSecondary, shape: BoxShape.circle)),
                                Transform.translate(offset: const Offset(-8, 0), child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: Colors.white54, shape: BoxShape.circle))),
                                Transform.translate(offset: const Offset(-16, 0), child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: AppTheme.surfaceMuted, shape: BoxShape.circle), child: const Center(child: Text('+12', style: TextStyle(color: Colors.white, fontSize: 8))))),
                              ]
                            ] else ...[
                              const Text('Tocá para unirte', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontStyle: FontStyle.italic)),
                            ]
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (isLive) ...[
                        const Text('TU PUESTO', style: TextStyle(color: AppTheme.accent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 4),
                        Text('#${event['user_stats'] != null && event['user_stats']['rank'] != null ? event['user_stats']['rank'] : '--'}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ] else ...[
                        const Text('EMPIEZA EN', style: TextStyle(color: AppTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 4),
                        Text(countdownStr, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                      const SizedBox(height: 12),
                      isLive ? 
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventDetailScreen(event: event))),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                            minimumSize: const Size(0, 32),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Unirme', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ) :
                        OutlinedButton(
                          onPressed: () async {
                            if (event['starts_at'] == null) return;
                            final startTime = DateTime.parse(event['starts_at']);
                            await NotificationService().scheduleNotification(
                              id: event['_id'].hashCode,
                              title: '¡Tu evento está por empezar! 🕺',
                              body: '${event['name']} empieza ahora en ${event['venue_name'] ?? 'Looped'}',
                              scheduledDate: startTime,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('¡Recordatorio creado!'))
                              );
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.accent,
                            side: const BorderSide(color: AppTheme.accent),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                            minimumSize: const Size(0, 32),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Recordar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color bgColor, {Color textColor = Colors.white}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (text == 'EN VIVO') ...[
            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
            const SizedBox(width: 4),
          ],
          Text(text, style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMyEventsPage() {
    final eventService = Provider.of<EventService>(context);
    final myEvents = eventService.myEvents.cast<Map<String, dynamic>>();

    final query = _myEventsSearchController.text.toLowerCase();
    final filtered = myEvents.where((e) {
      final matchesGenre = _myEventsGenre == null ||
          e['genre']?.toString().toLowerCase() == _myEventsGenre!.toLowerCase();
      final matchesSearch = query.isEmpty ||
          (e['name'] ?? '').toString().toLowerCase().contains(query) ||
          (e['venue_name'] ?? '').toString().toLowerCase().contains(query) ||
          (e['organizer'] ?? '').toString().toLowerCase().contains(query);
      return matchesGenre && matchesSearch;
    }).toList();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _myEventsSearchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Buscar en mis eventos...',
                      hintStyle: const TextStyle(color: AppTheme.textSecondary),
                      prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.surface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                _buildMyEventsFilterButton(),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      myEvents.isEmpty ? 'Todavía no te uniste a ningún evento' : 'Sin resultados para tu búsqueda',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => _buildEventCard(filtered[i], isFuture: true),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyEventsFilterButton() {
    final hasFilter = _myEventsGenre != null;
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppTheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (ctx) {
            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24).copyWith(
                      bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Filtros', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 24),
                        const Text('Género', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: List.generate(_genres.length + 1, (index) {
                            final isAll = index == 0;
                            final genre = isAll ? 'Todos' : _genres[index - 1];
                            final isSelected = isAll ? _myEventsGenre == null : _myEventsGenre == genre;

                            return GestureDetector(
                              onTap: () {
                                setModalState(() => _myEventsGenre = isAll ? null : genre);
                                setState(() => _myEventsGenre = isAll ? null : genre);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.accent : AppTheme.surfaceLight,
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  genre,
                                  style: TextStyle(
                                    color: isSelected ? Colors.black : Colors.white70,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          ),
                          child: const Text('Aplicar filtros', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: hasFilter ? AppTheme.accent : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Icon(Icons.filter_list, color: hasFilter ? Colors.black : Colors.white, size: 20),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: AppTheme.surfaceLight)),
      ),
      child: Row(
        children: [
          _buildNavItem(Icons.home_outlined, Icons.home, 'Inicio', 0),
          _buildNavItem(
              Icons.calendar_month_outlined, Icons.calendar_month, 'Eventos', 1),
          _buildNavItem(Icons.music_note_outlined, Icons.music_note, 'Bailar', 2),
          _buildNavItem(Icons.people_outline, Icons.people, 'Social', 3),
          _buildNavItem(Icons.person_outline, Icons.person, 'Perfil', 4),
        ],
      ),
    );
  }

  Widget _buildNavItem(
      IconData icon, IconData activeIcon, String label, int index) {
    final isSelected = _currentIndex == index;
    final manager = Provider.of<DanceSessionManager>(context, listen: false);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() {
          _currentIndex = index;
          // If we switch away from Solo tab (index 2), set flag to false
          manager.isOnDanceScreen = index == 2;
        }),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isSelected ? activeIcon : icon,
                color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
