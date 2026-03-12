import 'dart:math';
import 'package:flutter/material.dart';
import '../models/rank_model.dart';
import '../services/api_service.dart';

/// Reusable avatar widget that displays a colored border based on user rank.
/// For "immortal" rank, the border is an animated rainbow/glitch gradient.
class RankedAvatar extends StatefulWidget {
  final String? avatarUrl;
  final String rank;
  final double size;
  final VoidCallback? onTap;
  final Widget? overlay;

  const RankedAvatar({
    super.key,
    this.avatarUrl,
    this.rank = 'ghost',
    this.size = 80,
    this.onTap,
    this.overlay,
  });

  @override
  State<RankedAvatar> createState() => _RankedAvatarState();
}

class _RankedAvatarState extends State<RankedAvatar>
    with SingleTickerProviderStateMixin {
  AnimationController? _animController;

  @override
  void initState() {
    super.initState();
    if (widget.rank == 'immortal') {
      _animController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 3),
      )..repeat();
    }
  }

  @override
  void didUpdateWidget(RankedAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rank == 'immortal' && _animController == null) {
      _animController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 3),
      )..repeat();
    } else if (widget.rank != 'immortal') {
      _animController?.dispose();
      _animController = null;
    }
  }

  @override
  void dispose() {
    _animController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rankDef = RankConstants.getByKey(widget.rank);
    final borderWidth = widget.size * 0.04;

    Widget avatarContent = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF2A2A2A),
        image: widget.avatarUrl != null
            ? DecorationImage(
                image: NetworkImage(
                    '${ApiService.baseUrl}${widget.avatarUrl}'),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: widget.avatarUrl == null
          ? Icon(Icons.person,
              size: widget.size * 0.5, color: Colors.grey)
          : null,
    );

    // Outer border with rank color
    Widget borderedAvatar;

    if (widget.rank == 'immortal' && _animController != null) {
      // Animated rainbow border for Immortal
      borderedAvatar = AnimatedBuilder(
        animation: _animController!,
        builder: (context, child) {
          return CustomPaint(
            painter: _ImmortalBorderPainter(
              progress: _animController!.value,
              borderWidth: borderWidth + 2,
            ),
            child: Padding(
              padding: EdgeInsets.all(borderWidth + 4),
              child: child,
            ),
          );
        },
        child: avatarContent,
      );
    } else {
      // Static colored border
      borderedAvatar = Container(
        width: widget.size + borderWidth * 2 + 8,
        height: widget.size + borderWidth * 2 + 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: rankDef.color,
            width: borderWidth,
          ),
          boxShadow: [
            BoxShadow(
              color: rankDef.glowColor,
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: avatarContent,
        ),
      );
    }

    Widget result = Stack(
      alignment: Alignment.center,
      children: [
        borderedAvatar,
        if (widget.overlay != null) widget.overlay!,
      ],
    );

    if (widget.onTap != null) {
      result = GestureDetector(onTap: widget.onTap, child: result);
    }

    return result;
  }
}

/// Custom painter for the animated Immortal border (rainbow/glitch effect)
class _ImmortalBorderPainter extends CustomPainter {
  final double progress;
  final double borderWidth;

  _ImmortalBorderPainter({
    required this.progress,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) / 2);

    // Rotating gradient for the "glitch" effect
    final sweepGradient = SweepGradient(
      startAngle: progress * 2 * pi,
      colors: const [
        Color(0xFFFF00FF), // Magenta
        Color(0xFF00FFFF), // Cyan
        Color(0xFFFFFF00), // Yellow
        Color(0xFFFF6B35), // Orange
        Color(0xFF39FF14), // Neon Green
        Color(0xFF8B5CF6), // Purple
        Color(0xFFFF00FF), // Back to Magenta
      ],
      stops: const [0.0, 0.16, 0.33, 0.50, 0.66, 0.83, 1.0],
    );

    final paint = Paint()
      ..shader = sweepGradient
          .createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    canvas.drawCircle(center, radius - borderWidth / 2, paint);

    // Extra glow
    final glowPaint = Paint()
      ..shader = sweepGradient
          .createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth + 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8);

    canvas.drawCircle(center, radius - borderWidth / 2, glowPaint);
  }

  @override
  bool shouldRepaint(_ImmortalBorderPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Small rank badge indicator (shows emoji in a tiny bubble)
class RankBadgeIndicator extends StatelessWidget {
  final String rank;
  final double size;

  const RankBadgeIndicator({
    super.key,
    required this.rank,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    final rankDef = RankConstants.getByKey(rank);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: rankDef.color.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: rankDef.color, width: 2),
      ),
      child: Center(
        child: Text(
          rankDef.emoji,
          style: TextStyle(fontSize: size * 0.5),
        ),
      ),
    );
  }
}
