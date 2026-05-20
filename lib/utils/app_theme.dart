import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF007AFF); // Clean iOS-like blue
  static const primaryLight = Color(0xFF3B82F6);
  static const primarySoft = Color(0xFFE5F1FF); // Soft blue for backgrounds
  static const accent = Color(0xFF0EA5E9);
  static const background = Color(0xFFF4F7F9); // Very light cool gray
  static const surface = Color(0xFFFFFFFF);
  static const cardBg = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF1E293B); // Softer dark for better contrast
  static const textSecondary = Color(0xFF64748B);
  static const textHint = Color(0xFF94A3B8);
  static const divider = Color(0xFFE2E8F0);
  static const success = Color(0xFF10B981);
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const online = Color(0xFF22C55E);
  static const offline = Color(0xFF94A3B8);
  static const sentBubble = Color(0xFF007AFF);
  static const receivedBubble = Color(0xFFFFFFFF);
  static const shimmerBase = Color(0xFFE2E8F0);
  static const shimmerHighlight = Color(0xFFF8FAFC);
}

class AppTextStyles {
  static const String fontFamily = 'Roboto'; // Could be changed to Inter or similar if available, but Roboto is safe

  static const displayLarge = TextStyle(
    fontSize: 32, fontWeight: FontWeight.w800,
    color: AppColors.textPrimary, letterSpacing: -1.0,
  );
  static const displayMedium = TextStyle(
    fontSize: 26, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, letterSpacing: -0.5,
  );
  static const headlineLarge = TextStyle(
    fontSize: 22, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, letterSpacing: -0.3,
  );
  static const headlineMedium = TextStyle(
    fontSize: 18, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary, letterSpacing: -0.2,
  );
  static const titleLarge = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const titleMedium = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
  static const bodyLarge = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );
  static const bodyMedium = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
  static const bodySmall = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w400,
    color: AppColors.textHint,
  );
  static const labelLarge = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w600,
    color: AppColors.surface, letterSpacing: 0.3,
  );
}

class AppTheme {
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      brightness: Brightness.light,
      surface: AppColors.surface,
      background: AppColors.background,
    ),
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: AppTextStyles.fontFamily,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0, // Keeps it flat and clean
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      titleTextStyle: AppTextStyles.headlineMedium,
      centerTitle: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        minimumSize: const Size(double.infinity, 56),
        textStyle: AppTextStyles.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none, // Removes harsh borders
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      hintStyle: AppTextStyles.bodyMedium,
    ),
    cardTheme: CardThemeData(
      color: AppColors.cardBg,
      elevation: 0, // No harsh shadows
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.divider.withOpacity(0.5), width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: DividerThemeData(
      color: AppColors.divider.withOpacity(0.5), thickness: 1, space: 0,
    ),
  );
}

class AppRoutes {
  static const splash = '/';
  static const welcome = '/welcome';
  static const phoneLogin = '/phone-login';
  static const otpVerify = '/otp-verify';
  static const emailEntry = '/email-entry';
  static const profileSetup = '/profile-setup';
  static const success = '/success';
  static const home = '/home';
  static const chat = '/chat';
  static const editProfile = '/edit-profile';
  static const newChat = '/new-chat';
}
