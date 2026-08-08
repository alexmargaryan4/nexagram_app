import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../core/constants/app_constants.dart';
import 'local_storage_service.dart';

/// Shows a local heads-up notification when a new message arrives while
/// the app is open, by listening to Supabase Realtime's `postgres_changes`
/// feed on `public.messages` — no push-notification backend involved.
///
/// ## Why there's no background/killed-app push here
/// The old Firebase build used Firebase Cloud Messaging (FCM) to deliver
/// notifications even while the app was closed. Supabase has no
/// equivalent built-in push service — Realtime only delivers events while
/// the app has a live socket connection (i.e. is running), so this
/// service can only cover the **foreground/backgrounded-but-running**
/// case, the same as the old code's own `_showForegroundNotification`
/// path did.
///
/// To restore true "app fully closed" push delivery, the common
/// Supabase-native pattern is:
///   1. Keep sending each device's push token to `public.users.fcm_tokens`
///      (this service still does that — `registerToken` below), or swap
///      to APNs/FCM tokens managed by a package like `firebase_messaging`
///      *just* for the token+delivery transport, OR a push-focused service
///      such as OneSignal.
///   2. Add a Postgres trigger (or a `send_message` RPC extension) that,
///      on insert into `public.messages`, calls a Supabase Edge Function.
///   3. That Edge Function reads the recipients' tokens and calls the
///      FCM HTTP v1 API / APNs directly with a service-account key kept
///      server-side — the client never needs the full Firebase SDK for
///      this, only a small server-side credential.
/// This is intentionally left as a follow-up rather than silently wired
/// back to Firebase, since pulling `firebase_messaging` back in would
/// undo the point of this migration. See README.md → "Push notifications".
class NotificationService {
  NotificationService({sb.SupabaseClient? client, LocalStorageService? localStorage})
      : _client = client ?? sb.Supabase.instance.client,
        _localStorage = localStorage ?? LocalStorageService();

  final sb.SupabaseClient _client;
  final LocalStorageService _localStorage;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  sb.RealtimeChannel? _messagesChannel;

  static const String _channelId = 'nexagram_messages';
  static const String _channelName = 'Messages';

  Future<void> initialize() async {
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

    if (Platform.isIOS || Platform.isMacOS) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

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
      // Android 13+ requires runtime notification permission.
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  /// Subscribes to new-message events for chats [uid] participates in and
  /// shows a local notification for any message not sent by [uid] itself.
  ///
  /// Realtime's row-level filters can't express "chat_id in (my chats)"
  /// directly against a join, so this listens to all inserts on
  /// `public.messages` and filters client-side against [chatIds] — call
  /// [updateWatchedChats] whenever the caller's chat list changes (e.g.
  /// from [ChatsProvider]) to keep the filter set current.
  Set<String> _watchedChatIds = {};

  void updateWatchedChats(Set<String> chatIds) {
    _watchedChatIds = chatIds;
  }

  Future<void> registerToken(String uid) async {
    _messagesChannel?.unsubscribe();
    _messagesChannel = _client
        .channel('messages-for-$uid')
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseTables.messages,
          callback: (payload) {
            final Map<String, dynamic> row = payload.newRecord;
            final String senderId = row['sender_id'] as String? ?? '';
            final String chatId = row['chat_id'] as String? ?? '';
            if (senderId == uid) return;
            if (!_watchedChatIds.contains(chatId)) return;
            _showLocalNotification(
              title: 'New message',
              body: _previewFor(row),
              chatId: chatId,
            );
          },
        )
        .subscribe();
  }

  Future<void> unregisterToken(String uid) async {
    await _messagesChannel?.unsubscribe();
    _messagesChannel = null;
  }

  String _previewFor(Map<String, dynamic> row) {
    switch (row['type'] as String?) {
      case 'image':
        return '📷 Photo';
      case 'file':
        return '📎 ${row['file_name'] ?? 'File'}';
      case 'voice':
        return '🎤 Voice message';
      default:
        return (row['text'] as String?) ?? '';
    }
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required String chatId,
  }) async {
    final bool enabled = await _localStorage.getNotificationsEnabled();
    if (!enabled) return;

    try {
      await _localNotifications.show(
        chatId.hashCode,
        title,
        body,
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
        payload: chatId,
      );
    } catch (e) {
      debugPrint('Failed to show local notification: $e');
    }
  }
}
