import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final _fcm = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Request permissions
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      announcement: false,
    );

    // Initialize local notifications
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );
    await _localNotifications.initialize(initializationSettings);

    // Foreground messages
    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
      debugPrint('FCM foreground: ${message.notification?.title}');
    });

    // Background/terminated messages
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('FCM opened: ${message.notification?.title}');
    });
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'novachat_channel',
      'NovaChat Messages',
      channelDescription: 'Real-time chat notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );
    const platformDetails = NotificationDetails(
      android: androidDetails,
    );
    await _localNotifications.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      platformDetails,
    );
  }

  Future<String?> getToken() async => await _fcm.getToken();

  Future<void> saveToken(String uid, String token) async {
    // Save FCM token to database for targeted notifications
    try {
      // Implementation would write to the user's fcmTokens node
      debugPrint('FCM token for $uid: $token');
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
    }
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    int id = 0,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'novachat_channel',
      'NovaChat',
      channelDescription: 'Local notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const platformDetails = NotificationDetails(
      android: androidDetails,
    );
    await _localNotifications.show(id, title, body, platformDetails);
  }
}

// Top-level handler for background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background FCM: ${message.notification?.title}');
}