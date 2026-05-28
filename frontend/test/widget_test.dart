import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:looped_app/screens/splash_screen.dart';
import 'package:looped_app/services/auth_service.dart';
import 'package:looped_app/services/event_service.dart';
import 'package:looped_app/services/motion_scoring_service.dart';
import 'package:looped_app/services/leaderboard_service.dart';
import 'package:looped_app/services/dance_session_manager.dart';
import 'package:looped_app/services/solo_session_manager.dart';

void main() {
  testWidgets('SplashScreen rendering and logo drawing smoke test', (WidgetTester tester) async {
    // Build the SplashScreen widget wrapped in all required providers.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthService()),
          ChangeNotifierProvider(create: (_) => EventService()),
          ChangeNotifierProvider(create: (_) => MotionScoringService()),
          ChangeNotifierProvider(create: (_) => LeaderboardService()),
          ChangeNotifierProvider(create: (_) => DanceSessionManager()),
          ChangeNotifierProvider(create: (_) => SoloSessionManager()),
        ],
        child: const MaterialApp(
          home: SplashScreen(),
        ),
      ),
    );

    // Verify that the SplashScreen is rendered.
    expect(find.byType(SplashScreen), findsOneWidget);

    // Verify that the custom paint widget for the infinity logo exists.
    expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
    
    // Allow the animations and timer to complete to ensure clean disposal.
    await tester.pump(const Duration(seconds: 4));
  });
}
