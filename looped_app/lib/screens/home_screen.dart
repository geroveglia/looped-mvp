import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/event_service.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../ui/app_theme.dart';
import 'event_detail_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'create_event_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Search & Filter State
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedGenre;

  final List<String> _genres = [
    'Techno',
    'House',
    'Reggaeton',
    'Trance',
    'Pop',
    'HipHop',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => Provider.of<EventService>(context, listen: false).fetchEvents());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterEvents(List<Map<String, dynamic>> events) {
    return events.where((event) {
      if (_searchController.text.isNotEmpty) {
        final query = _searchController.text.toLowerCase();
        final name = (event['name'] ?? '').toString().toLowerCase();
        final venue = (event['venue_name'] ?? '').toString().toLowerCase();
        if (!name.contains(query) && !venue.contains(query)) return false;
      }

      if (_selectedGenre != null) {
        final genre = (event['genre'] ?? '').toString().toLowerCase();
        if (genre != _selectedGenre!.toLowerCase()) return false;
      }

      return true;
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> _groupByDate(
      List<Map<String, dynamic>> events) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final event in events) {
      final date = DateTime.tryParse(event['starts_at'] ?? '');
      final key =
          date != null ? DateFormat('EEEE, d MMMM').format(date) : 'No date';

      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(event);
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final eventService = Provider.of<EventService>(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: Text(
          _currentIndex == 0 ? 'LOOPED' : 'Profile',
          style: AppTheme.titleLarge.copyWith(
            letterSpacing: _currentIndex == 0 ? 3 : 0,
            color: _currentIndex == 0 ? AppTheme.accent : AppTheme.textPrimary,
          ),
        ),
        actions: [
          if (_currentIndex == 0)
            IconButton(
              icon: Icon(
                _isSearching ? Icons.close : Icons.search,
                color: AppTheme.textPrimary,
              ),
              onPressed: () => setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchController.clear();
              }),
            ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.textSecondary),
            onPressed: () {
              auth.logout();
              Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          )
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateEventScreen()),
                );
              },
              backgroundColor: AppTheme.accent,
              child: const Icon(Icons.add, color: AppTheme.background),
            )
          : null,
      body: _currentIndex == 0
          ? _buildEventsPage(eventService)
          : const ProfileScreen(),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppTheme.surface,
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        indicatorColor: AppTheme.accent.withOpacity(0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: AppTheme.textSecondary),
            selectedIcon: Icon(Icons.home, color: AppTheme.accent),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, color: AppTheme.textSecondary),
            selectedIcon: Icon(Icons.person, color: AppTheme.accent),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildEventsPage(EventService eventService) {
    final events = eventService.events.cast<Map<String, dynamic>>();
    final filteredEvents = _filterEvents(events);
    final groupedEvents = _groupByDate(filteredEvents);

    return Column(
      children: [
        // Search Bar
        if (_isSearching)
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: AppTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Search events...',
                hintStyle: AppTheme.bodyMedium,
                prefixIcon:
                    const Icon(Icons.search, color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

        // Filter Chips
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
            children: [
              _buildFilterChip('All', _selectedGenre == null, () {
                setState(() => _selectedGenre = null);
              }),
              ..._genres.map((g) => _buildFilterChip(
                    g,
                    _selectedGenre == g,
                    () => setState(() => _selectedGenre = g),
                  )),
            ],
          ),
        ),

        const SizedBox(height: AppTheme.spacingMd),

        // Events List
        Expanded(
          child: RefreshIndicator(
            color: AppTheme.accent,
            onRefresh: () => eventService.fetchEvents(),
            child: filteredEvents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_busy,
                            size: 64, color: AppTheme.textTertiary),
                        const SizedBox(height: AppTheme.spacingMd),
                        Text('No events found', style: AppTheme.bodyMedium),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingMd),
                    itemCount: groupedEvents.length,
                    itemBuilder: (ctx, groupIndex) {
                      final dateKey = groupedEvents.keys.elementAt(groupIndex);
                      final eventsForDate = groupedEvents[dateKey]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppTheme.spacingMd),
                            child: Text(dateKey, style: AppTheme.titleSmall),
                          ),
                          ...eventsForDate
                              .map((event) => _buildEventCard(event)),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: AppTheme.spacingSm),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMd,
            vertical: AppTheme.spacingSm,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.accent.withOpacity(0.15)
                : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusRound),
            border: Border.all(
              color: isSelected
                  ? AppTheme.accent.withOpacity(0.5)
                  : AppTheme.surfaceBorder,
            ),
          ),
          child: Text(
            label,
            style: AppTheme.bodyMedium.copyWith(
              color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final venue = event['venue_name'] ?? event['city'] ?? 'Unknown';
    final genre = (event['genre'] ?? 'Other').toString();
    final iconChar = event['icon'] ?? '🎵';
    final status = event['status'] ?? 'waiting';
    final isLive = status == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      decoration: AppTheme.cardDecoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => EventDetailScreen(event: event)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Row(
              children: [
                // Event Image
                _buildEventImage(iconChar),
                const SizedBox(width: AppTheme.spacingMd),

                // Event Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status + Genre row
                      Row(
                        children: [
                          if (isLive) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.success.withOpacity(0.15),
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusSm),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.success,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text('LIVE',
                                      style: AppTheme.labelSmall
                                          .copyWith(color: AppTheme.success)),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingSm),
                          ],
                          Text(genre, style: AppTheme.labelSmall),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingSm),

                      // Name
                      Text(
                        event['name'] ?? 'Event',
                        style: AppTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppTheme.spacingXs),

                      // Venue
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              venue,
                              style: AppTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Arrow
                const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventImage(String iconValue) {
    if (iconValue.startsWith('/')) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          image: DecorationImage(
            image: NetworkImage('${ApiService.baseUrl}$iconValue'),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Center(
          child: Text(iconValue, style: const TextStyle(fontSize: 28)),
        ),
      );
    }
  }
}
