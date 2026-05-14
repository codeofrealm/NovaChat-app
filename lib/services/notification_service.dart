import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final _fcm = FirebaseMessaging.instance;

  Future<void> initialize() async {
    await _fcm.requestPermission(
      alert: true, badge: true, sound: true,
    );

    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('FCM foreground: ${message.notification?.title}');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('FCM opened: ${message.notification?.title}');
    });
  }

  Future<String?> getToken() async => await _fcm.getToken();

  Future<void> saveToken(String uid, String token) async {
    // Save FCM token to database for targeted notifications
  }
}

// Top-level handler for background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background FCM: ${message.notification?.title}');
}
