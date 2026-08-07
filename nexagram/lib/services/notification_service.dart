import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'user_service.dart';

/// Top-level function required by FCM: must not be a class member and must
/// be annotated so it survives tree-shaking, since the platform invokes it
/// in a separate isolate while the app is backgrounded/terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Intentionally minimal: heavy work here risks being killed by the OS
  // before it completes. Full message handling happens in the foreground
  // handler when the user actually opens the notification.
  debugPrint('Background FCM message: ${message.messageId}');
}

/// Wraps [FirebaseMessaging] + local notification presentation.
///
/// Responsibilities:
/// - Request notification permission (iOS requires explicit opt-in).
/// - Register/refresh this device's FCM token against the user's profile.
/// - Show a local heads-up notification when a message arrives in the
///   foreground (FCM does not auto-display foreground notifications).
class NotificationService {
  NotificationService({
    FirebaseMessaging? messaging,
    UserService? userService,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _userService = userService ?? UserService();

  final FirebaseMessaging _messaging;
  final UserService _userService;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'nexagram_messages';
  static const String _channelName = 'Messages';

  Future<void> initialize() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'New message notifications',
        importance: Importance.high,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  /// Fetches the current device token and stores it on the user's profile
  /// so Cloud Functions can target this device for push delivery. Also
  /// subscribes to future token refreshes for the lifetime of the app.
  Future<void> registerToken(String uid) async {
    final String? token = await _messaging.getToken();
    if (token != null) {
      await _userService.addFcmToken(uid, token);
    }
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _userService.addFcmToken(uid, newToken);
    });
  }

  Future<void> unregisterToken(String uid) async {
    final String? token = await _messaging.getToken();
    if (token != null) {
      await _userService.removeFcmToken(uid, token);
    }
  }

  void _showForegroundNotification(RemoteMessage message) {
    final RemoteNotification? notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['chatId'] as String?,
    );
  }
}
