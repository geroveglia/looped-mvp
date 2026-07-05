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
  static const Color surfaceMuted = Color(0xFF2A2A2A);
  static const Color surfaceBorder = Color(0xFF333333);

  /// Hairline border used on cards over black
  static Color get cardBorder => Colors.white.withOpacity(0.06);

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
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  /// Unified Screen Main Title
  static const TextStyle screenTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    letterSpacing: -0.5,
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

  // Primary CTAs use the CtaButton widget below (gradient + glow).

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
          backgroundColor: surfaceLight,
          contentTextStyle: bodyMedium.copyWith(color: textPrimary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          behavior: SnackBarBehavior.floating,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
          ),
          titleTextStyle: titleMedium,
          contentTextStyle: bodyMedium,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
          ),
          showDragHandle: true,
          dragHandleColor: surfaceBorder,
        ),
        tabBarTheme: const TabBarThemeData(
          indicatorColor: accent,
          labelColor: accent,
          unselectedLabelColor: textSecondary,
          dividerColor: Colors.transparent,
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: surfaceLight,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: bodyMedium.copyWith(color: textPrimary),
        ),
        dividerTheme: const DividerThemeData(
          color: surfaceLight,
          thickness: 1,
          space: 1,
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: textSecondary,
          textColor: textPrimary,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: accent,
          linearTrackColor: surfaceMuted,
          circularTrackColor: surfaceMuted,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: accent,
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        datePickerTheme: DatePickerThemeData(
          backgroundColor: surface,
          surfaceTintColor: Colors.transparent,
          headerBackgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
          ),
        ),
        timePickerTheme: TimePickerThemeData(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
          ),
        ),
        useMaterial3: true,
      );
}

// ============================================
// REUSABLE WIDGETS
// ============================================

/// Primary call-to-action button: gradient fill, soft glow, light border.
/// Use [danger] for destructive main actions (stop/finish/delete).
class CtaButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool danger;
  final bool loading;
  final double height;

  const CtaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.danger = false,
    this.loading = false,
    this.height = 58,
  });

  @override
  Widget build(BuildContext context) {
    // While loading we keep the full look (spinner replaces the icon).
    final enabled = onPressed != null || loading;
    final glowColor = danger ? AppTheme.error : AppTheme.accent;
    final fg = danger ? Colors.white : const Color(0xFF03130D);

    final gradientColors = danger
        ? const [Color(0xFFFF7A70), Color(0xFFE5484D)]
        : const [Color(0xFF3DF5C3), Color(0xFF00C795)];

    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                )
              : null,
          color: enabled ? null : AppTheme.surfaceMuted,
          borderRadius: BorderRadius.circular(AppTheme.radiusRound),
          border: Border.all(
            color: Colors.white.withOpacity(enabled ? 0.25 : 0.05),
            width: 1,
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: glowColor.withOpacity(0.35),
                    blurRadius: 26,
                    spreadRadius: -6,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppTheme.radiusRound),
            splashColor: Colors.black.withOpacity(0.12),
            highlightColor: Colors.black.withOpacity(0.06),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading) ...[
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: fg,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ] else if (icon != null) ...[
                    Icon(icon,
                        color: enabled ? fg : AppTheme.textTertiary, size: 22),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: enabled ? fg : AppTheme.textTertiary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
        text = 'EN VIVO';
        icon = Icons.circle;
        break;
      case 'waiting':
        color = AppTheme.warning;
        text = 'EN ESPERA';
        icon = Icons.hourglass_empty;
        break;
      case 'ended':
        color = AppTheme.error;
        text = 'FINALIZADO';
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
