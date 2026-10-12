import 'package:flutter/material.dart';

/// Brand palette for the FitX Training Club app.
class AppColors {
  AppColors._();

  /// Off-white app background (light theme).
  static const Color background = Color(0xFFFBF9F8);

  /// Warm tinted card surface (light theme).
  static const Color card = Color(0xFFFFF0EB);

  /// Dark grey primary text (light theme).
  static const Color text = Color(0xFF1F1F1F);

  /// Vibrant orange primary accent.
  static const Color accent = Color(0xFFFF5722);

  /// Secondary warm orange accent (progress, highlights).
  static const Color accentSecondary = Color(0xFFFF9F1C);

  /// Warm dark scaffold background (dark theme).
  static const Color darkBackground = Color(0xFF17120F);

  /// Warm dark card surface (dark theme).
  static const Color darkCard = Color(0xFF241C17);

  /// Off-white text on dark surfaces.
  static const Color darkText = Color(0xFFF4EFEA);
}

/// Light + dark themes and the app-wide theme-mode notifier.
class AppTheme {
  AppTheme._();

  /// App-wide theme mode. Toggled by the sidebar's dark-mode switch and
  /// listened to by [FitXApp] so the whole tree rebuilds.
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.light);

  /// App-wide display name, updated when user edits personal info.
  /// Listened to by ProfileScreen, AppDrawer, and other widgets so the
  /// user name changes globally without needing a full re-login.
  static final ValueNotifier<String> userDisplayName = ValueNotifier<String>(
    '',
  );

  /// App-wide email, mirroring [userDisplayName] for instant drawer/profile
  /// sync without mutating the immutable login payload.
  static final ValueNotifier<String> userEmail = ValueNotifier<String>('');

  /// App-wide workout goals text, edited from ProfileScreen.
  static final ValueNotifier<String> userWorkoutGoals = ValueNotifier<String>(
    '',
  );

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      primary: AppColors.accent,
      secondary: AppColors.accentSecondary,
      brightness: Brightness.light,
    ).copyWith(surface: AppColors.background, onSurface: AppColors.text);

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      dividerTheme: const DividerThemeData(color: Color(0x1A1F1F1F)),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? AppColors.accent : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.accent.withValues(alpha: 0.4)
              : null,
        ),
      ),
    );
  }

  static ThemeData get dark {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          primary: AppColors.accent,
          secondary: AppColors.accentSecondary,
          brightness: Brightness.dark,
        ).copyWith(
          surface: AppColors.darkBackground,
          onSurface: AppColors.darkText,
        );

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.darkText,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.darkCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      dividerTheme: const DividerThemeData(color: Color(0x33F4EFEA)),
    );
  }
}
