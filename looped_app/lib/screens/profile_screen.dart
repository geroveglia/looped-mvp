import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../ui/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final data = await auth.fetchProfile();
      if (mounted) {
        setState(() {
          _profileData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppTheme.textTertiary),
            const SizedBox(height: AppTheme.spacingMd),
            Text("Failed to load profile", style: AppTheme.bodyMedium),
          ],
        ),
      );
    }

    final level = _profileData!['level'] ?? 1;
    final xp = _profileData!['xp'] ?? 0;
    final xpToNext = _profileData!['xp_to_next'] ?? 1000;
    final progress = (_profileData!['xp_progress'] as num?)?.toDouble() ?? 0.0;
    final username = _profileData!['username'] ?? "User";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header Card
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            decoration: AppTheme.cardDecoration,
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accent.withOpacity(0.15),
                    border: Border.all(
                        color: AppTheme.accent.withOpacity(0.3), width: 2),
                  ),
                  child: const Icon(Icons.person,
                      size: 40, color: AppTheme.accent),
                ),
                const SizedBox(width: AppTheme.spacingLg),
                // Name and role
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(username, style: AppTheme.titleLarge),
                      const SizedBox(height: AppTheme.spacingXs),
                      Text("Dancer", style: AppTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Level Card
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            decoration: AppTheme.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("LEVEL", style: AppTheme.labelMedium),
                        const SizedBox(height: AppTheme.spacingXs),
                        Text(
                          "$level",
                          style: AppTheme.displayLarge
                              .copyWith(color: AppTheme.accent),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingMd),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.star,
                          color: AppTheme.warning, size: 32),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingLg),

                // Progress bar
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: progress),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => ProgressBar(
                    progress: value,
                    color: AppTheme.accent,
                    height: 10,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMd),

                // XP info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("$xp XP",
                        style: AppTheme.bodyLarge
                            .copyWith(color: AppTheme.accent)),
                    Text(
                      "${xpToNext - xp} XP to Level ${level + 1}",
                      style: AppTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Stats Section
          Text("STATS", style: AppTheme.labelLarge),
          const SizedBox(height: AppTheme.spacingMd),

          _buildStatCard("Total Points", "$xp", Icons.emoji_events),
          _buildStatCard("Level", "$level", Icons.trending_up),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingSm),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(icon, color: AppTheme.textSecondary, size: 20),
          ),
          const SizedBox(width: AppTheme.spacingMd),
          Text(label, style: AppTheme.bodyLarge),
          const Spacer(),
          Text(value, style: AppTheme.titleMedium),
        ],
      ),
    );
  }
}
