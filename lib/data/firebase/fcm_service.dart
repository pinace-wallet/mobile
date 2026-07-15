import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firestore_repo.dart';

/// Push notifications for agent activity. Background delivery relies on the
/// Cloud Function bridge in mobile/functions (indexer events -> FCM tokens);
/// foreground messages are surfaced through flutter_local_notifications.
class FcmService {
  FcmService(this._repo);

  final FirestoreRepo _repo;
  final _messaging = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'pinace_agent_activity',
    'Agent activity',
    description: 'Pool deposits, agent swaps, and revocations',
    importance: Importance.high,
  );

  Future<bool> enable() async {
    final settings = await _messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return false;
    }

    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    final token = await _messaging.getToken();
    if (token != null) {
      await _repo.registerFcmToken(token, Platform.operatingSystem);
    }
    _messaging.onTokenRefresh.listen(
        (token) => _repo.registerFcmToken(token, Platform.operatingSystem));

    FirebaseMessaging.onMessage.listen(_showForeground);
    await _repo.setNotificationsEnabled(true);
    return true;
  }

  void _showForeground(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    _local.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
