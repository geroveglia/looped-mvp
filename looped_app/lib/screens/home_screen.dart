import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/event_service.dart';
import '../services/auth_service.dart';
import 'event_detail_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => 
      Provider.of<EventService>(context, listen: false).fetchEvents()
    );
  }

  void _showCreateEventDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Create Event', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Event Name'),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await Provider.of<EventService>(context, listen: false)
                    .createEvent(nameController.text, true);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final eventService = Provider.of<EventService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Looped Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
               auth.logout();
               Navigator.of(context).pushReplacement(
                 MaterialPageRoute(builder: (_) => const LoginScreen())
               );
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateEventDialog,
        backgroundColor: Colors.deepPurpleAccent,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => eventService.fetchEvents(),
        child: ListView.builder(
          itemCount: eventService.events.length,
          itemBuilder: (ctx, i) {
            final event = eventService.events[i];
            return Card(
              color: const Color(0xFF1E1E1E),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(event['name'], 
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                subtitle: Text('Host: ${event['host_user_id']}'), // Could resolve name if populated
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EventDetailScreen(event: event),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
