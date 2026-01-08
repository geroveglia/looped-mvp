import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/event_service.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'event_detail_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'create_event_screen.dart';
import '../ui/animations/fade_slide_route.dart';

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
  String? _selectedCity;

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
      // Text search
      if (_searchController.text.isNotEmpty) {
        final query = _searchController.text.toLowerCase();
        final name = (event['name'] ?? '').toString().toLowerCase();
        final venue = (event['venue_name'] ?? '').toString().toLowerCase();
        if (!name.contains(query) && !venue.contains(query)) return false;
      }

      // Genre filter
      if (_selectedGenre != null) {
        final genre = (event['genre'] ?? '').toString().toLowerCase();
        if (genre != _selectedGenre!.toLowerCase()) return false;
      }

      // City filter
      if (_selectedCity != null) {
        final city = (event['city'] ?? '').toString().toLowerCase();
        if (city != _selectedCity!.toLowerCase()) return false;
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
          date != null ? DateFormat('EEEE, d MMMM').format(date) : 'Sin fecha';

      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(event);
    }

    return grouped;
  }

  Widget _buildEventImage(String iconValue) {
    if (iconValue.startsWith('/')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          '${ApiService.baseUrl}$iconValue',
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
        ),
      );
    } else {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(iconValue, style: const TextStyle(fontSize: 32)),
      );
    }
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.music_note, color: Colors.white54, size: 32),
    );
  }

  void _showGenreFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Seleccionar Género',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterOption(null, 'Todos', _selectedGenre == null,
                    (val) {
                  setState(() => _selectedGenre = null);
                  Navigator.pop(ctx);
                }),
                ..._genres.map(
                    (g) => _buildFilterOption(g, g, _selectedGenre == g, (val) {
                          setState(() => _selectedGenre = val);
                          Navigator.pop(ctx);
                        })),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(
      String? value, String label, bool isSelected, Function(String?) onTap) {
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purpleAccent : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.purpleAccent : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final venue =
        event['venue_name'] ?? event['city'] ?? 'Ubicación desconocida';
    final genre = (event['genre'] ?? 'Other').toString();
    final iconChar = event['icon'] ?? '🎵';
    final isLive = event['status'] == 'active';

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            FadeSlideRoute(page: EventDetailScreen(event: event)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Event Image
              _buildEventImage(iconChar),
              const SizedBox(width: 12),
              // Event Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      event['name'] ?? 'Evento',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Venue
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            venue,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Genre
                    Row(
                      children: [
                        const Icon(Icons.music_note,
                            size: 14, color: Colors.purpleAccent),
                        const SizedBox(width: 4),
                        Text(
                          genre,
                          style: const TextStyle(
                              color: Colors.purpleAccent, fontSize: 12),
                        ),
                        if (isLive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle,
                                    size: 6, color: Colors.greenAccent),
                                SizedBox(width: 4),
                                Text('LIVE',
                                    style: TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // More button
              IconButton(
                icon: const Icon(Icons.more_horiz, color: Colors.grey),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventsPage(EventService eventService) {
    final events = eventService.events.cast<Map<String, dynamic>>();
    final filteredEvents = _filterEvents(events);
    final groupedEvents = _groupByDate(filteredEvents);

    return Column(
      children: [
        // Search Bar (when active)
        if (_isSearching)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar eventos...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                      _searchController.clear();
                    });
                  },
                ),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

        // Filter Chips
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildFilterChip('Género', _selectedGenre, _showGenreFilter),
              const SizedBox(width: 8),
              _buildFilterChip('Ubicación', _selectedCity, () {
                // TODO: Implement city filter
              }),
              const SizedBox(width: 8),
              _buildFilterChip('Fecha', null, () {
                // TODO: Implement date filter
              }),
              const SizedBox(width: 8),
              _buildFilterChip('Estado', null, () {
                // TODO: Implement status filter
              }),
            ],
          ),
        ),

        // Events List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => eventService.fetchEvents(),
            child: filteredEvents.isEmpty
                ? const Center(
                    child: Text('No se encontraron eventos',
                        style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: groupedEvents.length,
                    itemBuilder: (ctx, groupIndex) {
                      final dateKey = groupedEvents.keys.elementAt(groupIndex);
                      final eventsForDate = groupedEvents[dateKey]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date Header
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              dateKey,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Events for this date
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

  Widget _buildFilterChip(
      String label, String? selectedValue, VoidCallback onTap) {
    final hasSelection = selectedValue != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: hasSelection
              ? Colors.purpleAccent.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasSelection ? Colors.purpleAccent : Colors.white30,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hasSelection ? selectedValue : label,
              style: TextStyle(
                color: hasSelection ? Colors.purpleAccent : Colors.white,
                fontWeight: hasSelection ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: hasSelection ? Colors.purpleAccent : Colors.white54,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final eventService = Provider.of<EventService>(context);

    final List<Widget> pages = [
      _buildEventsPage(eventService),
      const ProfileScreen()
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: _currentIndex == 0
            ? const Text('LOOPED',
                style: TextStyle(
                  color: Colors.purpleAccent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ))
            : const Text('Mi Perfil', style: TextStyle(color: Colors.white)),
        actions: [
          if (_currentIndex == 0)
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: () => setState(() => _isSearching = !_isSearching),
            ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
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
              backgroundColor: Colors.purpleAccent,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (idx) => setState(() => _currentIndex = idx),
        backgroundColor: Colors.black,
        selectedItemColor: Colors.purpleAccent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Inicio"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Perfil"),
        ],
      ),
    );
  }
}
