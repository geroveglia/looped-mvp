import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../ui/app_theme.dart';
import 'solo_history_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profileData;
  Map<String, dynamic>? _statsData;
  bool _isLoading = true;
  bool _isUploading = false;

  final List<Map<String, dynamic>> _weeklyData = [
    {'day': 'MO', 'active': false, 'minutes': 0},
    {'day': 'TU', 'active': false, 'minutes': 0},
    {'day': 'WE', 'active': true, 'minutes': 45},
    {'day': 'TH', 'active': true, 'minutes': 30},
    {'day': 'FR', 'active': true, 'minutes': 60},
    {'day': 'SA', 'active': true, 'minutes': 120},
    {'day': 'SU', 'active': false, 'minutes': 0},
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final api = ApiService();

      final results =
          await Future.wait([auth.fetchProfile(), api.get('/auth/stats')]);

      if (mounted) {
        setState(() {
          _profileData = results[0];
          _statsData = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print("Error loading profile: $e");
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final bytes = await image.readAsBytes();
      final newUrl = await auth.uploadAvatar(bytes, image.name);

      setState(() {
        _profileData!['avatar_url'] = newUrl;
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated!')),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      );
    }

    if (_profileData == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppTheme.textTertiary),
            SizedBox(height: AppTheme.spacingMd),
            Text("Failed to load profile", style: AppTheme.bodyMedium),
          ],
        ),
      );
    }

    final level = _profileData!['level'] ?? 1;
    final xp = _profileData!['xp'] ?? 0;
    final username = _profileData!['username'] ?? "User";
    final avatarUrl = _profileData!['avatar_url'];

    // Stats
    final stats = _statsData ?? {};
    final derived = stats['derived'] ?? {};

    final totalSteps = derived['steps'] ?? 0;
    final totalCalories = derived['calories'] ?? 0;

    final totalSeconds = stats['total_seconds'] ?? 0;
    final totalMinutes = totalSeconds ~/ 60;

    // Breakdown
    final soloMin = (stats['solo']?['seconds'] ?? 0) ~/ 60;
    final privateMin = (stats['private']?['seconds'] ?? 0) ~/ 60;
    final publicMin = (stats['public']?['seconds'] ?? 0) ~/ 60;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.settings, color: Colors.white),
          onPressed: () {},
        ),
        title: const Text('Profile',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile Header
            _buildProfileHeader(username, level, avatarUrl),
            const SizedBox(height: 32),

            // Top Stats Row (XP, Minutes, Level)
            Row(
              children: [
                _buildTopStatCard(
                    'XP',
                    xp.toString().replaceAllMapped(
                        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                        (Match m) => '${m[1]},'),
                    '+12%',
                    progress: (xp % (level * 1000)) / (level * 1000),
                    isGreenSubtitle: true),
                const SizedBox(width: 12),
                _buildTopStatCard('MINUTES', '$totalMinutes', '+5%',
                    progress: (totalMinutes % 60) / 60, isGreenSubtitle: true),
                const SizedBox(width: 12),
                _buildTopStatCard('LEVEL', '$level', 'Next: 3k',
                    progress: (xp / (level * 1000)).clamp(0.0, 1.0)),
              ],
            ),
            const SizedBox(height: 32),

            // Daily Progress
            _buildDailyProgress(totalSteps, totalCalories),
            const SizedBox(height: 32),

            // Time by Mode
            _buildTimeByMode(soloMin, publicMin, privateMin),
            const SizedBox(height: 32),

            // Weekly Activity
            _buildWeeklyActivity(),
            const SizedBox(height: 24),

            // Solo History Action
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF131313),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const SoloHistoryScreen()),
                  );
                },
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.history, color: AppTheme.accent),
                ),
                title: const Text("My Dance History",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text("View all past sessions",
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              ),
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(String username, int level, String? avatarUrl) {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickAndUploadAvatar,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.accent, width: 4),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF2A2A2A),
                      image: avatarUrl != null
                          ? DecorationImage(
                              image: NetworkImage(
                                  '${ApiService.baseUrl}$avatarUrl'),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: avatarUrl == null
                        ? const Icon(Icons.person, size: 60, color: Colors.grey)
                        : null,
                  ),
                ),
              ),
              if (_isUploading)
                Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black54,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                          color: AppTheme.accent, strokeWidth: 3),
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 3),
                  ),
                  child: const Icon(Icons.edit, size: 16, color: Colors.black),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(username,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text("Level $level Dancer",
            style: const TextStyle(
                color: AppTheme.accent,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTopStatCard(String title, String value, String subtitle,
      {bool isGreenSubtitle = false, double progress = 0.5}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF131313),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5)),
            const SizedBox(height: 12),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFF2A2A2A),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 12),
            Text(subtitle,
                style: TextStyle(
                    color: isGreenSubtitle ? AppTheme.accent : Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyProgress(int steps, int calories) {
    const goal = 10000;
    double progress = (steps / goal).clamp(0.0, 1.0);
    int pct = (progress * 100).toInt();

    return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF131313),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Daily Progress',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Row(children: [
            // circular progress
            SizedBox(
                width: 110,
                height: 110,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox(
                    width: 110,
                    height: 110,
                    child: CircularProgressIndicator(
                      value: progress,
                      color: AppTheme.accent,
                      backgroundColor: const Color(0xFF2A2A2A),
                      strokeWidth: 8,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.directions_run,
                        color: AppTheme.accent, size: 28),
                    const SizedBox(height: 4),
                    Text('$pct%',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                  ])
                ])),
            const SizedBox(width: 32),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Steps',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                      '${steps.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} / ${goal ~/ 1000}k',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  const Text('Calories',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('$calories kcal',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ]))
          ])
        ]));
  }

  Widget _buildTimeByMode(int solo, int public, int private) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Time by Mode',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildModeRow('Solo Training', Icons.person, solo),
        const SizedBox(height: 12),
        _buildModeRow('Public Battles', Icons.people, public),
        const SizedBox(height: 12),
        _buildModeRow('Private Session', Icons.lock, private),
      ],
    );
  }

  Widget _buildModeRow(String title, IconData icon, int minutes) {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF131313),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.accent, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600))),
            Text('${minutes}m',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ],
        ));
  }

  Widget _buildWeeklyActivity() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Weekly Activity',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF131313),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _weeklyData.map((day) {
                bool active = day['active'] as bool;
                return Column(children: [
                  Text(day['day'],
                      style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active ? AppTheme.accent : const Color(0xFF2A2A2A),
                    ),
                    child: active
                        ? const Icon(Icons.check, color: Colors.black, size: 18)
                        : Center(
                            child: Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                    color: Colors.grey,
                                    shape: BoxShape.circle))),
                  )
                ]);
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Divider(color: Color(0xFF2A2A2A), height: 1),
            const SizedBox(height: 20),
            const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Current Streak',
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                  Text('4 Days',
                      style: TextStyle(
                          color: AppTheme.accent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ])
          ]))
    ]);
  }
}
