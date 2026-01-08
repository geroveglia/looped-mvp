import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => Provider.of<EventService>(context, listen: false).fetchEvents());
  }

  Widget _buildEventIcon(String iconValue) {
    if (iconValue.startsWith('/')) {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
                image: NetworkImage('${ApiService.baseUrl}$iconValue'),
                fit: BoxFit.cover)),
      );
    } else {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(iconValue, style: const TextStyle(fontSize: 24)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final eventService = Provider.of<EventService>(context);

    final List<Widget> pages = [
      // Event List Page
      RefreshIndicator(
        onRefresh: () => eventService.fetchEvents(),
        child: ListView.builder(
          itemCount: eventService.events.length,
          itemBuilder: (ctx, i) {
            final event = eventService.events[i];

            // Extract new fields with fallbacks
            final venue =
                event['venue_name'] ?? event['city'] ?? 'Unknown Location';
            final genre = (event['genre'] ?? 'Other').toString().toUpperCase();
            final date = DateTime.tryParse(event['starts_at'] ?? '');
            final dateStr = date != null
                ? "${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}"
                : "";
            final iconChar = event['icon'] ?? '🎵';

            return Card(
              color: const Color(0xFF1E1E1E),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    FadeSlideRoute(page: EventDetailScreen(event: event)),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // Icon Badge
                      _buildEventIcon(iconChar),
                      const SizedBox(width: 16),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                      color:
                                          Colors.purpleAccent.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4)),
                                  child: Text(genre,
                                      style: const TextStyle(
                                          color: Colors.purpleAccent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                ),
                                if (event['status'] == 'active')
                                  const Row(
                                    children: [
                                      Icon(Icons.circle,
                                          size: 8, color: Colors.greenAccent),
                                      SizedBox(width: 4),
                                      Text("LIVE",
                                          style: TextStyle(
                                              color: Colors.greenAccent,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  )
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(event['name'],
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Row(children: [
                              const Icon(Icons.location_on,
                                  size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(venue,
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                              const SizedBox(width: 10),
                              if (dateStr.isNotEmpty) ...[
                                const Icon(Icons.access_time,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(dateStr,
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 12)),
                              ]
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      // Profile Page
      const ProfileScreen()
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'Looped Events' : 'My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
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
                  MaterialPageRoute(
                      builder: (_) =>
                          const CreateEventScreen()), // No fancy transition needed for modal-like screen, or use FadeSlideRoute
                );
              },
              backgroundColor: Colors.deepPurpleAccent,
              child: const Icon(Icons.add),
            )
          : null,
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (idx) => setState(() => _currentIndex = idx),
        backgroundColor: Colors.black,
        selectedItemColor: Colors.deepPurpleAccent,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.event), label: "Events"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
