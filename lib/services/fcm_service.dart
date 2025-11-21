import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  factory FCMService() {
    return _instance;
  }

  FCMService._internal();

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
    
    // Handle background messages from FCM
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      _saveFCMToken(userId, newToken);
    });
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

  void _handleMessageOpenedApp(RemoteMessage message) {
    print('Message opened app: ${message.data}');
    // Handle navigation based on message data
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
        'https://bvecbees-5bwzjjm9s-sahils-projects-deff163e.vercel.app/api/sendNotification',
      );

      try {
        final response = await http.post(
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

        print('[FCM] Vercel sendNotification status: '
            '${response.statusCode}, body: ${response.body}');
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
