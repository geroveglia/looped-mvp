import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/event_service.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/dance_session_manager.dart';
import '../ui/app_theme.dart';
import 'event_detail_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'create_event_screen.dart';
import 'solo_dance_screen.dart';
import 'solo_history_screen.dart';

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
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showJoinByCodeDialog() {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: const Text('Join Private Event', style: AppTheme.titleMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the invite code shared by the host', style: AppTheme.bodyMedium),
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
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
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
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joined event!')));
                  if (result['event'] != null) {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventDetailScreen(event: result['event'])));
                  }
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('JOIN'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _currentIndex == 0 ? _buildAppBar() : null,
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  AppBar _buildAppBar() {
    final auth = Provider.of<AuthService>(context, listen: false);
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: const Text(
        'DanceEvents',
        style: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white),
          onPressed: () => setState(() {
            _isSearching = !_isSearching;
            if (!_isSearching) _searchController.clear();
          }),
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white70),
          onPressed: () {
            auth.logout();
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
          },
        ),
        IconButton(
          icon: const Icon(Icons.qr_code, color: Colors.white70),
          onPressed: _showJoinByCodeDialog,
          tooltip: 'Join by Code',
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, color: AppTheme.accent),
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateEventScreen()));
          },
          tooltip: 'Create Event',
        ),
        IconButton(
          icon: const Icon(Icons.history, color: Colors.white70),
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SoloHistoryScreen()));
          },
          tooltip: 'Solo History',
        ),
      ],
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
      final isPublic = e['is_private'] != true;
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
          final eDate = DateTime.parse(e['starts_at']);
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

    // Categorize (excluding featured)
    final List<Map<String, dynamic>> todayEvents = [];
    final List<Map<String, dynamic>> futureEvents = [];

    for (var i = 0; i < filtered.length; i++) {
       final e = filtered[i];
       if (i == 0) continue; // Skip featured
       
       if (e['starts_at'] == null) {
         todayEvents.add(e);
         continue;
       }
       final start = DateTime.parse(e['starts_at']);
       final startDate = DateTime(start.year, start.month, start.day);
       if (startDate.isAtSameMomentAs(today)) {
         todayEvents.add(e);
       } else if (startDate.isAfter(today)) {
         futureEvents.add(e);
       }
    }

    final featured = filtered.isNotEmpty ? filtered.first : null;

    return RefreshIndicator(
      color: AppTheme.accent,
      onRefresh: () async {
        await Provider.of<EventService>(context, listen: false).fetchEvents();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isSearching) _buildSearchBar(),
            const SizedBox(height: 10),
            _buildDailyActivityCard(),
            const SizedBox(height: 16),
            _buildCategorySelector(),
            const SizedBox(height: 32),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Trending Events', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () {},
                  child: const Text('View all', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (featured != null) _buildEventCard(featured, isLive: true),
            ...todayEvents.map((e) => _buildEventCard(e)),
            ...futureEvents.map((e) => _buildEventCard(e, isFuture: true)),
            
            const SizedBox(height: 100),
          ],
        ),
      ),
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
          hintText: 'Search experiences...',
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
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
          backgroundColor: const Color(0xFF131313),
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
                        const Text('Filters', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 24),
                        
                        // Genre
                        const Text('Genre', style: TextStyle(color: Colors.grey, fontSize: 14)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: List.generate(_genres.length + 1, (index) {
                            final isAll = index == 0;
                            final genre = isAll ? 'All' : _genres[index - 1];
                            final isSelected = isAll ? _selectedGenre == null : _selectedGenre == genre;
                            
                            return GestureDetector(
                              onTap: () {
                                setModalState(() => _selectedGenre = isAll ? null : genre);
                                setState(() => _selectedGenre = isAll ? null : genre);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.accent : const Color(0xFF1E1E1E),
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
                        const Text('Date', style: TextStyle(color: Colors.grey, fontSize: 14)),
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
                            decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedDate != null ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}' : 'Any Date',
                                  style: TextStyle(color: _selectedDate != null ? Colors.white : Colors.grey, fontSize: 16),
                                ),
                                if (_selectedDate != null)
                                  GestureDetector(
                                    onTap: () {
                                      setModalState(() => _selectedDate = null);
                                      setState(() => _selectedDate = null);
                                    },
                                    child: const Icon(Icons.close, color: Colors.grey, size: 20),
                                  )
                                else
                                  const Icon(Icons.calendar_today, color: Colors.grey, size: 20),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Location
                        const Text('Location (City)', style: TextStyle(color: Colors.grey, fontSize: 14)),
                        const SizedBox(height: 12),
                        TextField(
                          onChanged: (val) {
                            final formatted = val.trim().isEmpty ? null : val.trim();
                            setModalState(() => _selectedLocation = formatted);
                            setState(() => _selectedLocation = formatted);
                          },
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Any City (e.g., Berlin)',
                            hintStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: const Color(0xFF1E1E1E),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            suffixIcon: _selectedLocation != null 
                              ? IconButton(
                                  icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                                  onPressed: () {
                                    // Hack to clear textField visually via state would require a controller,
                                    // but we can at least clear the filter value.
                                    setModalState(() => _selectedLocation = null);
                                    setState(() => _selectedLocation = null);
                                  },
                                )
                              : const Icon(Icons.location_on, color: Colors.grey, size: 20),
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
                          child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
          color: (_selectedGenre != null || _selectedDate != null || _selectedLocation != null) ? AppTheme.accent : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list, color: (_selectedGenre != null || _selectedDate != null || _selectedLocation != null) ? Colors.black : AppTheme.accent, size: 18),
            const SizedBox(width: 8),
            Text(
              (_selectedGenre != null || _selectedDate != null || _selectedLocation != null) ? 'Filters Active' : 'Filters',
              style: TextStyle(
                color: (_selectedGenre != null || _selectedDate != null || _selectedLocation != null) ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, color: (_selectedGenre != null || _selectedDate != null || _selectedLocation != null) ? Colors.black54 : Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyActivityCard() {
    final manager = Provider.of<DanceSessionManager>(context);
    final steps = manager.steps;
    const goal = 10000;
    final progress = (steps / goal).clamp(0.0, 1.0);
    final percentage = (progress * 100).toInt();
    final remaining = goal - steps > 0 ? goal - steps : 0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF131313),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('DAILY ACTIVITY', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        steps.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},'),
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      const Text('steps', style: TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                ],
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1E1E1E), width: 3),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
                      strokeWidth: 3,
                    ),
                    const Icon(Icons.bolt, color: AppTheme.accent, size: 24),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Daily Goal', style: TextStyle(color: Colors.grey, fontSize: 12)),
              Text('$percentage%', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFF2A2A2A),
              valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            remaining > 0 ? 'Almost at your goal! ${remaining.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} more to go.' : 'Goal reached! Well done.',
            style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event, {bool isLive = false, bool isFuture = false}) {
    final iconChar = event['icon'] ?? '🎵';
    final isImageUrl = iconChar.toString().startsWith('/');
    final imageUrl = isImageUrl ? '${ApiService.baseUrl}$iconChar' : '';
    
    String countdownStr = 'STARTS IN 14h';
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
        countdownStr = 'STARTED';
      }
    }

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventDetailScreen(event: event))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
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
                      Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E1E1E), child: Center(child: Text(iconChar, style: const TextStyle(fontSize: 48)))))
                    else
                      Container(color: const Color(0xFF1E1E1E), child: Center(child: Text(iconChar, style: const TextStyle(fontSize: 48)))),
                    
                    // Badges
                    Positioned(
                      top: 12,
                      left: 12,
                      child: isLive 
                          ? _buildBadge('LIVE NOW', const Color(0xFFFF3333))
                          : (isFuture ? _buildBadge('TOMORROW', AppTheme.accent.withOpacity(0.15), textColor: AppTheme.accent) : const SizedBox.shrink()),
                    ),
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(4)),
                        child: Text(isLive ? '${(event.hashCode % 900) + 120} watching' : '${(event.hashCode % 50) + 12} registered', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
                            Icon(isLive ? Icons.location_on : Icons.videocam, color: Colors.grey, size: 14),
                            const SizedBox(width: 4),
                            Expanded(child: Text(event['venue_name'] ?? 'Virtual Session', style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (isLive) ...[
                              // mock avatars
                              Container(width: 24, height: 24, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
                              Transform.translate(offset: const Offset(-8, 0), child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: Colors.white54, shape: BoxShape.circle))),
                              Transform.translate(offset: const Offset(-16, 0), child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: Color(0xFF2A2A2A), shape: BoxShape.circle), child: const Center(child: Text('+12', style: TextStyle(color: Colors.white, fontSize: 8))))),
                            ] else ...[
                              const Text('Tap to join', style: TextStyle(color: Colors.grey, fontSize: 10, fontStyle: FontStyle.italic)),
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
                        const Text('CURRENT RANK', style: TextStyle(color: AppTheme.accent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 4),
                        Text('#${(event.hashCode % 10) + 2}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ] else ...[
                        const Text('STARTS IN', style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
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
                          child: const Text('Join Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ) :
                        OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.accent,
                            side: const BorderSide(color: AppTheme.accent),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                            minimumSize: const Size(0, 32),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Remind', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
          if (text == 'LIVE NOW') ...[
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

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('My Events', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: myEvents.isEmpty
                ? const Center(child: Text('You haven\'t joined any events yet', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: myEvents.length,
                    itemBuilder: (ctx, i) => _buildEventCard(myEvents[i], isFuture: true),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Color(0xFF1A1A1A))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavIcon(Icons.home, 0),
          _buildNavIcon(Icons.calendar_month, 1),
          _buildNavIcon(Icons.music_note, 2),
          _buildNavIcon(Icons.person, 3),
        ],
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, int index) {
    final isSelected = _currentIndex == index;
    final manager = Provider.of<DanceSessionManager>(context, listen: false);
    return GestureDetector(
      onTap: () => setState(() {
        _currentIndex = index;
        // If we switch away from Solo tab (index 2), set flag to false
        if (index != 2) {
          manager.isOnDanceScreen = false;
        } else {
          manager.isOnDanceScreen = true;
        }
      }),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? AppTheme.accent : Colors.grey.shade700, size: 28),
          if (isSelected) ...[
            const SizedBox(height: 4),
            Container(width: 4, height: 4, decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle)),
          ],
        ],
      ),
    );
  }
}
