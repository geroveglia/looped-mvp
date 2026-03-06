import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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
      title: Text(
        'LOOPED',
        style: AppTheme.titleLarge.copyWith(
          letterSpacing: 2,
          color: AppTheme.accent,
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

    // Filter by genre AND search text
    final query = _searchController.text.toLowerCase();
    final filtered = sortedEvents.where((e) {
      final matchesGenre = _selectedGenre == null || 
          e['genre']?.toString().toLowerCase() == _selectedGenre!.toLowerCase();
      
      final matchesSearch = query.isEmpty || 
          (e['name'] ?? '').toString().toLowerCase().contains(query) ||
          (e['venue_name'] ?? '').toString().toLowerCase().contains(query) ||
          (e['organizer'] ?? '').toString().toLowerCase().contains(query);
          
      return matchesGenre && matchesSearch;
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
            _buildCategorySelector(),
            const SizedBox(height: 30),
            const Text('FEATURED EXPERIENCE', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 16),
            if (featured != null) _buildFeaturedCard(featured),
            const SizedBox(height: 40),
            
            if (todayEvents.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Upcoming Tonight', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () {},
                    child: const Text('See All', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...todayEvents.map((e) => _buildUpcomingRow(e)),
              const SizedBox(height: 30),
            ],

            if (futureEvents.isNotEmpty) ...[
              const Text('Future Experiences', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...futureEvents.map((e) => _buildUpcomingRow(e)),
            ],
            
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
    return SizedBox(
      height: 45,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _genres.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, index) {
          final isAll = index == 0;
          final genre = isAll ? 'All' : _genres[index - 1];
          final isSelected = isAll ? _selectedGenre == null : _selectedGenre == genre;

          return GestureDetector(
            onTap: () => setState(() => _selectedGenre = isAll ? null : genre),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.accent : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(100),
                boxShadow: isSelected ? [BoxShadow(color: AppTheme.accent.withOpacity(0.3), blurRadius: 10, spreadRadius: 1)] : null,
              ),
              child: Center(
                child: Text(
                  genre,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.grey,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedCard(Map<String, dynamic> event) {
    final iconChar = event['icon'] ?? '🎵';
    final isImageUrl = iconChar.toString().startsWith('/');
    final imageUrl = isImageUrl ? '${ApiService.baseUrl}$iconChar' : '';

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventDetailScreen(event: event))),
      child: Container(
        height: 320,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          image: isImageUrl 
              ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
              : null,
          color: const Color(0xFF121212),
        ),
        child: Stack(
          children: [
            if (!isImageUrl) Center(child: Text(iconChar, style: const TextStyle(fontSize: 80))),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              bottom: 24,
              right: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildTag('PUBLIC', const Color(0xFF00C853)),
                      const SizedBox(width: 8),
                      _buildTag('ACTIVE NOW', Colors.white.withOpacity(0.2)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    event['name'] ?? 'Event Name',
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        event['venue_name'] ?? event['city'] ?? 'Global',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
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

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(100)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildUpcomingRow(Map<String, dynamic> event) {
    final iconChar = event['icon'] ?? '🎵';
    final isImageUrl = iconChar.toString().startsWith('/');
    final imageUrl = isImageUrl ? '${ApiService.baseUrl}$iconChar' : '';
    
    String timeDisplay = '20:00';
    if (event['starts_at'] != null) {
      final start = DateTime.parse(event['starts_at']);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final startDate = DateTime(start.year, start.month, start.day);
      
      final timeStr = DateFormat('HH:mm').format(start);
      if (startDate.isAtSameMomentAs(today)) {
        timeDisplay = 'Today · $timeStr';
      } else {
        final dateStr = DateFormat('MMM dd').format(start);
        timeDisplay = '$dateStr · $timeStr';
      }
    }

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventDetailScreen(event: event))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF121212), borderRadius: BorderRadius.circular(24)),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 64,
                height: 64,
                color: const Color(0xFF1A1A1A),
                child: isImageUrl 
                    ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Text(iconChar, style: const TextStyle(fontSize: 24))))
                    : Center(child: Text(iconChar, style: const TextStyle(fontSize: 24))),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        (event['genre'] ?? 'Dance').toString().toUpperCase(),
                        style: const TextStyle(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                      Text(
                        '  · $timeDisplay',
                        style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event['name'] ?? 'Event Name',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event['organizer'] ?? 'Official Looped',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            _buildCircleAddButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleAddButton() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.1))),
      child: const Icon(Icons.add, color: Colors.white, size: 20),
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
                    itemBuilder: (ctx, i) => _buildUpcomingRow(myEvents[i]),
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
