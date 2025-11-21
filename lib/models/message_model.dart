import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String senderImage;
  final String content;
  final DateTime timestamp;
  final bool isRead;
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
    required this.timestamp,
    this.isRead = false,
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
      'timestamp': timestamp,
      'isRead': isRead,
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
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
      replyToMessageId: map['replyToMessageId'],
      replyToSenderName: map['replyToSenderName'],
      replyToContent: map['replyToContent'],
    );
  }
}
