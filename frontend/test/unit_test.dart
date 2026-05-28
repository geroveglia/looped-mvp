import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:looped_app/models/rank_model.dart';
import 'package:looped_app/services/rank_service.dart';

void main() {
  group('Rank Constants & Definition Tests', () {
    test('getByKey should return correct definitions for default ghost rank', () {
      final rank = RankConstants.getByKey('ghost');
      expect(rank.id, 'ghost');
      expect(rank.name, 'El Fantasma');
      expect(rank.emoji, '👻');
      expect(rank.color, const Color(0xFF6B7280));
    });

    test('getByKey should fallback to ghost if rank key does not exist', () {
      final rank = RankConstants.getByKey('unknown_rank_id');
      expect(rank.id, 'ghost');
      expect(rank.emoji, '👻');
    });

    test('getByKey should return correct definition for rookie rank', () {
      final rank = RankConstants.getByKey('rookie');
      expect(rank.id, 'rookie');
      expect(rank.name, 'Rookie de la Previa');
      expect(rank.emoji, '🛋️');
      expect(rank.color, const Color(0xFF39FF14));
    });

    test('getByKey should return correct definition for pistero rank', () {
      final rank = RankConstants.getByKey('pistero');
      expect(rank.id, 'pistero');
      expect(rank.name, 'Pistero');
      expect(rank.emoji, '🔥');
      expect(rank.color, const Color(0xFFFF6B35));
    });

    test('getByKey should return correct definition for vip rank', () {
      final rank = RankConstants.getByKey('vip');
      expect(rank.id, 'vip');
      expect(rank.name, 'Dueño del VIP');
      expect(rank.emoji, '👑');
      expect(rank.color, const Color(0xFFFFD700));
    });
  });

  group('UserRank JSON Deserialization Tests', () {
    test('fromJson parses mock server response accurately', () {
      final json = {
        'rank': 'pistero',
        'monthly_points': 25000,
        'hall_of_fame': false,
        'bonus_multiplier': 1.25,
        'rank_meta': {
          'name': 'Pistero',
          'emoji': '🔥',
          'color': '#FF6B35',
          'description': 'Constante. Activa multiplicadores y tiene buen PPS.',
        },
        'next_rank': {
          'progress': 0.25,
          'nextRankName': 'Dueño del VIP',
          'pointsNeeded': 75000,
        },
        'badges': [
          {
            'id': 'badge_first_dance',
            'name': 'Primer Baile',
            'emoji': '💃',
            'earned_at': '2026-05-28T18:00:00Z',
            'description': '¡Completaste tu primera sesión de baile!',
          }
        ]
      };

      final userRank = UserRank.fromJson(json);

      expect(userRank.rank, 'pistero');
      expect(userRank.rankName, 'Pistero');
      expect(userRank.rankEmoji, '🔥');
      expect(userRank.rankColor, const Color(0xFFFF6B35));
      expect(userRank.monthlyPoints, 25000);
      expect(userRank.nextRankProgress, 0.25);
      expect(userRank.nextRankName, 'Dueño del VIP');
      expect(userRank.pointsToNextRank, 75000);
      expect(userRank.bonusMultiplier, 1.25);
      expect(userRank.badges.length, 1);
      expect(userRank.badges[0].id, 'badge_first_dance');
      expect(userRank.badges[0].name, 'Primer Baile');
      expect(userRank.badges[0].emoji, '💃');
      expect(userRank.badges[0].description, '¡Completaste tu primera sesión de baile!');
    });
  });

  group('RankService profile mapping tests', () {
    test('fromProfileData maps local profiles correctly', () {
      final profile = {
        'username': 'geroveglia',
        'rank': 'vip',
        'monthly_points': 120000,
        'badges': [
          {
            'id': 'gold_dancer',
            'name': 'Bailarín Dorado',
            'emoji': '🏆',
            'description': 'Superaste los 100k puntos mensuales.',
          }
        ]
      };

      final quickRank = RankService.fromProfileData(profile);

      expect(quickRank.rank, 'vip');
      expect(quickRank.monthlyPoints, 120000);
      expect(quickRank.badges.length, 1);
      expect(quickRank.badges[0].name, 'Bailarín Dorado');
      expect(quickRank.badges[0].emoji, '🏆');
    });
  });
}
