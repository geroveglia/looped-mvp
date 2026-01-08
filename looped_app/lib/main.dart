import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/event_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => EventService()),
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
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.deepPurpleAccent,
        colorScheme: const ColorScheme.dark(
          primary: Colors.deepPurpleAccent,
          secondary: Colors.greenAccent,
          surface: Color(0xFF1E1E1E),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto', // Default, but explicit is good
      ),
      home: const AuthWrapper(),
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
    // Check token on start
    Future.microtask(
        () => Provider.of<AuthService>(context, listen: false).tryAutoLogin());
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    if (auth.isAuth) {
      return const HomeScreen();
    } else {
      return const LoginScreen();
    }
  }
}
