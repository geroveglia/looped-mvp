import 'package:flutter/material.dart';

/// Looped Premium Design System
/// Inspired by wellness apps, optimized for nightlife/dance
///
/// Philosophy: "Una app de actividad física premium, no una app de fiesta caótica."

class AppTheme {
  // ============================================
  // COLORS
  // ============================================

  /// Background colors - near black, elegant
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF121212);
  static const Color surfaceLight = Color(0xFF1E1E1E);
  static const Color surfaceBorder = Color(0xFF333333);

  /// Text colors - soft, not harsh white
  static const Color textPrimary = Color(0xFFE8E8E8);
  static const Color textSecondary = Color(0xFF888888);
  static const Color textTertiary = Color(0xFF555555);

  /// Accent - ONE color only, used sparingly
  static const Color accent = Color(0xFF00D9A5); // Teal green
  static const Color accentLight = Color(0xFF00FFB8);
  static const Color accentDark = Color(0xFF00A67D);

  /// Status colors
  static const Color success = Color(0xFF00D9A5);
  static const Color warning = Color(0xFFFFB800);
  static const Color error = Color(0xFFFF5252);
  static const Color info = Color(0xFF64B5F6);

  // ============================================
  // SPACING
  // ============================================

  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;
  static const double spacingXxl = 48;

  // ============================================
  // RADII
  // ============================================

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
  static const double radiusRound = 100;

  // ============================================
  // SHADOWS
  // ============================================

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.5),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ];

  // ============================================
  // TEXT STYLES
  // ============================================

  /// Large display number (points, big stats)
  static const TextStyle displayLarge = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w300,
    color: textPrimary,
    letterSpacing: -1,
  );

  /// Medium display (time, secondary stats)
  static const TextStyle displayMedium = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );

  /// Section titles
  static const TextStyle titleLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  /// Card titles
  static const TextStyle titleMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  /// Labels, subtitles
  static const TextStyle titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );

  /// Body text
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textTertiary,
  );

  /// Labels (all caps, tracking)
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textSecondary,
    letterSpacing: 1.5,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: textSecondary,
    letterSpacing: 1.2,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: textTertiary,
    letterSpacing: 1,
  );

  // ============================================
  // CARD DECORATION
  // ============================================

  static BoxDecoration get cardDecoration => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: surfaceBorder.withOpacity(0.3)),
      );

  static BoxDecoration get cardElevatedDecoration => BoxDecoration(
        color: surfaceLight,
        borderRadius: BorderRadius.circular(radiusLg),
        boxShadow: cardShadow,
      );

  // ============================================
  // BUTTON STYLES
  // ============================================

  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: background,
        padding: const EdgeInsets.symmetric(
            horizontal: spacingLg, vertical: spacingMd),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      );

  static ButtonStyle get secondaryButtonStyle => OutlinedButton.styleFrom(
        foregroundColor: textPrimary,
        padding: const EdgeInsets.symmetric(
            horizontal: spacingLg, vertical: spacingMd),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
        side: const BorderSide(color: surfaceBorder),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      );

  static ButtonStyle get dangerButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: error,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
            horizontal: spacingLg, vertical: spacingMd),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
      );

  // ============================================
  // THEME DATA
  // ============================================

  static ThemeData get themeData => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        primaryColor: accent,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          secondary: accent,
          surface: surface,
          error: error,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: titleMedium,
          iconTheme: IconThemeData(color: textPrimary),
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: primaryButtonStyle,
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: secondaryButtonStyle,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: spacingMd,
            vertical: spacingMd,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: background,
          selectedItemColor: accent,
          unselectedItemColor: textSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: surface,
          contentTextStyle: bodyMedium,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          behavior: SnackBarBehavior.floating,
        ),
        useMaterial3: true,
      );
}

// ============================================
// REUSABLE WIDGETS
// ============================================

/// Premium card with consistent styling
class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final bool elevated;
  final VoidCallback? onTap;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.elevated = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: AppTheme.spacingMd),
      decoration:
          elevated ? AppTheme.cardElevatedDecoration : AppTheme.cardDecoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppTheme.spacingMd),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Large stat display widget
class StatDisplay extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;
  final double? fontSize;

  const StatDisplay({
    super.key,
    required this.value,
    required this.label,
    this.valueColor,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppTheme.displayLarge.copyWith(
            color: valueColor ?? AppTheme.textPrimary,
            fontSize: fontSize ?? 48,
          ),
        ),
        const SizedBox(height: AppTheme.spacingXs),
        Text(
          label.toUpperCase(),
          style: AppTheme.labelMedium,
        ),
      ],
    );
  }
}

/// Status badge widget
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'active':
        color = AppTheme.success;
        text = 'LIVE';
        icon = Icons.circle;
        break;
      case 'waiting':
        color = AppTheme.warning;
        text = 'WAITING';
        icon = Icons.hourglass_empty;
        break;
      case 'ended':
        color = AppTheme.error;
        text = 'ENDED';
        icon = Icons.stop_circle_outlined;
        break;
      default:
        color = AppTheme.textSecondary;
        text = status.toUpperCase();
        icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingSm,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusRound),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: AppTheme.spacingSm),
          Text(
            text,
            style: AppTheme.labelMedium.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Progress bar widget
class ProgressBar extends StatelessWidget {
  final double progress;
  final Color? color;
  final double height;

  const ProgressBar({
    super.key,
    required this.progress,
    this.color,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.surfaceBorder,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: color ?? AppTheme.accent,
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
      ),
    );
  }
}
