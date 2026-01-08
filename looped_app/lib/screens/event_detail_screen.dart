import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/event_service.dart';
import 'live_dance_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final Map<String, dynamic> event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  List<dynamic> _leaderboard = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchLeaderboard());
  }

  Future<void> _fetchLeaderboard() async {
    final lb = await Provider.of<EventService>(context, listen: false)
        .getLeaderboard(widget.event['_id']);
    setState(() => _leaderboard = lb);
  }

  Future<void> _joinAndStart() async {
    final eventService = Provider.of<EventService>(context, listen: false);
    try {
      await eventService.joinEvent(widget.event['_id']);
    } catch (e) {
      // Already joined, ignore
    }
    
    // Navigate to live dance
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LiveDanceScreen(eventId: widget.event['_id']),
        ),
      ).then((_) => _fetchLeaderboard()); // Refresh on return
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.event['name'])),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _joinAndStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text('START DANCE', 
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
              ),
            ),
          ),
          const Divider(color: Colors.grey),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("LEADERBOARD", style: TextStyle(color: Colors.grey, letterSpacing: 1.5)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _leaderboard.length,
              itemBuilder: (ctx, i) {
                final entry = _leaderboard[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.deepPurpleAccent,
                    child: Text('${i + 1}'),
                  ),
                  title: Text(entry['username'] ?? 'User', style: const TextStyle(color: Colors.white)),
                  trailing: Text('${entry['totalPoints']} pts', 
                    style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
