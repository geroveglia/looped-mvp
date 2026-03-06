import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
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
  int _selectedDayIndex = 5;

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

    final totalKm = (derived['km'] ?? 0.0).toStringAsFixed(1);
    final totalSteps = derived['steps'] ?? 0;
    final totalCalories = derived['calories'] ?? 0;

    final totalSeconds = stats['total_seconds'] ?? 0;
    final totalMinutes = totalSeconds ~/ 60;

    // Breakdown
    final soloMin = (stats['solo']?['seconds'] ?? 0) ~/ 60;
    final privateMin = (stats['private']?['seconds'] ?? 0) ~/ 60;
    final publicMin = (stats['public']?['seconds'] ?? 0) ~/ 60;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Profile Header
          _buildProfileHeader(username, level, avatarUrl),
          const SizedBox(height: AppTheme.spacingLg),

          // Top Stats Row (XP, Total Time, Level)
          _buildStatsRow(xp, totalMinutes, level),
          const SizedBox(height: AppTheme.spacingLg),

          // Detailed Category Breakdown (New)
          _buildBreakdownCard(soloMin, privateMin, publicMin),
          const SizedBox(height: AppTheme.spacingLg),

          // Main Stats Card (KM, Cals, Steps)
          _buildMainStatsCard(totalKm, totalCalories, totalSteps),
          const SizedBox(height: AppTheme.spacingLg),

          // This Week Card
          _buildThisWeekCard(),
          const SizedBox(height: AppTheme.spacingLg),

          // Weekly Days
          _buildWeeklyDays(),
          const SizedBox(height: AppTheme.spacingLg),

          // Solo History Action
          _buildActionItem(
            icon: Icons.history,
            title: "Solo Sessions",
            subtitle: "View your dancing history",
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SoloHistoryScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  // ... (Header and ActionItem reused methods if they were inside class,
  // but I'm rewriting the class so I need to include them or assume they exist.
  // The tool replaces existing content, so I must provide ALL methods inside _ProfileScreenState)

  // Re-implementing helper methods to be safe
  Widget _buildActionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: AppTheme.cardDecoration,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppTheme.accent),
        title: Text(title, style: AppTheme.titleSmall),
        subtitle: Text(subtitle, style: AppTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
      ),
    );
  }

  Widget _buildProfileHeader(String username, int level, String? avatarUrl) {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickAndUploadAvatar,
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.accent, width: 3),
                ),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.surfaceLight,
                    image: avatarUrl != null
                        ? DecorationImage(
                            image:
                                NetworkImage('${ApiService.baseUrl}$avatarUrl'),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: avatarUrl == null
                      ? const Icon(Icons.person,
                          size: 40, color: AppTheme.textSecondary)
                      : null,
                ),
              ),
              if (_isUploading)
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black54,
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                            color: AppTheme.accent, strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.background, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt,
                      size: 14, color: AppTheme.background),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        Text(username, style: AppTheme.titleLarge),
        const SizedBox(height: AppTheme.spacingXs),
        Text("Level $level Dancer", style: AppTheme.bodyMedium),
      ],
    );
  }

  Widget _buildStatsRow(int points, int minutes, int level) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          _buildStatColumn("$points", "XP"),
          Container(width: 1, height: 40, color: AppTheme.surfaceBorder),
          _buildStatColumn("$minutes", "Minutes"), // Total Minutes
          Container(width: 1, height: 40, color: AppTheme.surfaceBorder),
          _buildStatColumn("$level", "Level"),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppTheme.titleLarge),
          const SizedBox(height: AppTheme.spacingXs),
          Text(label, style: AppTheme.bodySmall),
        ],
      ),
    );
  }

  // NEW: Breakdown Card
  Widget _buildBreakdownCard(int solo, int subPrivate, int subPublic) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("TIME BY MODE", style: AppTheme.labelMedium),
          const SizedBox(height: AppTheme.spacingMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCategoryStat("Solo", "${solo}m", Icons.person_outline),
              _buildCategoryStat(
                  "Private", "${subPrivate}m", Icons.lock_outline),
              _buildCategoryStat("Public", "${subPublic}m", Icons.public),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCategoryStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceLight,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.accent, size: 20),
        ),
        const SizedBox(height: 8),
        Text(value, style: AppTheme.titleMedium),
        Text(label, style: AppTheme.bodySmall),
      ],
    );
  }

  Widget _buildThisWeekCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("THIS WEEK", style: AppTheme.labelMedium),
              Icon(Icons.directions_run, color: AppTheme.accent, size: 24),
            ],
          ),
          const SizedBox(height: AppTheme.spacingLg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActivityIcon(Icons.music_note, true),
              _buildActivityIcon(Icons.directions_walk, false),
              _buildActivityIcon(Icons.self_improvement, false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityIcon(IconData icon, bool isSelected) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingSm),
      decoration: BoxDecoration(
        color:
            isSelected ? AppTheme.accent.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Icon(
        icon,
        color: isSelected ? AppTheme.accent : AppTheme.textTertiary,
        size: 28,
      ),
    );
  }

  Widget _buildMainStatsCard(String km, int calories, int steps) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          _buildCircularProgress(km),
          const SizedBox(width: AppTheme.spacingLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Updated to match request: Km, Calories, Steps
                _buildStatRow(Icons.route, "${km}km", "Distance"),
                const SizedBox(height: AppTheme.spacingMd),
                _buildStatRow(
                    Icons.local_fire_department, "$calories", "Calories"),
                const SizedBox(height: AppTheme.spacingMd),
                _buildStatRow(Icons.directions_walk, "$steps", "Steps"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularProgress(String km) {
    return SizedBox(
      width: 120,
      height: 120,
      child: CustomPaint(
        painter: _CircularProgressPainter(
          progress: 0.7,
          backgroundColor: AppTheme.surfaceLight,
          progressColor: AppTheme.accent,
          strokeWidth: 10,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("GOAL", style: AppTheme.labelSmall),
              Text(
                km,
                style: AppTheme.displayMedium.copyWith(color: AppTheme.accent),
              ),
              const Text("km", style: AppTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.accent, size: 20),
        const SizedBox(width: AppTheme.spacingSm),
        Text(value, style: AppTheme.titleMedium),
        const SizedBox(width: AppTheme.spacingSm),
        Text(label, style: AppTheme.bodySmall),
      ],
    );
  }

  Widget _buildWeeklyDays() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingLg,
      ),
      decoration: AppTheme.cardDecoration,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_weeklyData.length, (index) {
          final day = _weeklyData[index];
          final isSelected = index == _selectedDayIndex;
          final isActive = day['active'] as bool;

          return GestureDetector(
            onTap: () => setState(() => _selectedDayIndex = index),
            child: Column(
              children: [
                Text(
                  day['day'],
                  style: AppTheme.labelSmall.copyWith(
                    color:
                        isSelected ? AppTheme.accent : AppTheme.textSecondary,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? AppTheme.accent
                        : isActive
                            ? AppTheme.accent.withOpacity(0.2)
                            : Colors.transparent,
                    border: Border.all(
                      color:
                          isActive ? AppTheme.accent : AppTheme.surfaceBorder,
                      width: isSelected ? 0 : 1,
                    ),
                  ),
                  child: isActive
                      ? Icon(
                          Icons.check,
                          size: 18,
                          color: isSelected
                              ? AppTheme.background
                              : AppTheme.accent,
                        )
                      : null,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;
  final double strokeWidth;

  _CircularProgressPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
