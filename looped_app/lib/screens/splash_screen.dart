import 'package:flutter/material.dart';
import 'dart:ui';
import '../ui/app_theme.dart';
import '../main.dart'; // To access AuthWrapper

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _drawAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _drawAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward();

    // Navigate after 3 seconds total
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const AuthWrapper(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AnimatedBuilder(
          animation: _drawAnimation,
          builder: (context, child) {
            return CustomPaint(
              painter: InfinityLogoPainter(progress: _drawAnimation.value),
              size: const Size(120, 60), // Adjust size as needed
            );
          },
        ),
      ),
    );
  }
}

class InfinityLogoPainter extends CustomPainter {
  final double progress;

  InfinityLogoPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final width = size.width;
    final height = size.height;

    // The infinity path consists of two intersecting arcs and connecting lines.
    Path fullPath = Path();

    // Start from the middle crossing point going right and up
    fullPath.moveTo(width / 2, height / 2);

    // Smooth bezier to the top right loop
    fullPath.cubicTo(width * 0.7, 0, width, 0, width, height / 2);

    // Bottom right loop back to center
    fullPath.cubicTo(width, height, width * 0.7, height, width / 2, height / 2);

    // Top left loop
    fullPath.cubicTo(width * 0.3, 0, 0, 0, 0, height / 2);

    // Bottom left loop back to center
    fullPath.cubicTo(0, height, width * 0.3, height, width / 2, height / 2);

    // To draw progressively, we extract the path based on the progress fraction
    PathMetrics pathMetrics = fullPath.computeMetrics();
    for (PathMetric pathMetric in pathMetrics) {
      Path extractedPath = pathMetric.extractPath(
        0.0,
        pathMetric.length * progress,
      );
      canvas.drawPath(extractedPath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant InfinityLogoPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
