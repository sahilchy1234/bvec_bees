import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late FlutterLocalNotificationsPlugin _localNotifications;
  StreamSubscription<QuerySnapshot>? _notificationSubscription;

  factory FCMService() {
    return _instance;
  }

  void _listenToUserNotifications(String userId) {
    // Cancel any existing subscription
    _notificationSubscription?.cancel();

    _notificationSubscription = _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added &&
            !change.doc.metadata.hasPendingWrites) {
          final data =
              change.doc.data() ?? <String, dynamic>{};
          final title = (data['title'] as String?) ?? 'Notification';
          final body = (data['body'] as String?) ?? '';
          _showSimpleLocalNotification(title, body);
        }
      }
    }, onError: (e) {
      print('Error listening to user notifications: $e');
    });
  }

  FCMService._internal() {
    _initializeLocalNotifications();
  }

  void _initializeLocalNotifications() {
    _localNotifications = FlutterLocalNotificationsPlugin();

    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'high_importance_channel',
            'High Importance Notifications',
            description: 'This channel is used for important notifications.',
            importance: Importance.max,
            enableVibration: true,
            playSound: true,
          ),
        );
      }
    }

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );

    _localNotifications.initialize(initializationSettings);
  }

  Future<void> initialize(String userId) async {
    // Debug log: starting FCM init
    print('[FCM] Initializing FCM for user: $userId');

    // Request permissions
    await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // Get FCM token
    final token = await _firebaseMessaging.getToken();
    if (token != null) {
      print('[FCM] Got FCM token for $userId: $token');
      await _saveFCMToken(userId, token);
    } else {
      print('[FCM] getToken returned null for user $userId');
    }

    // Handle foreground messages from FCM
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages from FCM
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      _saveFCMToken(userId, newToken);
    });

    // Listen to Firestore notifications for this user to show local popups
    _listenToUserNotifications(userId);
  }

  Future<void> _saveFCMToken(String userId, String token) async {
    try {
      print('[FCM] Saving FCM token for $userId');
      // Use set with merge so the document is created if it doesn't exist yet
      await _firestore.collection('users').doc(userId).set({
        'fcmToken': token,
        'lastTokenUpdate': DateTime.now(),
      }, SetOptions(merge: true));
      print('[FCM] Saved FCM token for $userId');
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('Foreground message: ${message.notification?.title}');
    _showLocalNotification(message);
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    print('Message opened app: ${message.data}');
    // Handle navigation based on message data
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription:
              'This channel is used for important notifications.',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> _showSimpleLocalNotification(String title, String body) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription:
              'This channel is used for important notifications.',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> sendNotification({
    required String userId,
    required String type,
    required String title,
    required String body,
    String? senderId,
    String? senderName,
    String? senderImage,
    String? relatedId,
    Map<String, dynamic>? data,
  }) async {
    try {
      final notificationId = DateTime.now().millisecondsSinceEpoch.toString();

      // Save to Firestore
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .set({
        'type': type,
        'title': title,
        'body': body,
        'senderId': senderId,
        'senderName': senderName,
        'senderImage': senderImage,
        'relatedId': relatedId,
        'timestamp': DateTime.now(),
        'isRead': false,
        'data': data,
      });

      // Call Vercel backend to send FCM (works in background / app killed)
      final uri = Uri.parse(
        'https://bvecbees-fddeezr2s-sahils-projects-deff163e.vercel.app/api/sendNotification',
      );

      try {
        await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'userId': userId,
            'title': title,
            'body': body,
            'type': type,
            'data': data ?? <String, dynamic>{},
          }),
        );
      } catch (e) {
        print('Error calling Vercel notification endpoint: $e');
      }
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  Future<void> markNotificationAsRead(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Stream<QuerySnapshot> getNotifications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> deleteNotification(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }
}
