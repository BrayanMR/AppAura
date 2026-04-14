import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is initialized in main before runApp. Background handler should stay lightweight.
}

class PushNotificationsService {
  PushNotificationsService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'aurapp_high_importance',
    'AurApp Notificaciones',
    description: 'Canal principal para notificaciones de AurApp',
    importance: Importance.high,
  );

  static bool _initialized = false;

  static bool get _isMobile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  static Future<void> initialize() async {
    if (_initialized || !_isMobile) return;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _requestPermissions();
    await _initLocalNotifications();
    await _initMessageListeners();
    await _syncTopicsWithCurrentUser();

    FirebaseAuth.instance.authStateChanges().listen((_) async {
      await _syncTopicsWithCurrentUser();
    });

    _initialized = true;
  }

  static Future<void> _requestPermissions() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();
    }

    if (Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  static Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const settings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(settings);

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_channel);
  }

  static Future<void> _initMessageListeners() async {
    FirebaseMessaging.onMessage.listen((message) async {
      await _showForegroundNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((_) {
      // Hook for future deep-link navigation from notifications.
    });

    await _messaging.getInitialMessage();
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'];
    final body = notification?.body ?? message.data['body'];

    if ((title ?? '').trim().isEmpty && (body ?? '').trim().isEmpty) {
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title ?? 'AurApp',
      body ?? 'Tienes una nueva notificación',
      NotificationDetails(android: androidDetails),
    );
  }

  static Future<void> _syncTopicsWithCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;

    await _messaging.subscribeToTopic('aurapp_users');

    final token = await _messaging.getToken();
    if (token != null && token.trim().isNotEmpty) {
      debugPrint('[FCM] token: ${token.substring(0, 20)}...');
    }

    if (user == null) return;
    await _messaging.subscribeToTopic('user_${user.uid}');
  }
}
