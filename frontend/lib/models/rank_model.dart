import 'package:flutter/material.dart';

/// Rank thresholds and metadata — mirrors the backend's rankUtils.js
class RankDefinition {
  final String id;
  final String name;
  final String emoji;
  final Color color;
  final Color glowColor;
  final String description;
  final int? minPoints;

  const RankDefinition({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    required this.glowColor,
    required this.description,
    this.minPoints,
  });
}

class RankConstants {
  static const List<RankDefinition> ranks = [
    RankDefinition(
      id: 'ghost',
      name: 'El Fantasma',
      emoji: '👻',
      color: Color(0xFF6B7280),
      glowColor: Color(0x336B7280),
      description: 'El que dice que va y cancela a último momento.',
      minPoints: 0,
    ),
    RankDefinition(
      id: 'rookie',
      name: 'Rookie de la Previa',
      emoji: '🛋️',
      color: Color(0xFF39FF14),
      glowColor: Color(0x3339FF14),
      description: 'Sale, suma puntos, pero todavía le falta resistencia.',
      minPoints: 5000,
    ),
    RankDefinition(
      id: 'pistero',
      name: 'Pistero',
      emoji: '🔥',
      color: Color(0xFFFF6B35),
      glowColor: Color(0x33FF6B35),
      description: 'Constante. Activa multiplicadores y tiene buen PPS.',
      minPoints: 20000,
    ),
    RankDefinition(
      id: 'vip',
      name: 'Dueño del VIP',
      emoji: '👑',
      color: Color(0xFFFFD700),
      glowColor: Color(0x33FFD700),
      description: 'El alma de la fiesta. Sale jueves, viernes y sábado.',
      minPoints: 100000,
    ),
    RankDefinition(
      id: 'immortal',
      name: 'El Inmortal',
      emoji: '⚡',
      color: Color(0xFFFF00FF),
      glowColor: Color(0x44FF00FF),
      description: 'La élite. Top 100 Global del Mes.',
      minPoints: null, // Top 100 based
    ),
  ];

  static RankDefinition getByKey(String rankId) {
    return ranks.firstWhere(
      (r) => r.id == rankId,
      orElse: () => ranks.first,
    );
  }

  static Color getRankColor(String rankId) => getByKey(rankId).color;
  static String getRankEmoji(String rankId) => getByKey(rankId).emoji;
  static String getRankName(String rankId) => getByKey(rankId).name;
}

/// User's current rank status (from GET /ranks/me)
class UserRank {
  final String rank;
  final String rankName;
  final String rankEmoji;
  final Color rankColor;
  final String rankDescription;
  final int monthlyPoints;
  final double nextRankProgress;
  final String? nextRankName;
  final int? pointsToNextRank;
  final int? top100Position;
  final bool isTop100;
  final List<Badge> badges;
  final bool hallOfFame;
  final double bonusMultiplier;

  UserRank({
    required this.rank,
    required this.rankName,
    required this.rankEmoji,
    required this.rankColor,
    required this.rankDescription,
    required this.monthlyPoints,
    required this.nextRankProgress,
    this.nextRankName,
    this.pointsToNextRank,
    this.top100Position,
    this.isTop100 = false,
    required this.badges,
    this.hallOfFame = false,
    this.bonusMultiplier = 1.0,
  });

  factory UserRank.fromJson(Map<String, dynamic> json) {
    final rankMeta = json['rank_meta'] ?? {};
    final nextRank = json['next_rank'] ?? {};

    return UserRank(
      rank: json['rank'] ?? 'ghost',
      rankName: rankMeta['name'] ?? 'El Fantasma',
      rankEmoji: rankMeta['emoji'] ?? '👻',
      rankColor: _hexToColor(rankMeta['color'] ?? '#6B7280'),
      rankDescription: rankMeta['description'] ?? '',
      monthlyPoints: json['monthly_points'] ?? 0,
      nextRankProgress: (nextRank['progress'] ?? 0.0).toDouble(),
      nextRankName: nextRank['nextRankName'],
      pointsToNextRank: nextRank['pointsNeeded'],
      top100Position: json['top100_position'],
      isTop100: json['is_top100'] ?? false,
      badges: (json['badges'] as List?)
              ?.map((b) => Badge.fromJson(b))
              .toList() ??
          [],
      hallOfFame: json['hall_of_fame'] ?? false,
      bonusMultiplier: (json['bonus_multiplier'] ?? 1.0).toDouble(),
    );
  }

  static Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}

/// Badge model
class Badge {
  final String id;
  final String name;
  final String emoji;
  final DateTime? earnedAt;
  final String description;

  Badge({
    required this.id,
    required this.name,
    required this.emoji,
    this.earnedAt,
    required this.description,
  });

  factory Badge.fromJson(Map<String, dynamic> json) {
    return Badge(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      emoji: json['emoji'] ?? '🏅',
      earnedAt: json['earned_at'] != null
          ? DateTime.tryParse(json['earned_at'])
          : null,
      description: json['description'] ?? '',
    );
  }
}

/// Top 100 entry
class Top100Entry {
  final int position;
  final String userId;
  final String username;
  final String? avatarUrl;
  final int monthlyPoints;
  final String rank;
  final bool hallOfFame;

  Top100Entry({
    required this.position,
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.monthlyPoints,
    required this.rank,
    this.hallOfFame = false,
  });

  factory Top100Entry.fromJson(Map<String, dynamic> json) {
    return Top100Entry(
      position: json['position'] ?? 0,
      userId: json['user_id'] ?? '',
      username: json['username'] ?? '',
      avatarUrl: json['avatar_url'],
      monthlyPoints: json['monthly_points'] ?? 0,
      rank: json['rank'] ?? 'ghost',
      hallOfFame: json['hall_of_fame'] ?? false,
    );
  }
}
