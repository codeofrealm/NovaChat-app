import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF2563EB);
  static const primaryLight = Color(0xFF3B82F6);
  static const primarySoft = Color(0xFFEFF6FF);
  static const accent = Color(0xFF06B6D4);
  static const background = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const cardBg = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textHint = Color(0xFF94A3B8);
  static const divider = Color(0xFFE2E8F0);
  static const success = Color(0xFF10B981);
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const online = Color(0xFF22C55E);
  static const offline = Color(0xFF94A3B8);
  static const sentBubble = Color(0xFF2563EB);
  static const receivedBubble = Color(0xFFF1F5F9);
  static const shimmerBase = Color(0xFFE2E8F0);
  static const shimmerHighlight = Color(0xFFF8FAFC);
}

class AppTextStyles {
  static const String fontFamily = 'Roboto';

  static const displayLarge = TextStyle(
    fontSize: 32, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, letterSpacing: -0.5,
  );
  static const displayMedium = TextStyle(
    fontSize: 26, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, letterSpacing: -0.3,
  );
  static const headlineLarge = TextStyle(
    fontSize: 22, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const headlineMedium = TextStyle(
    fontSize: 18, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
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
      brightness: Brightness.light,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: AppTextStyles.fontFamily,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: AppColors.divider,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      titleTextStyle: AppTextStyles.headlineMedium,
      centerTitle: false,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(double.infinity, 54),
        textStyle: AppTextStyles.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      hintStyle: AppTextStyles.bodyMedium,
    ),
    cardTheme: CardThemeData(
      color: AppColors.cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.divider, thickness: 1, space: 0,
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
