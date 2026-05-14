import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

class AppUtils {
  // Validate email
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // Format timestamp for chat list
  static String formatChatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return DateFormat('hh:mm a').format(dt);
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('dd/MM/yy').format(dt);
  }

  // Format timestamp for message bubble
  static String formatMessageTime(int timestamp) {
    return DateFormat('hh:mm a').format(
      DateTime.fromMillisecondsSinceEpoch(timestamp),
    );
  }

  // Format last seen
  static String formatLastSeen(int timestamp) {
    return 'last seen ${timeago.format(DateTime.fromMillisecondsSinceEpoch(timestamp))}';
  }

  // Format duration for voice messages
  static String formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // Internal static version used by chat_input_bar
  static String _formatDurationStatic(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // Generate chat ID from two UIDs (deterministic: smaller_first)
  static String getChatId(String uid1, String uid2) {
    return uid1.compareTo(uid2) < 0 ? '${uid1}_$uid2' : '${uid2}_$uid1';
  }

  // Show snackbar
  static void showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // Smooth slide route
  static Route<T> slideRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, animation, __) => page,
      transitionDuration: const Duration(milliseconds: 350),
      transitionsBuilder: (_, animation, __, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.05, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  // Fade route
  static Route<T> fadeRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, animation, __) => page,
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  // Custom curve for bouncy animations
  static const bounceCurve = Curves.elasticOut;
}