import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/event_service.dart';
import 'services/motion_scoring_service.dart';
import 'services/leaderboard_service.dart';
import 'services/dance_session_manager.dart';
import 'services/solo_session_manager.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'ui/now_dancing_overlay.dart';
import 'ui/app_theme.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => EventService()),
        ChangeNotifierProvider(create: (_) => MotionScoringService()),
        ChangeNotifierProvider(create: (_) => LeaderboardService()),
        ChangeNotifierProvider(create: (_) => DanceSessionManager()),
        ChangeNotifierProvider(create: (_) => SoloSessionManager()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Looped',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      home: const SplashScreen(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => Provider.of<AuthService>(context, listen: false).tryAutoLogin());
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    // Connect DanceSessionManager to MotionScoringService
    final danceManager =
        Provider.of<DanceSessionManager>(context, listen: false);
    final motionService =
        Provider.of<MotionScoringService>(context, listen: false);
    danceManager.setMotionService(motionService);

    final soloManager = Provider.of<SoloSessionManager>(context, listen: false);
    soloManager.setMotionService(motionService);

    Widget homeContent;
    if (auth.isAuth) {
      homeContent = const HomeScreen();
    } else {
      homeContent = const LoginScreen();
    }

    // Wrap with overlay only if authenticated
    if (auth.isAuth) {
      return NowDancingOverlay(child: homeContent);
    }
    return homeContent;
  }
}
