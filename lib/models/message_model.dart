import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String senderImage;
  final String content;
  final String? imageUrl;
  final DateTime timestamp;
  final bool isRead;
  final bool isDelivered;
  final String? replyToMessageId;
  final String? replyToSenderName;
  final String? replyToContent;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.senderImage,
    required this.content,
    this.imageUrl,
    required this.timestamp,
    this.isRead = false,
    this.isDelivered = false,
    this.replyToMessageId,
    this.replyToSenderName,
    this.replyToContent,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'senderImage': senderImage,
      'content': content,
      'imageUrl': imageUrl,
      'timestamp': timestamp,
      'isRead': isRead,
      'isDelivered': isDelivered,
      'replyToMessageId': replyToMessageId,
      'replyToSenderName': replyToSenderName,
      'replyToContent': replyToContent,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map, String docId) {
    return Message(
      id: docId,
      conversationId: map['conversationId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderImage: map['senderImage'] ?? '',
      content: map['content'] ?? '',
      imageUrl: map['imageUrl'],
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
      isDelivered: map['isDelivered'] ?? false,
      replyToMessageId: map['replyToMessageId'],
      replyToSenderName: map['replyToSenderName'],
      replyToContent: map['replyToContent'],
    );
  }
}
