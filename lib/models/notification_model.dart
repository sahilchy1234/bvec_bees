import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String userId; // Recipient
  final String type; // 'chat', 'post_like', 'tag', 'comment', 'match', 'engagement'
  final String title;
  final String body;
  final String? senderId; // Who triggered the notification
  final String? senderName;
  final String? senderImage;
  final String? relatedId; // postId, conversationId, matchId, etc.
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? data; // Additional metadata

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.senderId,
    this.senderName,
    this.senderImage,
    this.relatedId,
    required this.timestamp,
    this.isRead = false,
    this.data,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      userId: map['userId'] ?? '',
      type: map['type'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      senderId: map['senderId'],
      senderName: map['senderName'],
      senderImage: map['senderImage'],
      relatedId: map['relatedId'],
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
      data: map['data'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,
      'title': title,
      'body': body,
      'senderId': senderId,
      'senderName': senderName,
      'senderImage': senderImage,
      'relatedId': relatedId,
      'timestamp': timestamp,
      'isRead': isRead,
      'data': data,
    };
  }
}
