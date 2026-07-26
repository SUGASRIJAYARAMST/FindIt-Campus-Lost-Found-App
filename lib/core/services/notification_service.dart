import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firestore_service.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirestoreService firestoreService;

  bool _initialized = false;
  bool _isAppInForeground = true;
  Function()? onNotificationReceived;
  Function(Map<String, dynamic> data)? onNotificationTapped;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _backgroundSub;
  late final AppLifecycleListener _lifecycleListener;

  NotificationService({required this.firestoreService});

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        _isAppInForeground = state == AppLifecycleState.resumed;
      },
    );

    await _requestPermission();
    await _initializeLocalNotifications();
    await _setupTokenRefresh();
    _setupMessageHandlers();

    final token = await _messaging.getToken();
    if (token != null) {
      debugPrint('FCM Token: $token');
    }
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('Notification permission: ${settings.authorizationStatus}');
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  Future<void> _setupTokenRefresh() async {
    _tokenSub?.cancel();
    _tokenSub = _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('FCM Token refreshed: $newToken');
    });
  }

  void _setupMessageHandlers() {
    _foregroundSub?.cancel();
    _backgroundSub?.cancel();
    _foregroundSub = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    _backgroundSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
    _handleInitialMessage();
  }

  void dispose() {
    _tokenSub?.cancel();
    _foregroundSub?.cancel();
    _backgroundSub?.cancel();
    _lifecycleListener.dispose();
  }

  Future<void> _handleInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    if (message != null) {
      _handleBackgroundMessage(message);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message: ${message.messageId}');
    _showLocalNotification(message);
    _saveNotificationToFirestore(message);
    onNotificationReceived?.call();
  }

  void _handleBackgroundMessage(RemoteMessage message) {
    debugPrint('Background message: ${message.messageId}');
    onNotificationReceived?.call();
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        final data = json.decode(response.payload!) as Map<String, dynamic>;
        onNotificationTapped?.call(data);
      } catch (e) {
        debugPrint('Parse notification payload error: $e');
      }
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'findit_channel',
      'FindIt Notifications',
      channelDescription: 'Notifications for FindIt app',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: jsonEncode(message.data),
    );
  }

  Future<void> _saveNotificationToFirestore(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final uid = message.data['uid'] as String? ?? '';
    if (uid.isEmpty) return;

    final notifData = <String, dynamic>{
      'uid': uid,
      'title': notification.title ?? '',
      'body': notification.body ?? '',
      'type': message.data['type'] ?? 'system',
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
    };

    final type = message.data['type'] ?? 'system';
    if (type == 'chat_message') {
      notifData['chatId'] = message.data['chatId'] ?? '';
      notifData['senderId'] = message.data['senderId'] ?? '';
      notifData['itemName'] = message.data['itemName'] ?? '';
    }

    await firestoreService.addData('notifications', notifData);
  }

  Future<void> saveTokenToFirestore(String uid) async {
    final token = await _messaging.getToken();
    if (token != null) {
      await firestoreService.setData(
        'users',
        uid,
        {'fcmToken': token},
        merge: true,
      );
    }
  }

  Future<bool> _isNotificationsEnabled(String uid) async {
    try {
      final doc = await firestoreService.document('users', uid);
      if (doc.exists && doc.data() != null) {
        final userData = doc.data() as Map<String, dynamic>;
        return userData['notificationsEnabled'] as bool? ?? true;
      }
    } catch (e) {
      debugPrint('Error checking notification preference: $e');
    }
    return true;
  }

  Future<void> sendNotificationToUser({
    required String targetUid,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Check if user has notifications enabled
      if (!await _isNotificationsEnabled(targetUid)) {
        debugPrint('Notifications disabled for user: $targetUid');
        return;
      }

      final type = data?['type'] ?? 'system';

      // Always save to Firestore so notification appears in the notifications screen
      final notifData = <String, dynamic>{
        'uid': targetUid,
        'title': title,
        'body': body,
        'type': type,
        'read': false,
        'itemId': data?['itemId'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
      };

      if (type == 'chat_message') {
        notifData['chatId'] = data?['chatId'] ?? '';
        notifData['senderId'] = data?['senderId'] ?? '';
        notifData['itemName'] = data?['itemName'] ?? '';
      }

      await firestoreService.addData('notifications', notifData);

      // Only show local push notification when app is NOT in foreground
      if (!_isAppInForeground) {
        await _showLocalNotification(
          RemoteMessage(
            data: {'uid': targetUid, ...?data},
            notification: RemoteNotification(
              title: title,
              body: body,
            ),
          ),
        );
        debugPrint('Push notification sent to user: $targetUid');
      } else {
        debugPrint('In-app notification saved: $targetUid');
      }
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  Future<void> sendSystemNotification({
    required String uid,
    required String title,
    required String body,
    String type = 'system',
  }) async {
    try {
      await firestoreService.addData('notifications', {
        'uid': uid,
        'title': title,
        'body': body,
        'type': type,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
      });

      await _showLocalNotification(
        RemoteMessage(
          data: {'uid': uid, 'type': type},
          notification: RemoteNotification(title: title, body: body),
        ),
      );
    } catch (e) {
      debugPrint('Error sending system notification: $e');
    }
  }

  Future<void> cleanupOldNotifications() async {
    try {
      final oldDocs = await FirebaseFirestore.instance
          .collection('notifications')
          .where('expiresAt', isLessThan: Timestamp.now())
          .get();
      for (final doc in oldDocs.docs) {
        await doc.reference.delete();
      }
      if (oldDocs.docs.isNotEmpty) {
        debugPrint('Cleaned up ${oldDocs.docs.length} expired notifications');
      }
    } catch (e) {
      debugPrint('Error cleaning up notifications: $e');
    }
  }

  Future<void> unsubscribeFromAll() async {
    await _messaging.deleteToken();
  }
}
